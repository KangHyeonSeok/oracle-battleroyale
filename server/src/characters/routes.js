const express = require('express');
const router = express.Router();
const pool = require('../db/pool');
const { extractRulesTable } = require('../ai/gemini');

function requireAuth(req, res, next) {
  if (!req.isAuthenticated()) {
    return res.status(401).json({ error: 'Authentication required' });
  }
  next();
}

// POST /characters — create character with name + free-form persona prompt
// Calls Gemini Flash to extract a rules_table JSON from the prompt
router.post('/', requireAuth, async (req, res) => {
  const { name, prompt } = req.body;
  if (!name || typeof name !== 'string' || !name.trim()) {
    return res.status(400).json({ error: 'name is required' });
  }
  if (!prompt || typeof prompt !== 'string' || !prompt.trim()) {
    return res.status(400).json({ error: 'prompt is required' });
  }
  if (name.trim().length > 50) {
    return res.status(400).json({ error: 'name must be 50 characters or fewer' });
  }

  try {
    const rulesTable = await extractRulesTable(prompt.trim());

    const { rows } = await pool.query(
      `INSERT INTO characters (user_id, name, class, hp, attack, defense, speed, ai_persona, rules_table)
       VALUES ($1, $2, $3, 100, 10, 5, 1.0, $4, $5)
       RETURNING id, name, class, hp, attack, defense, speed, ai_persona, rules_table, created_at`,
      [
        req.user.id,
        name.trim(),
        rulesTable.class || 'warrior',
        prompt.trim(),
        JSON.stringify(rulesTable),
      ]
    );

    res.status(201).json({ character: rows[0], rulesTable });
  } catch (err) {
    console.error('[characters] create error:', err);
    res.status(500).json({ error: 'Failed to create character' });
  }
});

// GET /characters — list authenticated user's characters
router.get('/', requireAuth, async (req, res) => {
  try {
    const { rows } = await pool.query(
      `SELECT id, name, class, hp, attack, defense, speed, created_at
       FROM characters WHERE user_id = $1 ORDER BY created_at DESC`,
      [req.user.id]
    );
    res.json({ characters: rows });
  } catch (err) {
    console.error('[characters] list error:', err);
    res.status(500).json({ error: 'Failed to list characters' });
  }
});

// GET /characters/:id — fetch a single character (owner or any authenticated user)
router.get('/:id', requireAuth, async (req, res) => {
  const id = parseInt(req.params.id, 10);
  if (!Number.isInteger(id)) {
    return res.status(400).json({ error: 'Invalid character id' });
  }
  try {
    const { rows } = await pool.query(
      `SELECT id, user_id, name, class, hp, attack, defense, speed, ai_persona, rules_table, created_at
       FROM characters WHERE id = $1`,
      [id]
    );
    if (rows.length === 0) {
      return res.status(404).json({ error: 'Character not found' });
    }
    res.json({ character: rows[0] });
  } catch (err) {
    console.error('[characters] fetch error:', err);
    res.status(500).json({ error: 'Failed to fetch character' });
  }
});

module.exports = router;
