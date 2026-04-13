/**
 * Turn Scheduler
 *
 * Runs a 60-second interval for each active match.
 * Each tick:
 *   1. Load game state from Redis
 *   2. Acquire turn lock (skip if already processing)
 *   3. For each living character in order: evaluate AI action → resolve combat
 *   4. Check death + win condition
 *   5. Save updated state to Redis
 *   6. Broadcast state to room clients
 *   7. If game over, persist to DB and send game_over event
 */

const { evaluateAction } = require('./ai-engine');
const {
  buildCharacterGameState,
  resolveAction,
  getWinner,
  countAlive,
} = require('./combat');
const {
  saveMatchState,
  loadMatchState,
  acquireTurnLock,
  releaseTurnLock,
  listActiveMatchIds,
} = require('./redis-state');
const { broadcastToRoom } = require('./room-manager');
const { pool } = require('../db/pool');
const { popCharacterOverrides, clearOverrideQueue } = require('../oracle/override-queue');
const { awardSurvivalPoints, awardWinPoints, awardMatchEndPoints } = require('../oracle/points');

const TURN_INTERVAL_MS = 60 * 1000; // 60 seconds

/** Active interval handles: matchId → intervalId */
const activeIntervals = new Map();

let _redisClient = null;

/**
 * Initialise the scheduler with a connected Redis client.
 * @param {object} redisClient
 */
function init(redisClient) {
  _redisClient = redisClient;
  console.log('[turn-scheduler] initialised');
}

/**
 * Start the turn timer for a specific match.
 * Safe to call multiple times — won't create duplicate timers.
 * @param {number} matchId
 */
function startMatchTimer(matchId) {
  if (activeIntervals.has(matchId)) return;

  console.log(`[turn-scheduler] starting timer for match ${matchId}`);
  const handle = setInterval(() => processTurn(matchId), TURN_INTERVAL_MS);
  activeIntervals.set(matchId, handle);
}

/**
 * Stop and clear the turn timer for a match.
 * @param {number} matchId
 */
function stopMatchTimer(matchId) {
  const handle = activeIntervals.get(matchId);
  if (handle) {
    clearInterval(handle);
    activeIntervals.delete(matchId);
    console.log(`[turn-scheduler] stopped timer for match ${matchId}`);
  }
}

/**
 * Core turn processing logic.
 * @param {number} matchId
 */
async function processTurn(matchId) {
  if (!_redisClient) {
    console.error('[turn-scheduler] redis client not initialised');
    return;
  }

  // Acquire distributed lock
  const locked = await acquireTurnLock(_redisClient, matchId);
  if (!locked) {
    console.warn(`[turn-scheduler] match ${matchId} turn already in progress, skipping`);
    return;
  }

  try {
    const state = await loadMatchState(_redisClient, matchId);
    if (!state) {
      console.warn(`[turn-scheduler] no state found for match ${matchId}, stopping timer`);
      stopMatchTimer(matchId);
      return;
    }

    if (state.status === 'finished') {
      console.log(`[turn-scheduler] match ${matchId} already finished, stopping timer`);
      stopMatchTimer(matchId);
      return;
    }

    state.turn += 1;
    const turnEvents = [];

    console.log(`[turn-scheduler] match ${matchId} turn ${state.turn} — ${countAlive(state.characters)} alive`);

    // Process each living character in order
    for (const character of state.characters) {
      if (!character.alive) continue;

      // Check for a pending oracle override for this character
      const overrides = await popCharacterOverrides(_redisClient, matchId, character.id);
      const override = overrides.length > 0 ? overrides[0] : null;

      let action, damage_multiplier;
      if (override) {
        // Oracle override wins — bypass AI decision
        action = override.actionOverride;
        damage_multiplier = override.damageMultiplierOverride || character.damage_multiplier || 1.0;
        turnEvents.push({
          type: 'oracle_override',
          characterId: character.id,
          name: character.name,
          oracleType: override.type,
          actionOverride: action,
          turn: state.turn,
        });
        console.log(`[turn-scheduler] match ${matchId}: oracle override char ${character.id} → ${action} (${override.type})`);
      } else {
        // Build per-character snapshot for AI decision
        const gameState = buildCharacterGameState(character, state.characters);

        // AI action decision
        ({ action, damage_multiplier } = evaluateAction(
          character.rules_table,
          gameState
        ));
      }

      // Resolve action (may mutate character positions and hp in state.characters)
      const event = resolveAction(character, action, damage_multiplier, state.characters);
      turnEvents.push(event);

      // Check for deaths after each action
      for (const c of state.characters) {
        if (c.alive && c.hp <= 0) {
          c.alive = false;
          turnEvents.push({ type: 'death', characterId: c.id, name: c.name, turn: state.turn });
          console.log(`[turn-scheduler] match ${matchId}: ${c.name} (${c.id}) died on turn ${state.turn}`);
        }
      }
    }

    state.events = turnEvents;

    // Award survival points to living non-NPC character owners
    awardSurvivalPoints(state.characters).catch((err) =>
      console.error('[turn-scheduler] survival points error:', err.message)
    );

    // Win condition check
    const winner = getWinner(state.characters);
    const aliveCount = countAlive(state.characters);

    if (winner || aliveCount === 0) {
      state.status = 'finished';
      state.winnerId = winner ? winner.id : null;

      // Award win / dramatic reversal points
      awardWinPoints(winner).catch((err) =>
        console.error('[turn-scheduler] win points error:', err.message)
      );

      // Clean up override queue
      clearOverrideQueue(_redisClient, matchId).catch(() => {});

      // Persist final result to PostgreSQL
      await finaliseMatch(matchId, state, winner);

      // Broadcast final state
      await saveMatchState(_redisClient, matchId, state);
      broadcastToRoom(matchId, {
        type: 'turn_result',
        matchId,
        turn: state.turn,
        characters: state.characters,
        events: turnEvents,
      });
      broadcastToRoom(matchId, {
        type: 'game_over',
        matchId,
        turn: state.turn,
        winnerId: state.winnerId,
        winnerName: winner ? winner.name : null,
        message: winner
          ? `${winner.name} wins!`
          : 'Draw — no survivors.',
      });

      stopMatchTimer(matchId);
      console.log(`[turn-scheduler] match ${matchId} finished. Winner: ${winner ? winner.name : 'none'}`);
      return;
    }

    // Save updated state and broadcast
    await saveMatchState(_redisClient, matchId, state);
    broadcastToRoom(matchId, {
      type: 'turn_result',
      matchId,
      turn: state.turn,
      characters: state.characters,
      events: turnEvents,
      aliveCount,
    });
  } catch (err) {
    console.error(`[turn-scheduler] error processing turn for match ${matchId}:`, err);
  } finally {
    await releaseTurnLock(_redisClient, matchId);
  }
}

/**
 * Persist match result to PostgreSQL.
 */
async function finaliseMatch(matchId, state, winner) {
  try {
    // Update match record
    await pool.query(
      `UPDATE matches SET status = 'finished', finished_at = NOW(), winner_id = $1 WHERE id = $2`,
      [winner ? winner.id : null, matchId]
    );

    // Assign placements based on survival
    const alive = state.characters.filter((c) => c.alive);
    const dead = state.characters.filter((c) => !c.alive);

    // Winner gets placement 1
    if (winner) {
      await pool.query(
        `UPDATE match_participants SET placement = 1 WHERE match_id = $1 AND character_id = $2`,
        [matchId, winner.id]
      );
    }

    // Dead characters get placement > 1 (all get 2 for simplicity in a battle royale)
    for (const c of dead) {
      await pool.query(
        `UPDATE match_participants SET placement = 2, eliminated_at = NOW() WHERE match_id = $1 AND character_id = $2`,
        [matchId, c.id]
      );
    }

    // Update player_stats for each human participant
    const humanChars = state.characters.filter((c) => !c.is_npc);
    for (const c of humanChars) {
      // Resolve account_id from character owner
      const { rows: ownerRows } = await pool.query(
        `SELECT user_id FROM characters WHERE id = $1`,
        [c.id]
      );
      if (ownerRows.length === 0 || !ownerRows[0].user_id) continue;
      const accountId = ownerRows[0].user_id;
      const isWinner = winner && winner.id === c.id ? 1 : 0;
      await pool.query(
        `INSERT INTO player_stats (account_id, total_matches, total_wins, updated_at)
           VALUES ($1, 1, $2, NOW())
         ON CONFLICT (account_id) DO UPDATE
           SET total_matches = player_stats.total_matches + 1,
               total_wins    = player_stats.total_wins + $2,
               updated_at    = NOW()`,
        [accountId, isWinner]
      );
    }

    // Award match-end oracle points based on spec placement rules
    const totalPlayers = humanChars.length;
    awardMatchEndPoints(matchId, totalPlayers).catch((err) =>
      console.error(`[turn-scheduler] match-end points error for match ${matchId}:`, err.message)
    );

    console.log(`[turn-scheduler] match ${matchId} finalised in DB`);
  } catch (err) {
    console.error(`[turn-scheduler] failed to finalise match ${matchId} in DB:`, err.message);
  }
}

/**
 * Restore timers for all in-progress matches after server restart.
 * Reads active match IDs from Redis and restarts their timers.
 */
async function restoreActiveMatches() {
  if (!_redisClient) return;

  try {
    const matchIds = await listActiveMatchIds(_redisClient);
    let restored = 0;
    for (const matchId of matchIds) {
      const state = await loadMatchState(_redisClient, matchId);
      if (state && state.status === 'in_progress') {
        startMatchTimer(matchId);
        restored++;
      }
    }
    if (restored > 0) {
      console.log(`[turn-scheduler] restored timers for ${restored} active match(es) after restart`);
    }
  } catch (err) {
    console.error('[turn-scheduler] error during match restore:', err.message);
  }
}

/**
 * Manually trigger a turn (for testing).
 */
async function triggerTurn(matchId) {
  return processTurn(matchId);
}

module.exports = {
  init,
  startMatchTimer,
  stopMatchTimer,
  processTurn,
  triggerTurn,
  restoreActiveMatches,
};
