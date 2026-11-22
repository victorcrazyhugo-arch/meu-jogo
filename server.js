// Left to Die — servidor de salas (etapa 1: presença dos jogadores e chat).
// Retransmite o estado de cada jogador para os outros da mesma sala. Não guarda nada em disco.
// Uso: PORT=8080 node server.js
import http from 'node:http';
import { WebSocketServer } from 'ws';

const PORT = Number(process.env.PORT) || 8080;
const MAX_ROOM_PLAYERS = Number(process.env.MAX_ROOM_PLAYERS) || 16;
const MAX_ROOMS = Number(process.env.MAX_ROOMS) || 300;
const MAX_CONNECTIONS = Number(process.env.MAX_CONNECTIONS) || 600;
const MAX_STATE_BYTES = 4096;
const MAX_PROFILE_BYTES = 96 * 1024;
const MAX_CHAT_CHARS = 200;
const RATE_PER_SECOND = 45;      // mensagens por segundo por conexão
const IDLE_MS = 45000;           // sem mensagens => desconecta
const PROTOCOL = 1;

const started = Date.now();
const now = () => Math.round(performance.now());
const rooms = new Map();         // código -> Map(id -> player)
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
    response.end(JSON.stringify({ ok: true, service: 'left-to-die-mp', protocol: PROTOCOL, rooms: rooms.size, players, uptimeSeconds: Math.round((Date.now() - started) / 1000) }));
    return;
  }
  response.writeHead(404, headers); response.end('{"ok":false}');
});

const wss = new WebSocketServer({ noServer: true, maxPayload: MAX_PROFILE_BYTES + 1024, perMessageDeflate: false });
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
        t: 'welcome', id: player.id, room: code, now: now(), max: MAX_ROOM_PLAYERS,
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
}, 20000).unref();

server.listen(PORT, '0.0.0.0', () => console.log(`Left to Die MP ouvindo na porta ${PORT}`));
