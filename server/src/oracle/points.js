/**
 * Oracle Points Manager
 *
 * Point rules (oracle-point-system spec):
 *   Initial balance       : 100pt (set by DB DEFAULT on users.constellation_points)
 *   Daily login bonus     : +10pt (first login per calendar day only)
 *   Oracle send           : -10pt (rejected if balance < 10)
 *   Match win (1st place) : +50pt  (win_bonus)
 *   Top 25% finish        : +20pt  (top25_bonus)
 *   Completion (non-quit) : +5pt   (completion_bonus)
 *
 * All mutations are logged to point_transactions.
 * Balance changes are pushed to connected WS clients via broadcastToUser.
 */

const { pool } = require('../db/pool');
const { broadcastToUser } = require('../game/room-manager');

const ORACLE_COST = 10;
const WIN_REWARD = 50;
const TOP25_REWARD = 20;
const COMPLETION_REWARD = 5;
const DAILY_BONUS = 10;

/** Return current oracle point balance for a user. */
async function getPoints(accountId) {
  const { rows } = await pool.query(
    'SELECT constellation_points FROM users WHERE id = $1',
    [accountId]
  );
  return rows[0]?.constellation_points ?? 0;
}

/** Append a row to point_transactions. */
async function _logTransaction(accountId, matchId, delta, reason) {
  await pool.query(
    `INSERT INTO point_transactions (account_id, match_id, delta, reason)
     VALUES ($1, $2, $3, $4)`,
    [accountId, matchId || null, delta, reason]
  );
}

/**
 * Deduct ORACLE_COST from the user's balance.
 * Returns { error: 'insufficient_points' } if balance < ORACLE_COST.
 * Returns { points: <new_balance> } on success.
 *
 * @param {number} accountId
 * @param {number|null} matchId
 * @param {string} [reason='oracle_send']
 */
async function deductPoint(accountId, matchId, reason = 'oracle_send') {
  const { rows } = await pool.query(
    `UPDATE users
     SET constellation_points = constellation_points - $1,
         updated_at = NOW()
     WHERE id = $2 AND constellation_points >= $1
     RETURNING constellation_points`,
    [ORACLE_COST, accountId]
  );
  if (rows.length === 0) {
    return { error: 'insufficient_points' };
  }
  const newPoints = rows[0].constellation_points;
  await _logTransaction(accountId, matchId, -ORACLE_COST, reason);
  broadcastToUser(accountId, { type: 'points_update', points: newPoints });
  console.log(`[points] user ${accountId} -${ORACLE_COST}pt (${reason}) → ${newPoints}pt`);
  return { points: newPoints };
}

/**
 * Add delta points to a user's balance and log the transaction.
 *
 * @param {number} accountId
 * @param {number|null} matchId
 * @param {string} reason
 * @param {number} delta  — must be positive
 * @returns {number|undefined} updated balance
 */
async function awardPoints(accountId, matchId, reason, delta) {
  const { rows } = await pool.query(
    `UPDATE users
     SET constellation_points = constellation_points + $1,
         updated_at = NOW()
     WHERE id = $2
     RETURNING constellation_points`,
    [delta, accountId]
  );
  const newPoints = rows[0]?.constellation_points;
  if (newPoints !== undefined) {
    await _logTransaction(accountId, matchId, delta, reason);
    broadcastToUser(accountId, { type: 'points_update', points: newPoints });
    console.log(`[points] user ${accountId} +${delta}pt (${reason}) → ${newPoints}pt`);
  }
  return newPoints;
}

/**
 * Grant the daily login bonus (+10pt) if it hasn't been given today.
 * Idempotent: checks point_transactions for a same-day 'daily_login' entry.
 *
 * @param {number} accountId
 * @returns {number|null} new balance, or null if bonus already granted today
 */
async function grantDailyBonus(accountId) {
  const { rows } = await pool.query(
    `SELECT id FROM point_transactions
     WHERE account_id = $1
       AND reason = 'daily_login'
       AND created_at >= CURRENT_DATE
     LIMIT 1`,
    [accountId]
  );
  if (rows.length > 0) return null; // already granted today
  return awardPoints(accountId, null, 'daily_login', DAILY_BONUS);
}

/**
 * Award match-end points for all non-NPC participants of a finished match.
 *
 * Placement rules:
 *   - placement = 1 (winner)        → win_bonus   +50pt
 *   - top 25% (by placement rank)   → top25_bonus +20pt
 *   - all completers (non-NPC)      → completion_bonus +5pt
 *
 * @param {number} matchId
 * @param {number} totalPlayerCount  — total non-NPC participant count in this match
 */
async function awardMatchEndPoints(matchId, totalPlayerCount) {
  // Fetch all non-NPC participants with their user_ids and placements
  const { rows } = await pool.query(
    `SELECT mp.character_id, mp.placement, c.user_id
     FROM match_participants mp
     JOIN characters c ON c.id = mp.character_id
     WHERE mp.match_id = $1
       AND c.user_id IS NOT NULL`,
    [matchId]
  );

  const top25Threshold = Math.ceil(totalPlayerCount * 0.25);

  for (const row of rows) {
    const { user_id, placement } = row;
    if (!user_id) continue;

    if (placement === 1) {
      // Winner: win_bonus
      await awardPoints(user_id, matchId, 'win_bonus', WIN_REWARD).catch((err) =>
        console.error(`[points] win_bonus failed user ${user_id}:`, err.message)
      );
    } else if (placement !== null && placement <= top25Threshold) {
      // Top 25%: top25_bonus
      await awardPoints(user_id, matchId, 'top25_bonus', TOP25_REWARD).catch((err) =>
        console.error(`[points] top25_bonus failed user ${user_id}:`, err.message)
      );
    }

    // All completers get completion_bonus (participant who stayed to match end)
    await awardPoints(user_id, matchId, 'completion_bonus', COMPLETION_REWARD).catch((err) =>
      console.error(`[points] completion_bonus failed user ${user_id}:`, err.message)
    );
  }
}

// ---------------------------------------------------------------------------
// Legacy / backward-compat stubs
// (turn-scheduler still calls these; they are now no-ops because
//  awardMatchEndPoints replaces per-turn survival/win rewards)
// ---------------------------------------------------------------------------

/** @deprecated No-op — per-turn survival points replaced by match-end awards. */
async function awardSurvivalPoints(_characters) {
  // intentionally empty — spec rewards are match-end only
}

/** @deprecated No-op — win points now handled by awardMatchEndPoints. */
async function awardWinPoints(_winner) {
  // intentionally empty
}

/** @deprecated Use deductPoint() instead. Kept for incremental migration. */
async function deductOracleCost(userId) {
  const result = await deductPoint(userId, null, 'oracle_send');
  if (result.error) throw new Error('Insufficient constellation points');
  return result.points;
}

module.exports = {
  getPoints,
  deductPoint,
  awardPoints,
  grantDailyBonus,
  awardMatchEndPoints,
  // legacy
  awardSurvivalPoints,
  awardWinPoints,
  deductOracleCost,
  // constants
  ORACLE_COST,
  WIN_REWARD,
  TOP25_REWARD,
  COMPLETION_REWARD,
  DAILY_BONUS,
};
