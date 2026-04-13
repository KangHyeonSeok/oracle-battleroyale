/**
 * Matchmaker — 자동 매칭 시스템
 *
 * - Global single queue (MVP)
 * - 32 players → immediate match start
 * - 60 s timeout → fill remaining slots with NPCs
 * - Duplicate account prevention (auto-remove then re-insert)
 *
 * Public API:
 *   matchmaker.init(wss, redisClient)
 *   matchmaker.enqueue(userId, characterId, ws)   → void
 *   matchmaker.dequeue(userId)                    → void
 */

const { pool } = require('../db/pool');
const { ensureNpcCharactersExist } = require('../ai/npc-presets');
const { buildInitialState, saveMatchState } = require('./redis-state');
const { startMatchTimer } = require('./turn-scheduler');

const MATCH_SIZE = 32;
const WAIT_TIMEOUT_MS = 60 * 1000; // 60 seconds
const COUNTDOWN_SECS = 5;

class Matchmaker {
  constructor() {
    /** @type {Array<{userId:number, characterId:number, joinedAt:number, ws:object}>} */
    this.queue = [];
    this.matchTimerRef = null;
    this._wss = null;
    this._redisClient = null;
  }

  /**
   * Wire up dependencies after server init.
   * @param {import('ws').WebSocketServer} wss
   * @param {object} redisClient
   */
  init(wss, redisClient) {
    this._wss = wss;
    this._redisClient = redisClient;
  }

  /**
   * Add a player to the global queue.
   * If the same userId is already queued, silently remove them first (AC3).
   * @param {number} userId
   * @param {number} characterId
   * @param {object} ws - WebSocket connection for this user
   */
  enqueue(userId, characterId, ws) {
    // AC3: deduplicate — remove existing entry before re-inserting
    this.queue = this.queue.filter(e => e.userId !== userId);

    const entry = { userId, characterId, joinedAt: Date.now(), ws };
    this.queue.push(entry);

    console.log(`[matchmaker] user ${userId} enqueued with char ${characterId} (queue=${this.queue.length})`);

    // AC5: broadcast queue_update to all connected clients
    this._broadcastQueueUpdate();

    // Start 60 s fallback timer when first player joins
    if (this.queue.length === 1 && !this.matchTimerRef) {
      this.matchTimerRef = setTimeout(() => {
        this.matchTimerRef = null;
        this.tryStartMatch();
      }, WAIT_TIMEOUT_MS);
    }

    // AC1: immediate start when queue is full
    if (this.queue.length >= MATCH_SIZE) {
      if (this.matchTimerRef) {
        clearTimeout(this.matchTimerRef);
        this.matchTimerRef = null;
      }
      this.tryStartMatch();
    }
  }

  /**
   * Remove a player from the queue (e.g. queue_leave).
   * AC4: broadcasts queue_update after removal.
   * @param {number} userId
   */
  dequeue(userId) {
    const before = this.queue.length;
    this.queue = this.queue.filter(e => e.userId !== userId);
    if (this.queue.length < before) {
      console.log(`[matchmaker] user ${userId} dequeued (queue=${this.queue.length})`);
      // AC4 + AC5: broadcast to all
      this._broadcastQueueUpdate();

      // Cancel timer if queue is now empty
      if (this.queue.length === 0 && this.matchTimerRef) {
        clearTimeout(this.matchTimerRef);
        this.matchTimerRef = null;
      }
    }
  }

  /**
   * Broadcast { type: 'queue_update', count, waitSeconds } to all WS clients.
   * AC5: fires on every enqueue / dequeue.
   */
  _broadcastQueueUpdate() {
    if (!this._wss) return;
    const firstJoinedAt = this.queue.length > 0 ? this.queue[0].joinedAt : null;
    const waitSeconds = firstJoinedAt
      ? Math.floor((Date.now() - firstJoinedAt) / 1000)
      : 0;
    const msg = JSON.stringify({
      type: 'queue_update',
      count: this.queue.length,
      total: MATCH_SIZE,
      waitSeconds,
    });
    for (const client of this._wss.clients) {
      if (client.readyState === 1 /* OPEN */) {
        try { client.send(msg); } catch (_) {}
      }
    }
  }

  /**
   * Drain up to MATCH_SIZE players from queue and start a match.
   * AC1: called immediately when queue reaches 32.
   * AC2: called after 60 s timeout, NPC-fills remaining slots.
   */
  async tryStartMatch() {
    if (this.queue.length === 0) return;

    const realPlayers = this.queue.splice(0, MATCH_SIZE);
    const npcSlots = MATCH_SIZE - realPlayers.length;

    try {
      const npcCharacterIds = await this._fillWithNPCs(npcSlots);
      await this._startMatch(realPlayers, npcCharacterIds);
    } catch (err) {
      console.error('[matchmaker] failed to start match:', err.message);
      // Re-queue players at the front on transient failure
      this.queue.unshift(...realPlayers);
    }

    // If more players remain after this match, restart the timer for them
    if (this.queue.length > 0 && !this.matchTimerRef) {
      this.matchTimerRef = setTimeout(() => {
        this.matchTimerRef = null;
        this.tryStartMatch();
      }, WAIT_TIMEOUT_MS);
    }
  }

  /**
   * Get `slots` random NPC character IDs from the preset pool.
   * AC2: used to fill remaining slots when < 32 real players after timeout.
   * @param {number} slots
   * @returns {Promise<number[]>}
   */
  async _fillWithNPCs(slots) {
    if (slots <= 0) return [];
    const npcIds = await ensureNpcCharactersExist();
    // Shuffle
    const shuffled = [...npcIds].sort(() => Math.random() - 0.5);
    const result = [];
    for (let i = 0; i < slots; i++) {
      result.push(shuffled[i % shuffled.length]);
    }
    return result;
  }

  /**
   * Create a match record, insert participants, build state, start game loop.
   * AC6: inserts into matches table.
   * AC1: broadcasts match_starting to all, match_started to participants.
   * @param {Array<{userId,characterId,ws}>} realPlayers
   * @param {number[]} npcCharacterIds
   */
  async _startMatch(realPlayers, npcCharacterIds) {
    // AC6: create match record
    const { rows: matchRows } = await pool.query(
      `INSERT INTO matches (status, max_players) VALUES ('waiting', $1) RETURNING *`,
      [MATCH_SIZE]
    );
    const matchId = matchRows[0].id;

    // Insert real participants
    for (const player of realPlayers) {
      await pool.query(
        `INSERT INTO match_participants (match_id, character_id, is_npc)
         VALUES ($1, $2, FALSE)
         ON CONFLICT (match_id, character_id) DO NOTHING`,
        [matchId, player.characterId]
      );
    }

    // Insert NPC participants
    for (const npcId of npcCharacterIds) {
      await pool.query(
        `INSERT INTO match_participants (match_id, character_id, is_npc)
         VALUES ($1, $2, TRUE)
         ON CONFLICT (match_id, character_id) DO NOTHING`,
        [matchId, npcId]
      );
    }

    // Load full participant details for state builder
    const { rows: participants } = await pool.query(
      `SELECT mp.character_id, mp.is_npc, c.name, c.class, c.rules_table, c.credulity,
              c.hp, c.max_hp, c.attack, c.defense, c.speed
       FROM match_participants mp
       JOIN characters c ON c.id = mp.character_id
       WHERE mp.match_id = $1`,
      [matchId]
    );

    // Build and persist initial game state to Redis
    const initialState = buildInitialState(matchId, participants);
    if (this._redisClient) {
      await saveMatchState(this._redisClient, matchId, initialState);
    }

    // Transition match to in_progress (AC6: record exists with in_progress status)
    await pool.query(
      `UPDATE matches SET status = 'in_progress', started_at = NOW() WHERE id = $1`,
      [matchId]
    );

    const playerCount = realPlayers.length;
    const npcCount = npcCharacterIds.length;

    // AC1: broadcast match_starting to ALL connected clients
    const matchStartingMsg = JSON.stringify({
      type: 'match_starting',
      matchId,
      playerCount,
      npcCount,
      startsIn: COUNTDOWN_SECS,
    });
    if (this._wss) {
      for (const client of this._wss.clients) {
        if (client.readyState === 1) {
          try { client.send(matchStartingMsg); } catch (_) {}
        }
      }
    }

    console.log(
      `[matchmaker] match ${matchId} starting in ${COUNTDOWN_SECS}s — ${playerCount} players + ${npcCount} NPCs`
    );

    // After countdown: start game loop, notify participants
    setTimeout(() => {
      startMatchTimer(matchId);

      // Send match_found to participants' WebSocket connections (client expects match_found)
      const startedMsg = JSON.stringify({ type: 'match_found', matchId });
      for (const player of realPlayers) {
        const { ws } = player;
        if (ws && ws.readyState === 1) {
          try { ws.send(startedMsg); } catch (_) {}
        }
      }
    }, COUNTDOWN_SECS * 1000);
  }
}

const matchmaker = new Matchmaker();
module.exports = { matchmaker };
