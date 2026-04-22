/**
 * Match Management HTTP Routes
 *
 * POST /matches              — create a new match (waiting)
 * POST /matches/:id/join     — join a match with a character
 * POST /matches/:id/start    — start a match (transitions to in_progress)
 * GET  /matches/:id          — get match state (from Redis or DB)
 * GET  /matches/:id/state    — get full game state from Redis
 * POST /matches/:id/turn     — manually trigger a turn (dev/test only)
 */

const express = require('express');
const router = express.Router();
const { pool } = require('../db/pool');
const { autoFillNpcs } = require('../ai/npc-presets');
const { saveMatchState, loadMatchState, buildInitialState } = require('./redis-state');
const { startMatchTimer } = require('./turn-scheduler');

function requireAuth(req, res, next) {
  if (!req.isAuthenticated()) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  next();
}

// Lazy accessor to redis client (set after app init)
let _redisClient = null;
function setRedisClient(client) {
  _redisClient = client;
}

/**
 * POST /matches — Create a new match
 */
router.post('/', requireAuth, async (req, res) => {
  try {
    const { max_players = 8 } = req.body;
    const { rows } = await pool.query(
      `INSERT INTO matches (status, max_players) VALUES ('waiting', $1) RETURNING *`,
      [max_players]
    );
    const match = rows[0];
    res.status(201).json({ match });
  } catch (err) {
    console.error('[matches] create error:', err);
    res.status(500).json({ error: 'Failed to create match' });
  }
});

/**
 * POST /matches/:id/join — Join a match with a character
 */
router.post('/:id/join', requireAuth, async (req, res) => {
  const matchId = parseInt(req.params.id, 10);
  const { character_id } = req.body;

  if (!Number.isInteger(matchId)) return res.status(400).json({ error: 'Invalid match id' });
  if (!character_id) return res.status(400).json({ error: 'character_id required' });

  try {
    // Verify match exists and is waiting
    const { rows: matchRows } = await pool.query(
      'SELECT * FROM matches WHERE id = $1',
      [matchId]
    );
    if (matchRows.length === 0) return res.status(404).json({ error: 'Match not found' });
    const match = matchRows[0];
    if (match.status !== 'waiting') {
      return res.status(409).json({ error: `Match is ${match.status}, cannot join` });
    }

    // Verify character belongs to authenticated user
    const { rows: charRows } = await pool.query(
      'SELECT * FROM characters WHERE id = $1 AND user_id = $2',
      [character_id, req.user.id]
    );
    if (charRows.length === 0) {
      return res.status(404).json({ error: 'Character not found or not owned by you' });
    }

    // Check capacity
    const { rows: countRows } = await pool.query(
      'SELECT COUNT(*)::int AS cnt FROM match_participants WHERE match_id = $1',
      [matchId]
    );
    if (countRows[0].cnt >= match.max_players) {
      return res.status(409).json({ error: 'Match is full' });
    }

    // Insert participant (ignore duplicate)
    await pool.query(
      `INSERT INTO match_participants (match_id, character_id, is_npc)
       VALUES ($1, $2, FALSE)
       ON CONFLICT (match_id, character_id) DO NOTHING`,
      [matchId, character_id]
    );

    res.json({ message: 'Joined match', matchId, characterId: character_id });
  } catch (err) {
    console.error('[matches] join error:', err);
    res.status(500).json({ error: 'Failed to join match' });
  }
});

/**
 * POST /matches/:id/start — Start a match
 * Auto-fills with NPCs if fewer than 4 participants.
 * Builds initial game state and saves to Redis, then starts turn timer.
 */
router.post('/:id/start', requireAuth, async (req, res) => {
  const matchId = parseInt(req.params.id, 10);
  if (!Number.isInteger(matchId)) return res.status(400).json({ error: 'Invalid match id' });

  try {
    const { rows: matchRows } = await pool.query(
      'SELECT * FROM matches WHERE id = $1',
      [matchId]
    );
    if (matchRows.length === 0) return res.status(404).json({ error: 'Match not found' });
    const match = matchRows[0];
    if (match.status !== 'waiting') {
      return res.status(409).json({ error: `Match is already ${match.status}` });
    }

    // Auto-fill NPCs if needed
    await autoFillNpcs(matchId, 4);

    // Load participants with character details
    const { rows: participants } = await pool.query(
      `SELECT mp.character_id, mp.is_npc, c.name, c.class, c.rules_table, c.credulity
       FROM match_participants mp
       JOIN characters c ON c.id = mp.character_id
       WHERE mp.match_id = $1`,
      [matchId]
    );

    if (participants.length < 2) {
      return res.status(409).json({ error: 'Need at least 2 participants to start' });
    }

    // Build initial state and save to Redis
    if (!_redisClient) {
      return res.status(503).json({ error: 'Redis not available' });
    }
    const initialState = buildInitialState(matchId, participants);
    await saveMatchState(_redisClient, matchId, initialState);

    // Update DB status
    await pool.query(
      `UPDATE matches SET status = 'in_progress', started_at = NOW() WHERE id = $1`,
      [matchId]
    );

    // Start turn timer
    startMatchTimer(matchId);

    res.json({
      message: 'Match started',
      matchId,
      participants: participants.length,
      state: initialState,
    });
  } catch (err) {
    console.error('[matches] start error:', err);
    res.status(500).json({ error: 'Failed to start match' });
  }
});

/**
 * GET /matches/:id — Get match summary from DB
 */
router.get('/:id', async (req, res) => {
  const matchId = parseInt(req.params.id, 10);
  if (!Number.isInteger(matchId)) return res.status(400).json({ error: 'Invalid match id' });

  try {
    const { rows: matchRows } = await pool.query(
      'SELECT * FROM matches WHERE id = $1',
      [matchId]
    );
    if (matchRows.length === 0) return res.status(404).json({ error: 'Match not found' });

    const { rows: participants } = await pool.query(
      `SELECT mp.character_id, mp.is_npc, mp.placement, mp.eliminated_at,
              c.name, c.class
       FROM match_participants mp
       JOIN characters c ON c.id = mp.character_id
       WHERE mp.match_id = $1
       ORDER BY mp.placement ASC NULLS LAST`,
      [matchId]
    );

    res.json({ match: matchRows[0], participants });
  } catch (err) {
    console.error('[matches] get error:', err);
    res.status(500).json({ error: 'Failed to get match' });
  }
});

/**
 * GET /matches/:id/state — Get full game state from Redis
 */
router.get('/:id/state', async (req, res) => {
  const matchId = parseInt(req.params.id, 10);
  if (!Number.isInteger(matchId)) return res.status(400).json({ error: 'Invalid match id' });

  if (!_redisClient) {
    return res.status(503).json({ error: 'Redis not available' });
  }

  try {
    const state = await loadMatchState(_redisClient, matchId);
    if (!state) return res.status(404).json({ error: 'No game state found in Redis for this match' });
    res.json({ state });
  } catch (err) {
    console.error('[matches] state error:', err);
    res.status(500).json({ error: 'Failed to load game state' });
  }
});

/**
 * POST /matches/:id/turn — Manually trigger a turn (dev/test use only)
 */
router.post('/:id/turn', requireAuth, async (req, res) => {
  const matchId = parseInt(req.params.id, 10);
  if (!Number.isInteger(matchId)) return res.status(400).json({ error: 'Invalid match id' });

  try {
    const { triggerTurn } = require('./turn-scheduler');
    await triggerTurn(matchId);

    const state = _redisClient ? await loadMatchState(_redisClient, matchId) : null;
    res.json({ message: 'Turn processed', matchId, state });
  } catch (err) {
    console.error('[matches] trigger turn error:', err);
    res.status(500).json({ error: 'Failed to trigger turn' });
  }
});

module.exports = { router, setRedisClient };
