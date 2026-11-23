// Left to Die — servidor de salas (etapa 2: jogadores, chat e mundo da sala).
// Retransmite o estado de cada jogador e guarda em memória o mundo de cada sala (portas e baús),
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
const MAX_PROFILE_BYTES = 96 * 1024;
const MAX_WORLD_BYTES = 400 * 1024;   // uma mensagem de mundo (semente de portas, baú grande)
const MAX_DOORS = 8000, MAX_CONTAINERS = 6000, MAX_CONTAINER_ITEMS = 240, MAX_DEAD_ZOMBIES = 60000;
const WORLD_KEEP_MS = 6 * 60 * 60 * 1000;   // sala vazia mantém o mundo por 6 horas
const MAX_CHAT_CHARS = 200;
const RATE_PER_SECOND = 45;      // mensagens por segundo por conexão
const IDLE_MS = 45000;           // sem mensagens => desconecta
const PROTOCOL = 1;

const started = Date.now();
const now = () => Math.round(performance.now());
const rooms = new Map();         // código -> Map(id -> player)
const worlds = new Map();        // código -> {doors, loot, touched}
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
  if (!world) { world = { doors: Object.create(null), doorCount: 0, loot: new Map(), zdead: new Map(), touched: Date.now() }; worlds.set(code, world); }
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
    response.end(JSON.stringify({ ok: true, service: 'left-to-die-mp', protocol: PROTOCOL, world: 1, rooms: rooms.size, worlds: worlds.size, players, uptimeSeconds: Math.round((Date.now() - started) / 1000) }));
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
  const player = { id: null, name: 'Sobrevivente', room: null, socket, state: null, stateAt: 0, profile: null, last: Date.now(), bucket: RATE_PER_SECOND, bucketAt: Date.now() };
  socket._socket?.setNoDelay?.(true);   // sem agrupamento de pacotes: menor latência

  socket.on('message', (data, isBinary) => {
    const time = Date.now();
    player.last = time;
    player.bucket = Math.min(RATE_PER_SECOND, player.bucket + (time - player.bucketAt) / 1000 * RATE_PER_SECOND);
    player.bucketAt = time;
    if (player.bucket < 1) return;      // acima do limite: descarta
    player.bucket -= 1;
    if (isBinary) return;
    let message;
    try { message = JSON.parse(data.toString()); } catch { return; }
    if (!isObject(message)) return;

    if (message.t === 'ping') { send(socket, { t: 'pong', c: Number(message.c) || 0, now: now() }); return; }

    if (message.t === 'hello') {
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
        t: 'welcome', id: player.id, room: code, now: now(), max: MAX_ROOM_PLAYERS, caps: ['world1', 'zk1', 'zm1', 'zh1'],
        world: (w => ({ doors: w.doors, loot: Object.fromEntries(w.loot), zdead: [...w.zdead] }))(worldOf(code)),
        players: [...room.values()].filter(other => other !== player).map(other => ({ id: other.id, name: other.name, p: other.profile, d: other.state, st: other.stateAt })),
      });
      broadcast(room, { t: 'join', id: player.id, name: player.name }, player);
      return;
    }

    const room = player.room && rooms.get(player.room);
    if (!room) return;

    if (message.t === 's') {
      if (!isObject(message.d) || data.length > MAX_STATE_BYTES) return;
      player.state = message.d; player.stateAt = now();
      broadcast(room, { t: 's', id: player.id, st: player.stateAt, d: message.d }, player);
    } else if (message.t === 'p') {
      if (!isObject(message.d) || data.length > MAX_PROFILE_BYTES) return;
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
      if (text) broadcast(room, { t: 'c', id: player.id, name: player.name, m: text }, null);
    }
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
