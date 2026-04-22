/**
 * WebSocket Server — Phase 3 + Matchmaking + UI Screen Integration
 *
 * Handles:
 *   - Client connections on /ws
 *   - Room join/leave per match
 *   - Real-time state broadcast (driven by turn-scheduler)
 *   - Queue join/leave for automatic matchmaking
 *   - Character management (list, preview, create) over WS
 *   - Oracle send over WS with room broadcast
 *
 * Message protocol (client → server):
 *   { type: 'get_characters' }
 *   { type: 'preview_character', name: string, prompt: string }
 *   { type: 'create_character',  name: string, prompt: string }
 *   { type: 'find_match',   characterId: number }
 *   { type: 'cancel_match' }
 *   { type: 'join_match',   matchId: number, characterId?: number }
 *   { type: 'leave_match',  matchId: number }
 *   { type: 'queue_join',   characterId: number, userId: number }
 *   { type: 'queue_leave',  userId: number }
 *   { type: 'oracle_send',  targetId: number, text: string, spectator: bool }
 *   { type: 'ping' }
 *
 * Message protocol (server → client):
 *   { type: 'connected',       message: string }
 *   { type: 'my_characters',   characters: Array }
 *   { type: 'character_preview', character: object }
 *   { type: 'character_created', character: object }
 *   { type: 'joined_match',    matchId: number, roomSize: number }
 *   { type: 'left_match',      matchId: number }
 *   { type: 'queue_update',    count: number, total: number, waitSeconds: number }
 *   { type: 'match_found',     matchId: number }
 *   { type: 'match_starting',  matchId, playerCount, npcCount, startsIn: 5 }
 *   { type: 'state_sync',      matchId, state }
 *   { type: 'turn_result',     matchId, turn, characters, events, aliveCount }
 *   { type: 'game_over',       matchId, turn, winnerId, winnerName, message }
 *   { type: 'oracle_stream',   message: object }
 *   { type: 'points_update',   points: number }
 *   { type: 'error',           message: string }
 *   { type: 'pong' }
 */

const { WebSocketServer } = require('ws');
const {
  joinRoom,
  leaveRoom,
  leaveAllRooms,
  sendToClient,
  getRoomSize,
  broadcastToRoom,
} = require('../game/room-manager');
const { loadMatchState } = require('../game/redis-state');
const { matchmaker } = require('../game/matchmaker');
const { getPoints } = require('../oracle/points');
const { pool } = require('../db/pool');
const { extractRulesTable } = require('../ai/gemini');
const { extractOracleIntent } = require('../oracle/intent');
const { checkCredulity } = require('../oracle/credulity');
const { pushOverride } = require('../oracle/override-queue');
const { deductPoint } = require('../oracle/points');

let _redisClient = null;

function setRedisClient(client) {
  _redisClient = client;
}

/** Base stats per class (spec table). Multiplier 0.8–1.3 applied from LLM. */
const BASE_STATS = {
  warrior:  { hp: 150, atk: 25, def: 15 },
  archer:   { hp: 100, atk: 20, def: 8  },
  mage:     { hp: 80,  atk: 35, def: 5  },
  berserk:  { hp: 90,  atk: 30, def: 6  },
  assassin: { hp: 90,  atk: 30, def: 6  },
  healer:   { hp: 110, atk: 12, def: 10 },
  custom:   { hp: 100, atk: 20, def: 10 },
};

function classToStats(cls, multiplier) {
  const base = BASE_STATS[cls] || BASE_STATS.custom;
  const m = Math.min(1.3, Math.max(0.8, Number(multiplier) || 1.0));
  return {
    hp:  Math.round(base.hp  * m),
    atk: Math.round(base.atk * m),
    def: Math.round(base.def * m),
  };
}

/** Apply express-session middleware to a WS upgrade request to populate req.session. */
function applySession(req, sessionMiddleware) {
  return new Promise((resolve) => {
    sessionMiddleware(req, {}, resolve);
  });
}

function initWebSocket(httpServer) {
  const wss = new WebSocketServer({ server: httpServer, path: '/ws' });

  // Give matchmaker a reference to wss for global broadcasts
  matchmaker._wss = wss;

  wss.on('connection', async (ws, req) => {
    console.log('[ws] client connected from', req.socket.remoteAddress);

    // Apply session middleware so req.session is populated (browser sends cookie)
    try {
      const { sessionMiddleware } = require('../app');
      await applySession(req, sessionMiddleware);
    } catch (_) {
      // Session not available (e.g. non-browser client) — continue without auth
    }

    // Extract userId from Passport session
    ws._userId = req.session?.passport?.user ?? null;
    ws._joinedRooms = new Set();
    ws._currentMatchId = null;

    console.log('[ws] session userId:', ws._userId);

    // Send welcome frame
    sendToClient(ws, {
      type: 'connected',
      message: 'Oracle Battle Royale server ready',
    });

    ws.on('message', async (data) => {
      let msg;
      try {
        msg = JSON.parse(data.toString());
      } catch {
        sendToClient(ws, { type: 'error', message: 'Invalid JSON' });
        return;
      }

      try {
        await handleMessage(ws, msg);
      } catch (err) {
        console.error('[ws] handler error for', msg.type, ':', err.message);
        sendToClient(ws, { type: 'error', message: `Server error: ${err.message}` });
      }
    });

    ws.on('close', () => {
      leaveAllRooms(ws);
      console.log('[ws] client disconnected');
    });

    ws.on('error', (err) => {
      console.error('[ws] client error:', err.message);
      leaveAllRooms(ws);
    });
  });

  console.log('[ws] WebSocket server initialized at /ws');
  return wss;
}

async function handleMessage(ws, msg) {
  const userId = ws._userId;

  switch (msg.type) {

    // ── Character management ───────────────────────────────────────────────────

    case 'get_characters': {
      if (!userId) {
        sendToClient(ws, { type: 'error', message: 'Not authenticated' });
        return;
      }
      const { rows } = await pool.query(
        `SELECT id, name, class, hp, attack AS atk, defense AS def, created_at
         FROM characters WHERE user_id = $1 ORDER BY created_at DESC`,
        [userId]
      );
      const chars = rows.map(r => ({ ...r, win_rate: 0.0 }));
      sendToClient(ws, { type: 'my_characters', characters: chars });
      break;
    }

    case 'preview_character': {
      if (!userId) {
        sendToClient(ws, { type: 'error', message: 'Not authenticated' });
        return;
      }
      const { name, prompt } = msg;
      if (!name || !prompt) {
        sendToClient(ws, { type: 'error', message: 'name and prompt are required' });
        return;
      }
      const rulesTable = await extractRulesTable(String(prompt).trim());
      const stats = classToStats(rulesTable.class, rulesTable.damage_multiplier);
      sendToClient(ws, {
        type: 'character_preview',
        character: {
          name: String(name).trim(),
          class: rulesTable.class,
          hp:  stats.hp,
          atk: stats.atk,
          def: stats.def,
          tendency: (rulesTable.default_action || 'idle').replace(/_/g, ' '),
        },
      });
      break;
    }

    case 'create_character': {
      if (!userId) {
        sendToClient(ws, { type: 'error', message: 'Not authenticated' });
        return;
      }
      const { name, prompt } = msg;
      if (!name || !prompt) {
        sendToClient(ws, { type: 'error', message: 'name and prompt are required' });
        return;
      }
      const rulesTable = await extractRulesTable(String(prompt).trim());
      const stats = classToStats(rulesTable.class, rulesTable.damage_multiplier);
      const { rows } = await pool.query(
        `INSERT INTO characters (user_id, name, class, hp, attack, defense, speed, ai_persona, rules_table)
         VALUES ($1, $2, $3, $4, $5, $6, 1.0, $7, $8)
         RETURNING id, name, class, hp, attack AS atk, defense AS def, created_at`,
        [
          userId,
          String(name).trim(),
          rulesTable.class,
          stats.hp,
          stats.atk,
          stats.def,
          String(prompt).trim(),
          JSON.stringify(rulesTable),
        ]
      );
      const char = { ...rows[0], win_rate: 0.0 };
      sendToClient(ws, { type: 'character_created', character: char });
      break;
    }

    // ── Matchmaking ────────────────────────────────────────────────────────────

    case 'find_match': {
      if (!userId) {
        sendToClient(ws, { type: 'error', message: 'Not authenticated' });
        return;
      }
      const characterId = parseInt(msg.characterId, 10);
      if (isNaN(characterId)) {
        sendToClient(ws, { type: 'error', message: 'find_match: characterId must be a number' });
        return;
      }
      matchmaker.enqueue(userId, characterId, ws);
      console.log(`[ws] user ${userId} joined queue with char ${characterId}`);
      break;
    }

    case 'cancel_match': {
      if (!userId) {
        sendToClient(ws, { type: 'error', message: 'Not authenticated' });
        return;
      }
      matchmaker.dequeue(userId);
      sendToClient(ws, { type: 'match_cancelled' });
      console.log(`[ws] user ${userId} cancelled match queue`);
      break;
    }

    // ── Room management ────────────────────────────────────────────────────────

    case 'join_match': {
      const matchId = parseInt(msg.matchId, 10);
      if (isNaN(matchId)) {
        sendToClient(ws, { type: 'error', message: 'join_match: matchId must be a number' });
        return;
      }

      joinRoom(matchId, ws, {
        characterId: msg.characterId || null,
        userId: userId || msg.userId || null,
      });
      ws._joinedRooms.add(matchId);
      ws._currentMatchId = matchId;

      sendToClient(ws, {
        type: 'joined_match',
        matchId,
        roomSize: getRoomSize(matchId),
      });

      // Send current game state if available
      if (_redisClient) {
        try {
          const state = await loadMatchState(_redisClient, matchId);
          if (state) {
            sendToClient(ws, { type: 'state_sync', matchId, state });
          }
        } catch (err) {
          console.error('[ws] state sync error:', err.message);
        }
      }

      // Send current points balance if authenticated
      if (userId) {
        try {
          const points = await getPoints(userId);
          sendToClient(ws, { type: 'points_update', points });
        } catch (err) {
          console.error('[ws] points init error:', err.message);
        }
      } else if (msg.userId) {
        const uid = parseInt(msg.userId, 10);
        if (!isNaN(uid)) {
          try {
            const points = await getPoints(uid);
            sendToClient(ws, { type: 'points_update', points });
          } catch (err) {
            console.error('[ws] points init error:', err.message);
          }
        }
      }

      console.log(`[ws] client joined match ${matchId}`);
      break;
    }

    case 'leave_match': {
      const matchId = parseInt(msg.matchId, 10);
      if (isNaN(matchId)) {
        sendToClient(ws, { type: 'error', message: 'leave_match: matchId must be a number' });
        return;
      }

      leaveRoom(matchId, ws);
      ws._joinedRooms.delete(matchId);
      if (ws._currentMatchId === matchId) {
        ws._currentMatchId = null;
      }

      sendToClient(ws, { type: 'left_match', matchId });
      console.log(`[ws] client left match ${matchId}`);
      break;
    }

    // ── Legacy queue messages (from older clients) ─────────────────────────────

    case 'queue_join': {
      const characterId = parseInt(msg.characterId, 10);
      const qUserId = userId || parseInt(msg.userId, 10);
      if (isNaN(characterId) || !qUserId || isNaN(qUserId)) {
        sendToClient(ws, { type: 'error', message: 'queue_join: userId and characterId must be numbers' });
        return;
      }
      matchmaker.enqueue(qUserId, characterId, ws);
      console.log(`[ws] user ${qUserId} joined queue with char ${characterId}`);
      break;
    }

    case 'queue_leave': {
      const qUserId = userId || parseInt(msg.userId, 10);
      if (!qUserId || isNaN(qUserId)) {
        sendToClient(ws, { type: 'error', message: 'queue_leave: userId must be a number' });
        return;
      }
      matchmaker.dequeue(qUserId);
      console.log(`[ws] user ${qUserId} left queue`);
      break;
    }

    // ── Spectate ───────────────────────────────────────────────────────────────

    case 'spectate': {
      if (!userId) {
        sendToClient(ws, { type: 'error', message: 'Not authenticated' });
        return;
      }
      const { handleSpectate } = require('./spectate');
      await handleSpectate(ws, msg, _redisClient);
      break;
    }

    // ── Oracle ─────────────────────────────────────────────────────────────────

    case 'oracle_send': {
      if (!userId) {
        sendToClient(ws, { type: 'error', message: 'Not authenticated' });
        return;
      }

      // Spectators cannot send oracle messages
      if (ws._isSpectator) {
        return;
      }
      if (!_redisClient) {
        sendToClient(ws, { type: 'error', message: 'Redis not available' });
        return;
      }

      const matchId = ws._currentMatchId;
      if (!matchId) {
        sendToClient(ws, { type: 'error', message: 'Not in a match' });
        return;
      }

      const targetId = parseInt(msg.targetId, 10);
      const text = String(msg.text || '').trim();
      const isSpectator = Boolean(msg.spectator);

      if (isNaN(targetId) || !text) {
        sendToClient(ws, { type: 'error', message: 'oracle_send: targetId and text are required' });
        return;
      }

      // Load game state to find target character
      const state = await loadMatchState(_redisClient, matchId);
      if (!state) {
        sendToClient(ws, { type: 'error', message: 'Game state not found' });
        return;
      }
      const targetChar = state.characters.find(c => c.id === targetId);
      if (!targetChar) {
        sendToClient(ws, { type: 'error', message: 'Target character not found' });
        return;
      }
      if (!targetChar.alive) {
        sendToClient(ws, { type: 'error', message: 'Target character is already eliminated' });
        return;
      }

      // Get sender display name
      let senderName = 'Anonymous';
      try {
        const { rows: userRows } = await pool.query(
          'SELECT display_name, username, email FROM users WHERE id = $1',
          [userId]
        );
        if (userRows.length > 0) {
          senderName = userRows[0].display_name || userRows[0].username || userRows[0].email || 'Anonymous';
        }
      } catch (_) {}

      // Deduct points (oracle costs 5pt client-side, 10pt server-side)
      const deductResult = await deductPoint(userId, matchId, 'oracle_send');
      if (deductResult.error) {
        sendToClient(ws, { type: 'error', message: 'Insufficient constellation points' });
        return;
      }

      // Cooldown check via Redis (1 oracle/60s per user per match)
      const cdKey = `oracle:cooldown:${userId}:${matchId}`;
      const onCooldown = await _redisClient.get(cdKey);
      if (onCooldown) {
        const ttl = await _redisClient.ttl(cdKey);
        sendToClient(ws, { type: 'error', message: `Cooldown active. Try again in ${ttl}s` });
        return;
      }
      await _redisClient.set(cdKey, '1', { EX: 60 });

      // Extract oracle intent via Gemini
      const intent = await extractOracleIntent(text);
      const { type: intentType, actionOverride, damageMultiplierOverride } = intent;

      // Credulity check
      const credulity = targetChar.credulity !== undefined ? targetChar.credulity : 50;
      const { success, roll } = checkCredulity(intentType, credulity);

      // Push override to queue on success
      if (success) {
        await pushOverride(_redisClient, matchId, {
          characterId: targetId,
          actionOverride,
          damageMultiplierOverride: damageMultiplierOverride || null,
          userId,
          type: intentType,
        });
      }

      // Log invocation
      const responseText = success
        ? `[${intentType}] 신탁 성공: ${actionOverride}`
        : `[${intentType}] 신탁 실패: 대상이 흔들리지 않았습니다 (주사위: ${roll})`;

      try {
        await pool.query(
          `INSERT INTO oracle_invocations (match_id, user_id, character_id, prompt, response, points_spent)
           VALUES ($1, $2, $3, $4, $5, 10)`,
          [matchId, userId, targetId, text, responseText]
        );
      } catch (err) {
        console.error('[ws][oracle] log error:', err.message);
      }

      // Broadcast oracle_stream to the match room
      const streamMsg = {
        type: isSpectator ? 'spectator' : 'oracle',
        sender: senderName,
        target: targetChar.name,
        text,
        success,
      };
      broadcastToRoom(matchId, { type: 'oracle_stream', message: streamMsg });

      console.log(`[ws][oracle] user ${userId} → char ${targetId} in match ${matchId}: success=${success}`);
      break;
    }

    // ── Misc ───────────────────────────────────────────────────────────────────

    case 'ping': {
      sendToClient(ws, { type: 'pong', timestamp: Date.now() });
      break;
    }

    default: {
      sendToClient(ws, { type: 'error', message: `Unknown message type: ${msg.type}` });
      break;
    }
  }
}

module.exports = { initWebSocket, setRedisClient };
