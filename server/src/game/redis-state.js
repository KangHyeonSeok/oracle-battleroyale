/**
 * Redis State Persistence for Game Matches
 *
 * Key schema:
 *   game:match:{matchId}        — full game state (JSON)
 *   game:match:{matchId}:lock   — turn processing lock (string, TTL 70s)
 *
 * State structure stored in Redis:
 * {
 *   matchId: number,
 *   status: 'waiting' | 'in_progress' | 'finished',
 *   turn: number,
 *   startedAt: ISO string | null,
 *   characters: [
 *     {
 *       id: number,
 *       name: string,
 *       class: string,
 *       hp: number,
 *       alive: boolean,
 *       x: number,
 *       y: number,
 *       rules_table: object,
 *       damage_multiplier: number,
 *     }
 *   ],
 *   events: [],    // last turn events, cleared each turn
 *   winnerId: number | null,
 *   updatedAt: ISO string,
 * }
 */

const MATCH_KEY_PREFIX = 'game:match:';
const MATCH_TTL_SECONDS = 60 * 60 * 24; // 24 hours

function matchKey(matchId) {
  return `${MATCH_KEY_PREFIX}${matchId}`;
}

function lockKey(matchId) {
  return `${MATCH_KEY_PREFIX}${matchId}:lock`;
}

/**
 * Save full game state for a match to Redis.
 * @param {object} redisClient - connected Redis client
 * @param {number} matchId
 * @param {object} state
 */
async function saveMatchState(redisClient, matchId, state) {
  const key = matchKey(matchId);
  state.updatedAt = new Date().toISOString();
  await redisClient.set(key, JSON.stringify(state), { EX: MATCH_TTL_SECONDS });
}

/**
 * Load game state for a match from Redis.
 * Returns null if not found.
 * @param {object} redisClient
 * @param {number} matchId
 * @returns {object|null}
 */
async function loadMatchState(redisClient, matchId) {
  const key = matchKey(matchId);
  const raw = await redisClient.get(key);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch (err) {
    console.error(`[redis-state] Failed to parse state for match ${matchId}:`, err);
    return null;
  }
}

/**
 * Delete game state for a match from Redis.
 * @param {object} redisClient
 * @param {number} matchId
 */
async function deleteMatchState(redisClient, matchId) {
  await redisClient.del(matchKey(matchId));
  await redisClient.del(lockKey(matchId));
}

/**
 * Attempt to acquire a turn processing lock (prevents double-processing).
 * Returns true if acquired, false if already locked.
 * @param {object} redisClient
 * @param {number} matchId
 * @returns {boolean}
 */
async function acquireTurnLock(redisClient, matchId) {
  const key = lockKey(matchId);
  // NX = only set if not exists, EX = TTL in seconds
  const result = await redisClient.set(key, '1', { NX: true, EX: 70 });
  return result === 'OK';
}

/**
 * Release turn processing lock.
 */
async function releaseTurnLock(redisClient, matchId) {
  await redisClient.del(lockKey(matchId));
}

/**
 * List all active match IDs from Redis.
 * @param {object} redisClient
 * @returns {number[]}
 */
async function listActiveMatchIds(redisClient) {
  const keys = await redisClient.keys(`${MATCH_KEY_PREFIX}*`);
  const matchIds = [];
  for (const key of keys) {
    // Exclude lock keys
    if (key.endsWith(':lock')) continue;
    const id = parseInt(key.replace(MATCH_KEY_PREFIX, ''), 10);
    if (!isNaN(id)) matchIds.push(id);
  }
  return matchIds;
}

/**
 * Build initial game state for a new match from DB participants.
 * @param {number} matchId
 * @param {Array} participants - rows from DB with character info
 * @returns {object} initial state
 */
function buildInitialState(matchId, participants) {
  const MAP_SIZE = 800;

  // Distribute characters evenly around the map
  const characters = participants.map((p, index) => {
    const angle = (2 * Math.PI * index) / participants.length;
    const radius = 300; // spawn radius from center
    const cx = Math.round(MAP_SIZE / 2 + radius * Math.cos(angle));
    const cy = Math.round(MAP_SIZE / 2 + radius * Math.sin(angle));

    const maxHp = p.max_hp || p.hp || 100;
    return {
      id: p.character_id,
      name: p.name,
      class: p.class,
      hp: maxHp, // start at full HP (max_hp per class)
      max_hp: maxHp,
      attack: p.attack !== undefined ? p.attack : 10,
      defense: p.defense !== undefined ? p.defense : 0,
      speed: p.speed !== undefined ? p.speed : 1.0,
      alive: true,
      x: Math.min(Math.max(cx, 50), MAP_SIZE - 50),
      y: Math.min(Math.max(cy, 50), MAP_SIZE - 50),
      rules_table: p.rules_table || null,
      damage_multiplier: 1.0,
      is_npc: p.is_npc || false,
      credulity: p.credulity !== undefined ? p.credulity : 50,
    };
  });

  return {
    matchId,
    status: 'in_progress',
    turn: 0,
    startedAt: new Date().toISOString(),
    characters,
    events: [],
    winnerId: null,
    updatedAt: new Date().toISOString(),
  };
}

module.exports = {
  saveMatchState,
  loadMatchState,
  deleteMatchState,
  acquireTurnLock,
  releaseTurnLock,
  listActiveMatchIds,
  buildInitialState,
};
