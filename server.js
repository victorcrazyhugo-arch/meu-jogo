// Left to Die — servidor de salas (etapa 4: jogadores, chat, mundo da sala, carros e itens no chão).
// Retransmite o estado de cada jogador e guarda em memória o mundo de cada sala (portas, baús e carros),
// para quem entrar depois receber tudo igual. Nada vai para disco: se o servidor reiniciar,
// o primeiro jogador que voltar reenvia o que tem salvo.
// Itens no chão (largados, troncos, peixes) também ficam na sala. Dois jogadores pegando o mesmo item ao
// mesmo tempo (do chão ou de um baú): vale quem chegou primeiro ao servidor; o outro recebe 'lost' e o item
// sai do inventário dele (sem duplicar).
// Uso: PORT=8080 node server.js
import http from 'node:http';
import { WebSocketServer } from 'ws';

const PORT = Number(process.env.PORT) || 8080;
const MAX_ROOM_PLAYERS = Number(process.env.MAX_ROOM_PLAYERS) || 16;
const MAX_ROOMS = Number(process.env.MAX_ROOMS) || 300;
const MAX_CONNECTIONS = Number(process.env.MAX_CONNECTIONS) || 600;
const MAX_STATE_BYTES = 4096;
const MAX_REVS = 40, MAX_REV_BYTES = 60 * 1024;   // zumbis de jogadores mortos guardados por sala
// Corpo de jogador (morto por outro jogador, ou o zumbi dele depois de morto) some 1 h depois, com os itens.
const CORPSE_MS = Math.max(1000, Number(process.env.CORPSE_MS) || 60 * 60 * 1000), MAX_REV_GONE = 500;
const MAX_CARS = 160, MAX_CAR_BYTES = 8 * 1024;    // carros e carretas parados (posição, combustível, peças)
const MAX_PROFILE_BYTES = 96 * 1024;
const MAX_WORLD_BYTES = 400 * 1024;   // uma mensagem de mundo (semente de portas, baú grande)
// v37: o mapa ganhou 44 casas (800 baús, 514 portas, 619 janelas), então os tetos subiram junto
const MAX_DOORS = 16000, MAX_CONTAINERS = 9000, MAX_CONTAINER_ITEMS = 240, MAX_DEAD_ZOMBIES = 60000;
const MAX_GROUND = 6000, MAX_GROUND_FLOOR = 1500, MAX_GROUND_BYTES = 2000;   // itens no chão: os que estão no chão e os que já foram pegos
const RACE_MS = 60000;   // quem pegou um item há menos de 1 minuto: outro que pegar o mesmo item perde a disputa
const WORLD_KEEP_MS = 6 * 60 * 60 * 1000;   // sala vazia mantém o mundo por 6 horas
const MAX_CHAT_CHARS = 200;
// Semana da sala: a cada 7 dias reais (virada na segunda-feira, 0h de Brasília) os aparelhos fazem parte do loot
// reaparecer. O servidor só marca a virada, avisa quem está na sala e guarda se algum aparelho já fez a reposição
// desta semana (quem chega depois recebe os móveis prontos e não repete).
const WEEK_MS = 604800000, WEEK_OFFSET = 356400000, WEEK_TEST = process.env.WEEK_TEST === '1';   // WEEK_TEST: só nos testes automáticos
// WEEK_EXTRA: reposições fora de hora. Cada vez que este número sobe (aqui ou na variável WEEK_EXTRA do Render)
// a sala oficial ganha uma reposição na hora, sem mudar a virada normal de segunda-feira.
// 1 = reposição extra pedida pelo dono do jogo em 25/11/2026.
const WEEK_EXTRA = Number.isInteger(Number(process.env.WEEK_EXTRA)) && process.env.WEEK_EXTRA !== undefined && process.env.WEEK_EXTRA !== '' ? Number(process.env.WEEK_EXTRA) : 1;
let weekShift = 0;
const weekNow = () => Math.floor((Date.now() - WEEK_OFFSET) / WEEK_MS) + WEEK_EXTRA + weekShift;
// Peças trocáveis de um carro. Sem registro na sala, vale a peça de fábrica.
const PART_SLOTS = ['sparkPlug', 'battery', 'radiator', 'tireFrontLeft', 'tireFrontRight', 'tireRearLeft', 'tireRearRight', 'suspensionFrontLeft', 'suspensionFrontRight', 'suspensionRearLeft', 'suspensionRearRight'];
const partOf = (record, slot) => (isObject(record.mechanicalParts) && Object.hasOwn(record.mechanicalParts, slot) ? record.mechanicalParts[slot] : 'vehicle-part:' + record.id + ':' + slot);
const MAX_RTC_BYTES = 16 * 1024;   // combinação da conexão de voz entre dois jogadores
const RTC_RANGE = 160;             // metros: só jogadores próximos combinam conexão de voz
// Servidores de apoio da conexão de voz (opcional): ICE_SERVERS='[{"urls":"turn:...","username":"...","credential":"..."}]'
const ICE_SERVERS = (() => { try { const list = JSON.parse(process.env.ICE_SERVERS || 'null'); return Array.isArray(list) && list.length ? list.slice(0, 6) : null; } catch { return null; } })();
const RATE_PER_SECOND = 90;      // mensagens por segundo por conexão
const BYTE_RATE = 1.5 * 1024 * 1024;   // volume de dados por segundo por conexão (anti-amplificação)
const CHAT_COOLDOWN_MS = 600, HELLO_COOLDOWN_MS = 750, PROFILE_COOLDOWN_MS = 350;   // anti-spam por conexão
const IDLE_MS = 45000;           // sem mensagens => desconecta
const PROTOCOL = 1;

const started = Date.now();
const now = () => Math.round(performance.now());
const rooms = new Map();         // código -> Map(id -> player)
const worlds = new Map();        // código -> {doors, loot, zdead, revs, cars, touched}
let connections = 0, nextId = 1, relayed = 0;

const cleanRoom = value => String(value ?? '').toUpperCase().replace(/[^A-Z0-9_-]/g, '').slice(0, 24);
const cleanName = value => String(value ?? '').replace(/[\u0000-\u001f\u007f<>]/g, '').trim().slice(0, 24) || 'Sobrevivente';
const isObject = value => value !== null && typeof value === 'object' && !Array.isArray(value);

function send(socket, message) {
  if (socket.readyState === 1 && socket.bufferedAmount < 512 * 1024) socket.send(JSON.stringify(message));
}
function broadcast(room, message, except) {
  const text = JSON.stringify(message);
  for (const player of room.values()) {
    if (player === except) continue;
    // Um cliente travado não pode acumular fila: estados antigos são descartados.
    if (player.socket.readyState === 1 && player.socket.bufferedAmount < 256 * 1024) { player.socket.send(text); relayed++; }
  }
}
// Só a sala oficial tem reposição semanal de loot. As outras salas não recebem "semana" e nunca repõem.
// (Dá para trocar a sala oficial no Render com a variável OFFICIAL_ROOM, sem mexer no jogo.)
const OFFICIAL_ROOM = cleanRoom(process.env.OFFICIAL_ROOM || 'LTDOFICIAL');
// Só existe o servidor oficial: ninguém cria outra sala. (OPEN_ROOMS=1 libera salas à parte, só para os testes.)
const OPEN_ROOMS = process.env.OPEN_ROOMS === '1';
// Mapa mínimo para entrar: a v37 ampliou Cedros, Aurora e Livena. Quem está com o mapa antigo não veria as casas novas
// (atravessaria as paredes delas), então é avisado para atualizar. MIN_MAP=0 desliga a exigência.
const MIN_MAP = Math.max(0, Math.floor(Number(process.env.MIN_MAP ?? 37)) || 0);
function turnWeek(code) {
  if (code !== OFFICIAL_ROOM) return null;
  const world = worldOf(code), week = weekNow();
  if (world.week !== week) {
    world.week = week; world.refilled = false;
    const room = rooms.get(code); if (room) broadcast(room, { t: 'week', week }, null);
  }
  return week;
}
function worldOf(code) {
  let world = worlds.get(code);
  if (!world) { world = { doors: Object.create(null), doorCount: 0, loot: new Map(), lootGone: new Map(), zdead: new Map(), revs: new Map(), cars: new Map(), ground: new Map(), groundFloor: 0, groundBy: new Map(), revGone: new Map(), touched: Date.now(), week: weekNow() }; worlds.set(code, world); }
  world.touched = Date.now();
  return world;
}
const simple = value => value === null || typeof value === 'boolean' || typeof value === 'number' || (typeof value === 'string' && value.length <= 200);
const goodKey = key => typeof key === 'string' && key.length > 0 && key.length <= 160 && !key.startsWith('__');
const goodItem = item => isObject(item) && item.id != null && String(item.id).length <= 160 && JSON.stringify(item).length <= 4000;
function handleWorld(player, room, message) {
  const world = worldOf(player.room);
  if (message.k === 'door' && (isObject(message.c) || isObject(message.seed))) {
    const seeding = !isObject(message.c), source = seeding ? message.seed : message.c, changed = {};
    let any = false;
    for (const key of Object.keys(source)) {
      const value = source[key];
      if (!goodKey(key) || !(simple(value) || (isObject(value) && JSON.stringify(value).length <= (key.startsWith('obj:') ? 1500 : 400)))) continue;   // obj: caixote, gerador, coletor
      const known = key in world.doors;
      if (seeding && known) continue;                       // semente não troca o que a sala já sabe
      if (!known) { if (world.doorCount >= MAX_DOORS) continue; world.doorCount++; }
      world.doors[key] = value; changed[key] = value; any = true;
    }
    if (any && !seeding) broadcast(room, { t: 'w', k: 'door', c: changed }, player);
  } else if (message.k === 'rev' && Number.isInteger(message.id) && message.id >= 1000000 && message.id < 1e9) {
    // Zumbi de um jogador morto: o registro (aparência, equipamento e itens) fica na sala para quem entrar depois.
    const id = message.id; let entry = world.revs.get(id);
    if (world.revGone.has(id)) { send(player.socket, { t: 'w', k: 'rev', id, gone: 1 }); return; }   // corpo já apagado: o aparelho apaga também
    if (isObject(message.r)) {
      if (entry) return;                                                       // já conhecido
      const text = JSON.stringify(message.r);
      if (text.length > MAX_REV_BYTES || message.r.id !== id || !Array.isArray(message.r.cargo)) return;
      if (world.revs.size >= MAX_REVS) world.revs.delete(world.revs.keys().next().value);   // sai o mais antigo
      entry = { r: message.r, at: Date.now(), dead: null, taken: new Set() }; world.revs.set(id, entry);
      broadcast(room, { t: 'w', k: 'rev', id, r: entry.r, age: 0 }, player);
    } else if (entry && Array.isArray(message.dead) && message.dead.length === 3 && message.dead.every(Number.isFinite)) {
      if (entry.dead) return;                                                   // os itens caem uma vez só
      entry.dead = message.dead.map(v => Math.round(v * 100) / 100); entry.deadAt = Date.now();
      broadcast(room, { t: 'w', k: 'rev', id, dead: entry.dead }, player);
    } else if (entry && Array.isArray(message.take)) {
      const fresh = [];
      for (const item of message.take.slice(0, 120)) { if (typeof item !== 'string' || item.length > 120 || entry.taken.has(item) || entry.taken.size >= 400) continue; entry.taken.add(item); fresh.push(item); }
      if (fresh.length) broadcast(room, { t: 'w', k: 'rev', id, take: fresh }, player);
    }
  } else if (message.k === 'zk' && Array.isArray(message.list)) {
    // Zumbis mortos: guarda a maior geração conhecida de cada um e avisa os outros jogadores.
    const fresh = [];
    for (const entry of message.list.slice(0, 4000)) {
      if (!Array.isArray(entry)) continue;
      const id = entry[0], generation = Number(entry[1]) | 0;
      if (!(typeof id === 'number' ? Number.isFinite(id) : typeof id === 'string' && id.length > 0 && id.length <= 80) || generation < 0) continue;
      const known = world.zdead.get(id);
      if (known !== undefined && known >= generation) continue;
      if (known === undefined && world.zdead.size >= MAX_DEAD_ZOMBIES) continue;
      world.zdead.set(id, generation); fresh.push([id, generation]);
    }
    if (fresh.length && !message.seed) broadcast(room, { t: 'w', k: 'zk', list: fresh }, player);
  } else if (message.k === 'car' && (isObject(message.c) || isObject(message.seed))) {
    // Carros: a semente só entra se a sala ainda não conhece aquele carro (quem chegou primeiro define a frota);
    // uma atualização (carro estacionado, resumo de quem dirige) sempre substitui.
    const seeding = !isObject(message.c), source = seeding ? message.seed : message.c, changed = {}, back = {};
    let any = false, anyBack = false, okay = null, deny = null;
    for (const key of Object.keys(source).slice(0, MAX_CARS)) {
      const value = source[key];
      if (!goodKey(key) || !isObject(value) || value.id !== key || JSON.stringify(value).length > MAX_CAR_BYTES) continue;
      const known = world.cars.has(key);
      if (seeding && known) { back[key] = world.cars.get(key); anyBack = true; continue; }
      if (!known && world.cars.size >= MAX_CARS) continue;
      // Troca de peça: quem manda declara a peça que viu instalada (exp). Se outro jogador já mexeu nela, a troca
      // é recusada e vale o que a sala tem; assim a mesma peça nunca vai para dois inventários.
      if (known && message.pv === 1 && !key.startsWith('tr:')) {
        const old = world.cars.get(key), exp = isObject(message.exp) && isObject(message.exp[key]) ? message.exp[key] : null;
        let fixed = false;
        for (const slot of PART_SLOTS) {
          const declared = !!exp && Object.hasOwn(exp, slot), a = partOf(old, slot), b = partOf(value, slot);
          if (a === b || (declared && exp[slot] === a)) { if (declared) { if (!okay) okay = {}; if (!okay[key]) okay[key] = []; okay[key].push(slot); } continue; }
          if (!isObject(value.mechanicalParts)) value.mechanicalParts = {};
          if (isObject(old.mechanicalParts) && Object.hasOwn(old.mechanicalParts, slot)) value.mechanicalParts[slot] = old.mechanicalParts[slot]; else delete value.mechanicalParts[slot];
          if (isObject(value.condition) && isObject(old.condition) && Number.isFinite(old.condition[slot])) value.condition[slot] = old.condition[slot];
          fixed = true; if (declared) { if (!deny) deny = {}; if (!deny[key]) deny[key] = []; deny[key].push(slot); }
        }
        if (fixed) { back[key] = value; anyBack = true; }
      }
      world.cars.set(key, value); changed[key] = value; any = true;
    }
    if (any) broadcast(room, { t: 'w', k: 'car', c: changed }, player);
    if (anyBack || okay || deny) send(player.socket, { t: 'w', k: 'car', c: back, ...(okay ? { ok: okay } : {}), ...(deny ? { deny } : {}) });   // semente atrasada ou troca de peça: vale o que a sala tem
  } else if (message.k === 'gnd' && Array.isArray(message.ops)) {
    // Itens no chão: [id, registro] = está no chão (posição e dados do item); [id, 0] = alguém pegou.
    // A semente (quem entra) não troca o que a sala já sabe.
    const fresh = [], lost = [], time = Date.now(), seeding = !!message.seed;
    for (const [item, info] of world.groundBy) { if (time - info.at > RACE_MS) world.groundBy.delete(item); else break; }
    for (const op of message.ops.slice(0, 120)) {
      if (!Array.isArray(op) || !goodKey(op[0])) continue;
      const item = op[0], value = op[1], known = world.ground.get(item);
      if (seeding && known !== undefined) continue;
      if (value === 0) {
        if (known === 0) { const info = world.groundBy.get(item); if (!seeding && info && info.by !== player.cid) lost.push(item); continue; }
        if (known === undefined && world.ground.size >= MAX_GROUND) { const old = [...world.ground].find(([, v]) => v === 0); if (!old) continue; world.ground.delete(old[0]); }
        if (known) world.groundFloor--;
        world.ground.delete(item); world.ground.set(item, 0);
        world.groundBy.delete(item); world.groundBy.set(item, { by: player.cid, at: time });
        fresh.push([item, 0]);
      } else if (isObject(value) && Array.isArray(value.position) && value.position.length === 3 && value.position.every(Number.isFinite) && JSON.stringify(value).length <= MAX_GROUND_BYTES) {
        if (!known && world.groundFloor >= MAX_GROUND_FLOOR) continue;
        if (known === undefined && world.ground.size >= MAX_GROUND) { const old = [...world.ground].find(([, v]) => v === 0); if (!old) continue; world.ground.delete(old[0]); }
        if (!known) world.groundFloor++;
        world.ground.set(item, value); world.groundBy.delete(item);
        fresh.push([item, value]);
      }
    }
    if (fresh.length) broadcast(room, { t: 'w', k: 'gnd', ops: fresh }, player);
    if (lost.length) send(player.socket, { t: 'w', k: 'lost', from: 'gnd', items: lost });
  } else if (message.k === 'loot' && goodKey(message.id)) {
    const id = message.id, full = Array.isArray(message.full) ? message.full.filter(goodItem).slice(0, MAX_CONTAINER_ITEMS) : null;
    let list = world.loot.get(id);
    if (!list) {
      if (!full || world.loot.size >= MAX_CONTAINERS) return;
      list = full; world.loot.set(id, list);
    } else if (!message.seed) {
      if (Array.isArray(message.del)) {
        const gone = new Set(message.del.slice(0, MAX_CONTAINER_ITEMS).map(String)), time = Date.now();
        let taken = world.lootGone.get(id); if (!taken) { taken = new Map(); world.lootGone.set(id, taken); if (world.lootGone.size > 400) world.lootGone.delete(world.lootGone.keys().next().value); }
        for (const [item, info] of taken) if (time - info.at > RACE_MS) taken.delete(item);
        const present = new Set(list.map(item => String(item.id))), lost = [];
        // Item que outro jogador tirou deste baú há pouco: quem chegou depois perde a disputa.
        for (const item of gone) { if (present.has(item)) taken.set(item, { by: player.cid, at: time }); else { const info = taken.get(item); if (info && info.by !== player.cid) lost.push(item); } }
        if (lost.length) send(player.socket, { t: 'w', k: 'lost', from: 'loot', id, items: lost });
        list = list.filter(item => !gone.has(String(item.id)));
      }
      if (Array.isArray(message.put)) for (const item of message.put.slice(0, MAX_CONTAINER_ITEMS)) { if (!goodItem(item)) continue; const at = list.findIndex(other => String(other.id) === String(item.id)); if (at >= 0) list[at] = item; else if (list.length < MAX_CONTAINER_ITEMS) list.push(item); }
      world.loot.set(id, list);
    } else return;                                           // semente de baú que a sala já conhece
    broadcast(room, { t: 'w', k: 'loot', id, v: list }, player);
    // Quem enviou só recebe de volta se a junção no servidor deu um resultado diferente do dele.
    if (full && JSON.stringify(full) !== JSON.stringify(list)) send(player.socket, { t: 'w', k: 'loot', id, v: list });
  }
}
// Apaga os corpos de jogadores com mais de 1 h: o registro, o saque do cadáver e os itens que ficaram no chão.
function expireCorpses(code, world, time = Date.now()) {
  const room = rooms.get(code), groundOps = [];
  for (const [id, entry] of world.revs) {
    const since = entry.r?.pvp ? entry.at : entry.deadAt;
    if (!since || time - since <= CORPSE_MS) continue;
    world.revs.delete(id); world.loot.delete('corpse43:' + id); world.lootGone.delete('corpse43:' + id);
    for (const item of Array.isArray(entry.r?.cargo) ? entry.r.cargo : []) {
      const key = item && item.id != null ? String(item.id) : null, known = key && world.ground.get(key);
      if (known) { world.ground.set(key, 0); world.groundFloor--; groundOps.push([key, 0]); }
    }
    world.revGone.set(id, time); if (world.revGone.size > MAX_REV_GONE) world.revGone.delete(world.revGone.keys().next().value);
    if (room) broadcast(room, { t: 'w', k: 'rev', id, gone: 1 }, null);
  }
  if (room && groundOps.length) for (let i = 0; i < groundOps.length; i += 120) broadcast(room, { t: 'w', k: 'gnd', ops: groundOps.slice(i, i + 120) }, null);
}
function leave(player) {
  if (!player.room) return;
  const room = rooms.get(player.room);
  if (room) {
    room.delete(player.id);
    if (room.size) broadcast(room, { t: 'leave', id: player.id });
    else rooms.delete(player.room);
  }
  player.room = null;
}

const server = http.createServer((request, response) => {
  const path = new URL(request.url, 'http://localhost').pathname;
  const headers = { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'Access-Control-Allow-Origin': '*' };
  if (path === '/health' || path === '/') {
    let players = 0; for (const room of rooms.values()) players += room.size;
    response.writeHead(200, headers);
    response.end(JSON.stringify({ ok: true, service: 'left-to-die-mp', protocol: PROTOCOL, world: 1, rev: 1, car: 1, ground: 1, ack: 1, voice: 1, corpse: Math.round(CORPSE_MS / 60000), official: OFFICIAL_ROOM, onlyOfficial: OPEN_ROOMS ? 0 : 1, map: MIN_MAP, hardened: 1, rooms: rooms.size, worlds: worlds.size, players, uptimeSeconds: Math.round((Date.now() - started) / 1000) }));
    return;
  }
  response.writeHead(404, headers); response.end('{"ok":false}');
});

const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_WORLD_BYTES + 1024, perMessageDeflate: false });
server.on('upgrade', (request, socket, head) => {
  const path = new URL(request.url, 'http://localhost').pathname;
  if (path !== '/mp' || connections >= MAX_CONNECTIONS) { socket.destroy(); return; }
  wss.handleUpgrade(request, socket, head, ws => wss.emit('connection', ws, request));
});

wss.on('connection', socket => {
  connections++;
  const player = { id: null, name: 'Sobrevivente', room: null, socket, state: null, stateAt: 0, profile: null, last: Date.now(), bucket: RATE_PER_SECOND, bucketAt: Date.now(), bytes: BYTE_RATE, bytesAt: Date.now(), lastChat: 0, lastHello: 0, lastProfile: 0, lastPos: null };
  socket._socket?.setNoDelay?.(true);   // sem agrupamento de pacotes: menor latência

  socket.on('message', (data, isBinary) => {
    const time = Date.now();
    player.last = time;
    player.bucket = Math.min(RATE_PER_SECOND, player.bucket + (time - player.bucketAt) / 1000 * RATE_PER_SECOND);
    player.bucketAt = time;
    if (player.bucket < 1) return;      // acima do limite: descarta
    player.bucket -= 1;
    // Volume de dados por segundo: impede que um cliente mande mensagens grandes em rajada (perfil ou
    // mundo de centenas de KB) para forçar o servidor a reenviar isso a todos da sala (amplificação).
    player.bytes = Math.min(BYTE_RATE, player.bytes + (time - player.bytesAt) / 1000 * BYTE_RATE);
    player.bytesAt = time;
    if (player.bytes < data.length) return;
    player.bytes -= data.length;
    if (isBinary) return;
    let message;
    try { message = JSON.parse(data.toString()); } catch { return; }
    if (!isObject(message)) return;
    // Nenhuma mensagem de um cliente pode derrubar o servidor: erros ao tratá-la são contidos aqui.
    try {

    if (message.t === 'ping') { send(socket, { t: 'pong', c: Number(message.c) || 0, now: now() }); return; }

    if (message.t === 'hello') {
      if (time - player.lastHello < HELLO_COOLDOWN_MS) return;
      player.lastHello = time;
      if (player.room) leave(player);
      if (Number(message.v) !== PROTOCOL) { send(socket, { t: 'err', code: 'version', msg: 'Versão do jogo diferente da versão do servidor.' }); return; }
      if ((Math.floor(Number(message.map)) || 0) < MIN_MAP) { send(socket, { t: 'err', code: 'version', msg: 'O mapa do servidor foi ampliado. Atualize o jogo para a versão mais nova (v' + MIN_MAP + ' ou mais) para entrar.' }); return; }
      const code = cleanRoom(message.room);
      if (!code) { send(socket, { t: 'err', code: 'room', msg: 'Informe o código da sala.' }); return; }
      if (code !== OFFICIAL_ROOM && !OPEN_ROOMS) { send(socket, { t: 'err', code: 'room', msg: 'Agora só existe o servidor oficial ' + OFFICIAL_ROOM + '. Atualize o jogo ou use esse código de sala.' }); return; }
      let room = rooms.get(code);
      if (!room) {
        if (rooms.size >= MAX_ROOMS) { send(socket, { t: 'err', code: 'busy', msg: 'Servidor cheio. Tente mais tarde.' }); return; }
        room = new Map(); rooms.set(code, room);
      }
      if (room.size >= MAX_ROOM_PLAYERS) { send(socket, { t: 'err', code: 'full', msg: 'O servidor está cheio (' + MAX_ROOM_PLAYERS + ' jogadores). Tente de novo daqui a pouco.' }); return; }
      player.id = 'p' + (nextId++).toString(36);
      // Identidade do aparelho (fica igual ao reconectar): usada só para decidir disputas por itens.
      player.cid = typeof message.cid === 'string' && /^[A-Za-z0-9_-]{8,40}$/.test(message.cid) ? message.cid : player.id;
      player.name = cleanName(message.name);
      player.room = code; player.state = null; player.profile = null;
      room.set(player.id, player);
      send(socket, {
        t: 'welcome', id: player.id, room: code, now: now(), week: turnWeek(code), refilled: worldOf(code).refilled === true, max: MAX_ROOM_PLAYERS, caps: ['world1', 'zk1', 'zm1', 'zh1', 'rev1', 'car1', 'gnd1', 'loot2', 'ack1', 'rtc1', 'carp1', 'week1'], ...(ICE_SERVERS ? { ice: ICE_SERVERS } : {}),
        world: (w => (expireCorpses(code, w), { doors: w.doors, loot: Object.fromEntries(w.loot), zdead: [...w.zdead], revs: [...w.revs].map(([id, v]) => ({ id, r: v.r, age: Date.now() - v.at, dead: v.dead, taken: [...v.taken] })), revGone: [...w.revGone.keys()], cars: Object.fromEntries(w.cars), ground: [...w.ground] }))(worldOf(code)),
        players: [...room.values()].filter(other => other !== player).map(other => ({ id: other.id, name: other.name, p: other.profile, d: other.state, st: other.stateAt })),
      });
      broadcast(room, { t: 'join', id: player.id, name: player.name }, player);
      return;
    }

    const room = player.room && rooms.get(player.room);
    if (!room) return;

    if (message.t === 's') {
      if (!isObject(message.d) || data.length > MAX_STATE_BYTES) return;
      // Posição precisa ser um número de verdade: lixo (NaN, infinito) não é guardado nem repassado,
      // então um cliente adulterado não consegue aparecer em lugar nenhum no mapa dos outros.
      const _d = message.d;
      if ((_d.x !== undefined && !Number.isFinite(_d.x)) || (_d.z !== undefined && !Number.isFinite(_d.z)) || (_d.h !== undefined && !Number.isFinite(_d.h))) return;
      // Anti-teletransporte: entre dois avisos a posição não pode saltar o impossível. Renascer (muda o
      // contador de mortes) e dirigir (está em veículo) são exceções. Um salto além do limite é "puxado"
      // de volta ao passo máximo, então um cliente adulterado não se teletransporta na frente dos outros
      // (e nenhum jogador honesto é afetado, pois nunca chega perto do limite).
      const prev = player.lastPos;
      if (prev && Number.isFinite(_d.x) && Number.isFinite(_d.z) && (_d.rs | 0) === prev.rs && !_d.veh && !prev.veh) {
        const dt = Math.max(0.05, (time - prev.t) / 1000), limit = 20 * dt + 5;
        const dx = _d.x - prev.x, dz = _d.z - prev.z, dist = Math.hypot(dx, dz);
        if (dist > limit) { const k = limit / dist; message.d = { ..._d, x: prev.x + dx * k, z: prev.z + dz * k }; }
      }
      const _sx = message.d.x, _sz = message.d.z;
      player.lastPos = (Number.isFinite(_sx) && Number.isFinite(_sz)) ? { x: _sx, z: _sz, rs: message.d.rs | 0, veh: !!message.d.veh, t: time } : null;
      player.state = message.d; player.stateAt = now();
      broadcast(room, { t: 's', id: player.id, st: player.stateAt, d: message.d }, player);
      // Carro que este jogador está dirigindo: a sala guarda a última posição dele (e da carreta puxada),
      // então quem entrar depois, ou quem ficar quando o motorista cair, vê o carro onde ele realmente está.
      const car = message.d.car;
      if (isObject(car) && car.seat === 'driver' && typeof car.id === 'string' && Number.isFinite(car.x) && Number.isFinite(car.z)) {
        const world = worlds.get(player.room), stored = world && world.cars.get(car.id);
        if (stored) {
          stored.x = car.x; stored.z = car.z; if (Number.isFinite(car.h)) stored.heading = car.h; if (Number.isFinite(car.fu)) stored.fuel = car.fu;
          stored.engineOn = !!car.en; stored.headlights = !!car.hl; stored.reverse = !!car.rv; stored.speed = 0;
          if (Number.isFinite(car.ic)) stored.impactCount = car.ic; if (Array.isArray(car.bw)) stored.brokenWindows = car.bw.slice(0, 8);
          const tow = car.tw, trailer = Array.isArray(tow) && typeof tow[0] === 'string' ? world.cars.get('tr:' + tow[0]) : null;
          if (trailer && isObject(trailer.tr) && [tow[1], tow[2], tow[3]].every(Number.isFinite)) { trailer.tr.x = tow[1]; trailer.tr.z = tow[2]; trailer.tr.heading = tow[3]; trailer.tr.attachedTo = car.id; }
        }
      }
    } else if (message.t === 'p') {
      if (!isObject(message.d) || data.length > MAX_PROFILE_BYTES) return;
      if (time - player.lastProfile < PROFILE_COOLDOWN_MS) return;
      player.lastProfile = time;
      if (typeof message.d.name === 'string') { player.name = cleanName(message.d.name); message.d.name = player.name; }
      player.profile = message.d;
      broadcast(room, { t: 'p', id: player.id, d: message.d }, player);
    } else if (message.t === 'z') {
      // Posições dos zumbis que este jogador está simulando: só retransmite, nada é guardado.
      if (!Array.isArray(message.list) || data.length > 12288) return;
      const relay = { t: 'z', id: player.id, list: message.list.slice(0, 48) };
      if (Array.isArray(message.hp) && message.hp.length) relay.hp = message.hp.slice(0, 32);     // vida que mudou
      if (Array.isArray(message.fx) && message.fx.length) relay.fx = message.fx.slice(0, 24);     // quedas e pulos de janela
      broadcast(room, relay, player);
    } else if (message.t === 'w') {
      if (data.length > MAX_WORLD_BYTES) return;
      // Confirmação: o jogo reenvia a mudança do mundo que não for confirmada (mensagem descartada pelo limite).
      if (Number.isInteger(message.q) && message.q > 0) send(player.socket, { t: 'w', k: 'ack', q: message.q });
      try { handleWorld(player, room, message); } catch {}
    } else if (message.t === 'week') {
      if (player.room !== OFFICIAL_ROOM) return;
      const world = worldOf(player.room); if (Number.isInteger(message.done) && message.done === world.week) world.refilled = true;
      if (WEEK_TEST && message.bump === 1) { weekShift++; turnWeek(player.room); }   // teste: vira a semana agora
    } else if (message.t === 'rtc') {
      // Voz por proximidade: a voz vai direto de um aparelho para o outro; aqui só passa a combinação da conexão,
      // e só entre jogadores da mesma sala que estão perto um do outro.
      const other = typeof message.to === 'string' ? room.get(message.to) : null;
      if (!other || other === player || !isObject(message.d) || data.length > MAX_RTC_BYTES) return;
      const a = player.state, b = other.state;
      if (message.d.k !== 'bye' && a && b && [a.x, a.z, b.x, b.z].every(Number.isFinite) && Math.hypot(a.x - b.x, a.z - b.z) > RTC_RANGE) return;
      send(other.socket, { t: 'rtc', from: player.id, d: message.d });
    } else if (message.t === 'c') {
      const text = String(message.m ?? '').replace(/[\u0000-\u001f\u007f]/g, ' ').trim().slice(0, MAX_CHAT_CHARS);
      if (text && time - player.lastChat >= CHAT_COOLDOWN_MS) { player.lastChat = time; broadcast(room, { t: 'c', id: player.id, name: player.name, m: text }, null); }
    }
    } catch {}
  });

  socket.on('close', () => { connections--; leave(player); });
  socket.on('error', () => {});
  socket.isAlive = true;
  socket.on('pong', () => { socket.isAlive = true; });
  socket.player = player;
});

// Conexões mortas ou paradas são encerradas para liberar a sala.
setInterval(() => {
  const time = Date.now();
  for (const socket of wss.clients) {
    if (!socket.isAlive || time - socket.player.last > IDLE_MS) { socket.terminate(); continue; }
    socket.isAlive = false;
    try { socket.ping(); } catch {}
  }
  for (const [code, world] of worlds) if (!rooms.has(code) && time - world.touched > WORLD_KEEP_MS) worlds.delete(code);
  for (const [code, world] of worlds) expireCorpses(code, world, time);
  for (const code of rooms.keys()) { const world = worlds.get(code); if (world) world.touched = time; turnWeek(code); }
}, 20000).unref();

server.listen(PORT, '0.0.0.0', () => console.log(`Left to Die MP ouvindo na porta ${PORT}`));
