/**
 * Leaderboard — top N players by constellation points.
 */

const { pool } = require('../db/pool');

/**
 * Returns the top `limit` players sorted by constellation_points DESC.
 * @param {number} limit
 * @returns {Promise<Array>}
 */
async function getLeaderboard(limit = 20) {
  const { rows } = await pool.query(
    `SELECT
       ROW_NUMBER() OVER (ORDER BY u.constellation_points DESC) AS rank,
       u.id                          AS account_id,
       COALESCE(NULLIF(u.display_name, ''), '(이름 없음)') AS display_name,
       u.constellation_points        AS oracle_points,
       COALESCE(ps.total_wins, 0)    AS total_wins,
       COALESCE(ps.total_matches, 0) AS total_matches,
       CASE
         WHEN COALESCE(ps.total_matches, 0) > 0
           THEN ROUND(100.0 * COALESCE(ps.total_wins, 0) / ps.total_matches)
         ELSE 0
       END                           AS win_rate,
       COALESCE(ps.oracle_sent, 0)   AS oracle_sent
     FROM users u
     LEFT JOIN player_stats ps ON ps.account_id = u.id
     ORDER BY u.constellation_points DESC,
              COALESCE(ps.total_wins, 0) DESC,
              u.created_at ASC
     LIMIT $1`,
    [limit]
  );

  return rows.map((r) => ({
    rank:          Number(r.rank),
    accountId:     r.account_id,
    displayName:   r.display_name,
    oraclePoints:  r.oracle_points,
    totalWins:     Number(r.total_wins),
    totalMatches:  Number(r.total_matches),
    winRate:       Number(r.win_rate),
    oracleSent:    Number(r.oracle_sent),
  }));
}

module.exports = { getLeaderboard };
