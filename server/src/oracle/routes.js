/**
 * Oracle Routes
 *
 * POST /oracle — Send an oracle message to influence a character's next action.
 *
 * Request body:
 *   { matchId: number, targetCharacterId: number, message: string }
 *
 * Guards (checked in order):
 *   1. Authenticated user
 *   2. ≥5 constellation points
 *   3. Per-user-per-match cooldown: 1 oracle per 60 seconds
 *   4. Match is in_progress
 *   5. Target character is alive in the match
 *
 * Pipeline:
 *   Gemini → OracleIntent (type + actionOverride)
 *   credulity check → if success, push to override_queue
 *   deduct 5 points (atomic)
 *   log to oracle_invocations
 */

const express = require('express');
const router = express.Router();
const { pool } = require('../db/pool');
const { loadMatchState } = require('../game/redis-state');
const { extractOracleIntent } = require('./intent');
const { checkCredulity } = require('./credulity');
const { pushOverride } = require('./override-queue');
const { deductPoint } = require('./points');

let _redisClient = null;

function setRedisClient(client) {
  _redisClient = client;
}

function requireAuth(req, res, next) {
  if (!req.isAuthenticated()) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  next();
}

const COOLDOWN_TTL_SECONDS = 60;

function cooldownKey(userId, matchId) {
  return `oracle:cooldown:${userId}:${matchId}`;
}

/**
 * POST /oracle
 */
router.post('/', requireAuth, async (req, res) => {
  const userId = req.user.id;
  const { matchId, targetCharacterId, message } = req.body;

  // Input validation
  if (!matchId || !targetCharacterId || !message) {
    return res.status(400).json({ error: 'matchId, targetCharacterId, and message are required' });
  }
  const mId = parseInt(matchId, 10);
  const tId = parseInt(targetCharacterId, 10);
  if (isNaN(mId) || isNaN(tId)) {
    return res.status(400).json({ error: 'matchId and targetCharacterId must be integers' });
  }
  const trimmedMessage = String(message).trim();
  if (trimmedMessage.length === 0) {
    return res.status(400).json({ error: 'message must not be empty' });
  }

  if (!_redisClient) {
    return res.status(503).json({ error: 'Redis not available' });
  }

  try {
    // 1. Points check (fast read from session-loaded user)
    if (req.user.constellation_points < 10) {
      return res.status(402).json({
        error: 'insufficient_points',
        currentPoints: req.user.constellation_points,
        required: 10,
      });
    }

    // 2. Cooldown check
    const cdKey = cooldownKey(userId, mId);
    const onCooldown = await _redisClient.get(cdKey);
    if (onCooldown) {
      const ttl = await _redisClient.ttl(cdKey);
      return res.status(429).json({ error: `Cooldown active. Try again in ${ttl}s` });
    }

    // 3. Match status
    const { rows: matchRows } = await pool.query(
      'SELECT status FROM matches WHERE id = $1',
      [mId]
    );
    if (matchRows.length === 0) return res.status(404).json({ error: 'Match not found' });
    if (matchRows[0].status !== 'in_progress') {
      return res.status(409).json({ error: `Match is ${matchRows[0].status}, oracle unavailable` });
    }

    // 4. Target character alive in match (via Redis state)
    const state = await loadMatchState(_redisClient, mId);
    if (!state) return res.status(404).json({ error: 'Game state not found' });

    const targetChar = state.characters.find((c) => c.id === tId);
    if (!targetChar) return res.status(404).json({ error: 'Target character not found in match' });
    if (!targetChar.alive) {
      return res.status(409).json({ error: 'Target character is already eliminated' });
    }

    // 5. Gemini: extract oracle intent
    const intent = await extractOracleIntent(trimmedMessage);
    const { type, actionOverride, damageMultiplierOverride } = intent;

    // 6. Credulity check
    const credulity = targetChar.credulity !== undefined ? targetChar.credulity : 50;
    const { success, roll } = checkCredulity(type, credulity);

    // 7. Atomic point deduction
    const deductResult = await deductPoint(userId, mId, 'oracle_send');
    if (deductResult.error) {
      return res.status(402).json({ error: 'insufficient_points' });
    }
    const remainingPoints = deductResult.points;

    // 8. Set cooldown
    await _redisClient.set(cdKey, '1', { EX: COOLDOWN_TTL_SECONDS });

    // 9. Push to override queue on success
    if (success) {
      await pushOverride(_redisClient, mId, {
        characterId: tId,
        actionOverride,
        damageMultiplierOverride: damageMultiplierOverride || null,
        userId,
        type,
      });
    }

    // 10. Increment oracle_sent in player_stats
    pool.query(
      `INSERT INTO player_stats (account_id, oracle_sent, updated_at)
         VALUES ($1, 1, NOW())
       ON CONFLICT (account_id) DO UPDATE
         SET oracle_sent = player_stats.oracle_sent + 1,
             updated_at  = NOW()`,
      [userId]
    ).catch((err) => console.error('[oracle] player_stats oracle_sent update error:', err.message));

    // 11. Persist invocation log
    const responseText = success
      ? `[${type}] 신탁 성공: ${actionOverride} (다음 턴 반영)`
      : `[${type}] 신탁 실패: 대상이 흔들리지 않았습니다 (주사위: ${roll}, 피감화성: ${credulity})`;

    await pool.query(
      `INSERT INTO oracle_invocations
         (match_id, user_id, character_id, prompt, response, points_spent)
       VALUES ($1, $2, $3, $4, $5, 10)`,
      [mId, userId, tId, trimmedMessage, responseText]
    );

    console.log(`[oracle] user ${userId} → char ${tId} in match ${mId}: type=${type} action=${actionOverride} success=${success}`);

    return res.json({
      success,
      type,
      actionOverride,
      damageMultiplierOverride: damageMultiplierOverride || null,
      remainingPoints,
      credulityRoll: success ? undefined : { roll, credulity },
      message: responseText,
    });
  } catch (err) {
    console.error('[oracle] unhandled error:', err);
    return res.status(500).json({ error: 'Oracle invocation failed' });
  }
});

module.exports = { router, setRedisClient };
