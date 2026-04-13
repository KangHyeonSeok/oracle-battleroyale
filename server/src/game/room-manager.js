/**
 * Room Manager
 *
 * Tracks in-memory WebSocket connections per match room.
 * Rooms are keyed by matchId (number).
 *
 * Each room entry: Map<ws, { characterId, userId }>
 */

/** @type {Map<number, Map<object, {characterId: number|null, userId: number|null, spectator: boolean}>>} */
const rooms = new Map();

/**
 * Add a WebSocket client to a room.
 * @param {number} matchId
 * @param {object} ws - WebSocket instance
 * @param {object} meta - { characterId, userId }
 */
function joinRoom(matchId, ws, meta = {}) {
  if (!rooms.has(matchId)) {
    rooms.set(matchId, new Map());
  }
  rooms.get(matchId).set(ws, {
    characterId: meta.characterId || null,
    userId: meta.userId || null,
    spectator: meta.spectator === true,
  });
  console.log(`[room-manager] ws joined match ${matchId}, total in room: ${rooms.get(matchId).size}`);
}

/**
 * Remove a WebSocket client from all rooms it is in.
 * @param {object} ws
 */
function leaveAllRooms(ws) {
  for (const [matchId, clients] of rooms.entries()) {
    if (clients.has(ws)) {
      clients.delete(ws);
      console.log(`[room-manager] ws left match ${matchId}, remaining: ${clients.size}`);
      if (clients.size === 0) {
        rooms.delete(matchId);
        console.log(`[room-manager] room ${matchId} removed (empty)`);
      }
    }
  }
}

/**
 * Remove a WebSocket from a specific room.
 * @param {number} matchId
 * @param {object} ws
 */
function leaveRoom(matchId, ws) {
  const room = rooms.get(matchId);
  if (!room) return;
  room.delete(ws);
  console.log(`[room-manager] ws left match ${matchId}, remaining: ${room.size}`);
  if (room.size === 0) {
    rooms.delete(matchId);
    console.log(`[room-manager] room ${matchId} removed (empty)`);
  }
}

/**
 * Broadcast a message to all connected clients in a room.
 * Dead connections are pruned automatically.
 * @param {number} matchId
 * @param {object} message - will be JSON.stringified
 */
function broadcastToRoom(matchId, message) {
  const room = rooms.get(matchId);
  if (!room || room.size === 0) return;

  const payload = JSON.stringify(message);
  const dead = [];

  for (const [ws] of room.entries()) {
    if (ws.readyState === 1 /* OPEN */) {
      try {
        ws.send(payload);
      } catch (err) {
        console.error(`[room-manager] send error in match ${matchId}:`, err.message);
        dead.push(ws);
      }
    } else {
      dead.push(ws);
    }
  }

  for (const ws of dead) {
    room.delete(ws);
  }
}

/**
 * Send a message to a single WebSocket client.
 * @param {object} ws
 * @param {object} message
 */
function sendToClient(ws, message) {
  if (ws.readyState === 1 /* OPEN */) {
    try {
      ws.send(JSON.stringify(message));
    } catch (err) {
      console.error('[room-manager] sendToClient error:', err.message);
    }
  }
}

/**
 * Send a message to all WebSocket connections associated with a given userId,
 * across all rooms. Used for user-scoped events like points_update.
 * @param {number} userId
 * @param {object} message
 */
function broadcastToUser(userId, message) {
  const payload = JSON.stringify(message);
  for (const [, clients] of rooms.entries()) {
    for (const [ws, meta] of clients.entries()) {
      if (meta.userId === userId && ws.readyState === 1 /* OPEN */) {
        try {
          ws.send(payload);
        } catch (err) {
          console.error('[room-manager] broadcastToUser send error:', err.message);
        }
      }
    }
  }
}

/**
 * Get count of clients in a room.
 */
function getRoomSize(matchId) {
  const room = rooms.get(matchId);
  return room ? room.size : 0;
}

/**
 * Get count of spectator clients in a room.
 * @param {number} matchId
 */
function getSpectatorCount(matchId) {
  const room = rooms.get(matchId);
  if (!room) return 0;
  let count = 0;
  for (const [, meta] of room.entries()) {
    if (meta.spectator) count++;
  }
  return count;
}

/**
 * Get all matchIds with active rooms.
 */
function getActiveRoomIds() {
  return Array.from(rooms.keys());
}

/**
 * Get all rooms (for debugging).
 */
function getRoomSnapshot() {
  const snapshot = {};
  for (const [matchId, clients] of rooms.entries()) {
    snapshot[matchId] = clients.size;
  }
  return snapshot;
}

module.exports = {
  joinRoom,
  leaveRoom,
  leaveAllRooms,
  broadcastToRoom,
  broadcastToUser,
  sendToClient,
  getRoomSize,
  getSpectatorCount,
  getActiveRoomIds,
  getRoomSnapshot,
};
