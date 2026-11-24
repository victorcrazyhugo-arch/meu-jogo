// Left to Die — servidor de salas (etapa 3: jogadores, chat, mundo da sala e carros).
// Retransmite o estado de cada jogador e guarda em memória o mundo de cada sala (portas, baús e carros),
// para quem entrar depois receber tudo igual. Nada vai para disco: se o servidor reiniciar,
// o primeiro jogador que voltar reenvia o que tem salvo.
// Uso: PORT=8080 node server.js
import http from 'node:http';
import { WebSocketServer } from 'ws';

const PORT = Number(process.env.PORT) || 8080;
const MAX_ROOM_PLAYERS = Number(process.env.MAX_ROOM_PLAYERS) || 16;
const MAX_ROOMS = Number(process.env.MAX_ROOMS) || 300;
const MAX_CONNECTIONS = Number(process.env.MAX_CONNECTIONS) || 600;
const MAX_STATE_BYTES = 4096;
const MAX_REVS = 40, MAX_REV_BYTES = 60 * 1024;   // zumbis de jogadores mortos guardados por sala
const MAX_CARS = 160, MAX_CAR_BYTES = 8 * 1024;    // carros e carretas parados (posição, combustível, peças)
const MAX_PROFILE_BYTES = 96 * 1024;
const MAX_WORLD_BYTES = 400 * 1024;   // uma mensagem de mundo (semente de portas, baú grande)
const MAX_DOORS = 8000, MAX_CONTAINERS = 6000, MAX_CONTAINER_ITEMS = 240, MAX_DEAD_ZOMBIES = 60000;
const WORLD_KEEP_MS = 6 * 60 * 60 * 1000;   // sala vazia mantém o mundo por 6 horas
const MAX_CHAT_CHARS = 200;
const RATE_PER_SECOND = 45;      // mensagens por segundo por conexão
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
function worldOf(code) {
  let world = worlds.get(code);
  if (!world) { world = { doors: Object.create(null), doorCount: 0, loot: new Map(), zdead: new Map(), revs: new Map(), cars: new Map(), touched: Date.now() }; worlds.set(code, world); }
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
      if (!goodKey(key) || !(simple(value) || (isObject(value) && JSON.stringify(value).length <= 400))) continue;
      const known = key in world.doors;
      if (seeding && known) continue;                       // semente não troca o que a sala já sabe
      if (!known) { if (world.doorCount >= MAX_DOORS) continue; world.doorCount++; }
      world.doors[key] = value; changed[key] = value; any = true;
    }
    if (any && !seeding) broadcast(room, { t: 'w', k: 'door', c: changed }, player);
  } else if (message.k === 'rev' && Number.isInteger(message.id) && message.id >= 1000000 && message.id < 1e9) {
    // Zumbi de um jogador morto: o registro (aparência, equipamento e itens) fica na sala para quem entrar depois.
    const id = message.id; let entry = world.revs.get(id);
    if (isObject(message.r)) {
      if (entry) return;                                                       // já conhecido
      const text = JSON.stringify(message.r);
      if (text.length > MAX_REV_BYTES || message.r.id !== id || !Array.isArray(message.r.cargo)) return;
      if (world.revs.size >= MAX_REVS) world.revs.delete(world.revs.keys().next().value);   // sai o mais antigo
      entry = { r: message.r, at: Date.now(), dead: null, taken: new Set() }; world.revs.set(id, entry);
      broadcast(room, { t: 'w', k: 'rev', id, r: entry.r, age: 0 }, player);
    } else if (entry && Array.isArray(message.dead) && message.dead.length === 3 && message.dead.every(Number.isFinite)) {
      if (entry.dead) return;                                                   // os itens caem uma vez só
      entry.dead = message.dead.map(v => Math.round(v * 100) / 100);
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
    let any = false, anyBack = false;
    for (const key of Object.keys(source).slice(0, MAX_CARS)) {
      const value = source[key];
      if (!goodKey(key) || !isObject(value) || value.id !== key || JSON.stringify(value).length > MAX_CAR_BYTES) continue;
      const known = world.cars.has(key);
      if (seeding && known) { back[key] = world.cars.get(key); anyBack = true; continue; }
      if (!known && world.cars.size >= MAX_CARS) continue;
      world.cars.set(key, value); changed[key] = value; any = true;
    }
    if (any) broadcast(room, { t: 'w', k: 'car', c: changed }, player);
    if (anyBack) send(player.socket, { t: 'w', k: 'car', c: back });   // semente atrasada: vale o que a sala já tinha
  } else if (message.k === 'loot' && goodKey(message.id)) {
    const id = message.id, full = Array.isArray(message.full) ? message.full.filter(goodItem).slice(0, MAX_CONTAINER_ITEMS) : null;
    let list = world.loot.get(id);
    if (!list) {
      if (!full || world.loot.size >= MAX_CONTAINERS) return;
      list = full; world.loot.set(id, list);
    } else if (!message.seed) {
      if (Array.isArray(message.del)) { const gone = new Set(message.del.slice(0, MAX_CONTAINER_ITEMS).map(String)); list = list.filter(item => !gone.has(String(item.id))); }
      if (Array.isArray(message.put)) for (const item of message.put.slice(0, MAX_CONTAINER_ITEMS)) { if (!goodItem(item)) continue; const at = list.findIndex(other => String(other.id) === String(item.id)); if (at >= 0) list[at] = item; else if (list.length < MAX_CONTAINER_ITEMS) list.push(item); }
      world.loot.set(id, list);
    } else return;                                           // semente de baú que a sala já conhece
    broadcast(room, { t: 'w', k: 'loot', id, v: list }, player);
    // Quem enviou só recebe de volta se a junção no servidor deu um resultado diferente do dele.
    if (full && JSON.stringify(full) !== JSON.stringify(list)) send(player.socket, { t: 'w', k: 'loot', id, v: list });
  }
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
    response.end(JSON.stringify({ ok: true, service: 'left-to-die-mp', protocol: PROTOCOL, world: 1, rev: 1, car: 1, hardened: 1, rooms: rooms.size, worlds: worlds.size, players, uptimeSeconds: Math.round((Date.now() - started) / 1000) }));
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
      const code = cleanRoom(message.room);
      if (!code) { send(socket, { t: 'err', code: 'room', msg: 'Informe o código da sala.' }); return; }
      let room = rooms.get(code);
      if (!room) {
        if (rooms.size >= MAX_ROOMS) { send(socket, { t: 'err', code: 'busy', msg: 'Servidor cheio. Tente mais tarde.' }); return; }
        room = new Map(); rooms.set(code, room);
      }
      if (room.size >= MAX_ROOM_PLAYERS) { send(socket, { t: 'err', code: 'full', msg: 'A sala está cheia.' }); return; }
      player.id = 'p' + (nextId++).toString(36);
      player.name = cleanName(message.name);
      player.room = code; player.state = null; player.profile = null;
      room.set(player.id, player);
      send(socket, {
        t: 'welcome', id: player.id, room: code, now: now(), max: MAX_ROOM_PLAYERS, caps: ['world1', 'zk1', 'zm1', 'zh1', 'rev1', 'car1'],
        world: (w => ({ doors: w.doors, loot: Object.fromEntries(w.loot), zdead: [...w.zdead], revs: [...w.revs].map(([id, v]) => ({ id, r: v.r, age: Date.now() - v.at, dead: v.dead, taken: [...v.taken] })), cars: Object.fromEntries(w.cars) }))(worldOf(code)),
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
      try { handleWorld(player, room, message); } catch {}
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
  for (const code of rooms.keys()) { const world = worlds.get(code); if (world) world.touched = time; }
}, 20000).unref();

server.listen(PORT, '0.0.0.0', () => console.log(`Left to Die MP ouvindo na porta ${PORT}`));
