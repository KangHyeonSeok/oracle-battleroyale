/**
 * History Queries
 *
 * SQL helpers for match history list and detail views.
 * Note: uses oracle_invocations (not oracle_messages) per actual DB schema.
 *       match status 'finished', finished_at, winner_id per 001_initial_schema.sql.
 */

const { pool } = require('../db/pool');

/**
 * Returns paginated match history for the given accountId.
 * @param {number} accountId
 * @param {number} limit   - already clamped to [1..50]
 * @param {number} offset  - already clamped to >= 0
 * @returns {{ total: number, matches: Array }}
 */
async function getMatchList(accountId, limit, offset) {
  const countResult = await pool.query(
    `SELECT COUNT(*) AS total
     FROM matches m
     JOIN match_participants my_mp ON my_mp.match_id = m.id
     JOIN characters mc ON mc.id = my_mp.character_id
     WHERE m.status = 'finished'
       AND mc.user_id = $1`,
    [accountId]
  );
  const total = parseInt(countResult.rows[0].total, 10);

  const { rows } = await pool.query(
    `SELECT
       m.id                AS match_id,
       m.started_at,
       m.finished_at       AS ended_at,
       (SELECT COUNT(*) FROM match_participants mp2 WHERE mp2.match_id = m.id)
                           AS participant_count,
       mc.name             AS my_char_name,
       mc.class            AS my_char_class,
       my_mp.placement     AS my_rank,
       wc.name             AS winner_name,
       wc.class            AS winner_class,
       (SELECT COUNT(*) FROM oracle_invocations oi
        WHERE oi.match_id = m.id AND oi.user_id = $1)
                           AS oracle_sent_count
     FROM matches m
     JOIN match_participants my_mp ON my_mp.match_id = m.id
     JOIN characters mc ON mc.id = my_mp.character_id
     LEFT JOIN characters wc ON wc.id = m.winner_id
     WHERE m.status = 'finished'
       AND mc.user_id = $1
     ORDER BY m.finished_at DESC NULLS LAST, m.id DESC
     LIMIT $2 OFFSET $3`,
    [accountId, limit, offset]
  );

  const matches = rows.map((r) => ({
    matchId:          r.match_id,
    startedAt:        r.started_at  ? r.started_at.toISOString()  : null,
    endedAt:          r.ended_at    ? r.ended_at.toISOString()    : null,
    participantCount: parseInt(r.participant_count, 10),
    myCharacter: {
      name:  r.my_char_name  || '(삭제됨)',
      class: r.my_char_class || '',
    },
    myRank:          r.my_rank,
    winner:          r.winner_name ? { name: r.winner_name, class: r.winner_class } : null,
    oracleSentCount: parseInt(r.oracle_sent_count, 10),
  }));

  return { total, matches };
}

/**
 * Returns detail for a single finished match.
 * @param {number} matchId
 * @param {number} accountId
 * @returns {{ error: string }|Object}
 */
async function getMatchDetail(matchId, accountId) {
  const matchResult = await pool.query(
    `SELECT id, started_at, finished_at AS ended_at FROM matches WHERE id = $1`,
    [matchId]
  );
  if (matchResult.rows.length === 0) return { error: 'not_found' };

  const match = matchResult.rows[0];

  // Verify participation
  const partCheck = await pool.query(
    `SELECT mp.id FROM match_participants mp
     JOIN characters c ON c.id = mp.character_id
     WHERE mp.match_id = $1 AND c.user_id = $2
     LIMIT 1`,
    [matchId, accountId]
  );
  if (partCheck.rows.length === 0) return { error: 'forbidden' };

  // All participants sorted by placement
  const participantsResult = await pool.query(
    `SELECT
       mp.placement        AS rank,
       c.name              AS character_name,
       c.class,
       mp.is_npc,
       c.user_id
     FROM match_participants mp
     JOIN characters c ON c.id = mp.character_id
     WHERE mp.match_id = $1
     ORDER BY mp.placement ASC NULLS LAST`,
    [matchId]
  );

  const participants = participantsResult.rows.map((r) => ({
    rank:          r.rank,
    characterName: r.character_name || '(삭제됨)',
    class:         r.class          || '',
    isNpc:         r.is_npc,
    isMe:          r.user_id === accountId,
  }));

  // Total oracle count (including > 100)
  const totalOracleResult = await pool.query(
    `SELECT COUNT(*) AS total FROM oracle_invocations WHERE match_id = $1`,
    [matchId]
  );
  const oracleCount = parseInt(totalOracleResult.rows[0].total, 10);

  // Oracle messages — latest 100, returned in ascending time order
  const oraclesResult = await pool.query(
    `SELECT
       c.name              AS sender_name,
       oi.user_id,
       oi.prompt           AS content,
       oi.response         AS action_result,
       oi.invoked_at       AS sent_at
     FROM (
       SELECT * FROM oracle_invocations
       WHERE match_id = $1
       ORDER BY invoked_at DESC
       LIMIT 100
     ) oi
     LEFT JOIN characters c ON c.id = oi.character_id
     ORDER BY oi.invoked_at ASC`,
    [matchId]
  );

  const oracles = oraclesResult.rows.map((r) => ({
    senderName:   r.sender_name   || '(삭제됨)',
    isMe:         r.user_id === accountId,
    content:      r.content,
    credulity:    null,
    actionResult: r.action_result,
    sentAt:       r.sent_at ? r.sent_at.toISOString() : null,
  }));

  return {
    matchId:      match.id,
    startedAt:    match.started_at ? match.started_at.toISOString() : null,
    endedAt:      match.ended_at   ? match.ended_at.toISOString()   : null,
    participants,
    oracles,
    oracleCount,
  };
}

module.exports = { getMatchList, getMatchDetail };
