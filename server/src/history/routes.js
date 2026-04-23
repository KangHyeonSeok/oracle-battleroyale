/**
 * History Routes
 *
 * GET /history             — paginated match history list for authenticated user
 * GET /history/:matchId    — match detail: participants + oracle feed
 */

const express = require('express');
const router = express.Router();
const { getMatchList, getMatchDetail } = require('./queries');

function requireAuth(req, res, next) {
  if (!req.isAuthenticated()) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  next();
}

// GET /history?limit=20&offset=0
router.get('/', requireAuth, async (req, res) => {
  const accountId = req.user.id;
  let limit  = parseInt(req.query.limit,  10) || 20;
  let offset = parseInt(req.query.offset, 10) || 0;
  limit  = Math.min(Math.max(limit, 1), 50);
  offset = Math.max(offset, 0);

  try {
    const result = await getMatchList(accountId, limit, offset);
    return res.json(result);
  } catch (err) {
    console.error('[history] list error:', err);
    return res.status(500).json({ error: 'Failed to fetch match history' });
  }
});

// GET /history/:matchId
router.get('/:matchId', requireAuth, async (req, res) => {
  const accountId = req.user.id;
  const matchId   = parseInt(req.params.matchId, 10);
  if (!Number.isInteger(matchId) || matchId <= 0) {
    return res.status(400).json({ error: 'Invalid match id' });
  }

  try {
    const result = await getMatchDetail(matchId, accountId);
    if (result.error === 'not_found') {
      return res.status(404).json({ error: 'not_found' });
    }
    if (result.error === 'forbidden') {
      return res.status(403).json({ error: 'forbidden' });
    }
    return res.json(result);
  } catch (err) {
    console.error('[history] detail error:', err);
    return res.status(500).json({ error: 'Failed to fetch match detail' });
  }
});

module.exports = router;
