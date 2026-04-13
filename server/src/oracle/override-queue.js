/**
 * Override Queue — Redis-backed per-match action override queue.
 *
 * Key: game:match:{matchId}:override_queue  (Redis LIST)
 *
 * Each entry is a JSON object:
 * {
 *   characterId: number,
 *   actionOverride: string,
 *   damageMultiplierOverride: number | null,
 *   userId: number,
 *   type: 'buff' | 'debuff' | 'lure',
 * }
 *
 * The turn scheduler calls popCharacterOverrides() for each character before
 * evaluating its AI action. The first matching override (if any) replaces the
 * AI decision for that turn.
 */

const QUEUE_TTL_SECONDS = 60 * 60 * 24; // 24 hours

function queueKey(matchId) {
  return `game:match:${matchId}:override_queue`;
}

/**
 * Push an override entry to the tail of the match queue.
 * @param {object} redisClient
 * @param {number} matchId
 * @param {object} override
 */
async function pushOverride(redisClient, matchId, override) {
  const key = queueKey(matchId);
  await redisClient.rPush(key, JSON.stringify(override));
  await redisClient.expire(key, QUEUE_TTL_SECONDS);
}

/**
 * Pop all pending overrides for a specific character, leaving others in the queue.
 * Returns array of override objects (usually 0 or 1 items).
 *
 * @param {object} redisClient
 * @param {number} matchId
 * @param {number} characterId
 * @returns {object[]}
 */
async function popCharacterOverrides(redisClient, matchId, characterId) {
  const key = queueKey(matchId);
  const all = await redisClient.lRange(key, 0, -1);
  if (all.length === 0) return [];

  const parsed = all
    .map((s) => { try { return JSON.parse(s); } catch { return null; } })
    .filter(Boolean);

  const mine = parsed.filter((o) => o.characterId === characterId);
  if (mine.length === 0) return [];

  const others = parsed.filter((o) => o.characterId !== characterId);

  // Rewrite queue with only non-consumed entries
  await redisClient.del(key);
  if (others.length > 0) {
    for (const entry of others) {
      await redisClient.rPush(key, JSON.stringify(entry));
    }
    await redisClient.expire(key, QUEUE_TTL_SECONDS);
  }

  return mine;
}

/**
 * Delete the override queue for a match (called on match completion).
 * @param {object} redisClient
 * @param {number} matchId
 */
async function clearOverrideQueue(redisClient, matchId) {
  await redisClient.del(queueKey(matchId));
}

module.exports = { pushOverride, popCharacterOverrides, clearOverrideQueue };
