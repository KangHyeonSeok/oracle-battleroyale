/**
 * Spectate handler — joins a WS socket to an active match as a read-only spectator.
 *
 * Message (client → server): { type: "spectate", matchId: number }
 *
 * On success the client receives:
 *   { type: "joined_match", matchId, roomSize, spectator: true }
 *   { type: "state_sync",   matchId, state }
 *
 * On failure:
 *   { type: "error", code: "not_found", message: "..." }
 */

const { joinRoom, sendToClient, getRoomSize } = require('../game/room-manager');
const { loadMatchState } = require('../game/redis-state');
const { pool } = require('../db/pool');

/**
 * @param {object} ws          - WebSocket instance
 * @param {object} msg         - Parsed message ({ type: "spectate", matchId })
 * @param {object} redisClient - Shared Redis client (may be null)
 */
async function handleSpectate(ws, msg, redisClient) {
  const userId = ws._userId;
  if (!userId) {
    sendToClient(ws, { type: 'error', message: 'Not authenticated' });
    return;
  }

  const matchId = parseInt(msg.matchId, 10);
  if (isNaN(matchId)) {
    sendToClient(ws, { type: 'error', message: 'spectate: matchId must be a number' });
    return;
  }

  // Verify match exists and is currently in progress
  try {
    const { rows } = await pool.query(
      "SELECT id FROM matches WHERE id = $1 AND status = 'in_progress'",
      [matchId]
    );
    if (rows.length === 0) {
      sendToClient(ws, { type: 'error', code: 'not_found', message: 'Match not found or not active' });
      return;
    }
  } catch (err) {
    console.error('[ws][spectate] db error:', err.message);
    sendToClient(ws, { type: 'error', message: 'Server error' });
    return;
  }

  // Add socket to room as spectator (reuses broadcast infrastructure)
  joinRoom(matchId, ws, { characterId: null, userId, spectator: true });
  ws._joinedRooms.add(matchId);
  ws._currentMatchId = matchId;
  ws._isSpectator = true;

  sendToClient(ws, {
    type: 'joined_match',
    matchId,
    roomSize: getRoomSize(matchId),
    spectator: true,
  });

  // Send current game state so the client can render the arena immediately
  if (redisClient) {
    try {
      const state = await loadMatchState(redisClient, matchId);
      if (state) {
        sendToClient(ws, { type: 'state_sync', matchId, state });
      }
    } catch (err) {
      console.error('[ws][spectate] state sync error:', err.message);
    }
  }

  console.log(`[ws][spectate] user ${userId} spectating match ${matchId}`);
}

module.exports = { handleSpectate };
