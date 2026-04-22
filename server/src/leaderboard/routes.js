/**
 * Leaderboard Routes
 *
 * GET /leaderboard — returns top 20 players by oracle points (public, no auth required)
 */

const express = require('express');
const router = express.Router();
const { getLeaderboard } = require('./leaderboard');

router.get('/', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit, 10) || 20, 100);
    const entries = await getLeaderboard(limit);
    return res.json({
      updatedAt: new Date().toISOString(),
      entries,
    });
  } catch (err) {
    console.error('[leaderboard] error:', err);
    return res.status(500).json({ error: 'Failed to fetch leaderboard' });
  }
});

module.exports = router;
