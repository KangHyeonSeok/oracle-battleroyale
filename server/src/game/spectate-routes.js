/**
 * Spectate REST Routes
 *
 * GET /spectate — list active matches available for spectating
 *
 * Response:
 * {
 *   "matches": [
 *     {
 *       "matchId": number,
 *       "startedAt": "ISO8601",
 *       "participantCount": number,
 *       "turnCount": number,
 *       "spectatorCount": number
 *     }
 *   ]
 * }
 */

const express = require('express');
const router = express.Router();
const { pool } = require('../db/pool');
const { getSpectatorCount } = require('./room-manager');
const { loadMatchState } = require('./redis-state');

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

/**
 * GET /spectate — List in-progress matches
 */
router.get('/', requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query(`
      SELECT
        m.id          AS "matchId",
        m.started_at  AS "startedAt",
        COUNT(mp.character_id)::int AS "participantCount"
      FROM matches m
      LEFT JOIN match_participants mp ON mp.match_id = m.id
      WHERE m.status = 'in_progress'
      GROUP BY m.id, m.started_at
      ORDER BY m.started_at DESC
    `);

    const matches = await Promise.all(
      rows.map(async (row) => {
        let turnCount = 0;
        if (_redisClient) {
          try {
            const state = await loadMatchState(_redisClient, row.matchId);
            if (state) turnCount = state.turn || 0;
          } catch (_) {}
        }
        return {
          matchId: row.matchId,
          startedAt: row.startedAt,
          participantCount: row.participantCount,
          turnCount,
          spectatorCount: getSpectatorCount(row.matchId),
        };
      })
    );

    res.json({ matches });
  } catch (err) {
    console.error('[spectate] list error:', err);
    res.status(500).json({ error: 'Failed to list active matches' });
  }
});

module.exports = { router, setRedisClient };
