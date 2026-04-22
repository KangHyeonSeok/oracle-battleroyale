/**
 * AI Action Decision Engine
 *
 * Evaluates a character's rules_table against current game state parameters
 * and returns the chosen action for the 60-second turn.
 *
 * Game state keys:
 *   hp_percent     {number}  Current HP as 0–100 percentage
 *   enemy_distance {number}  Tiles to nearest living enemy (1 = adjacent)
 *   enemy_count    {number}  Number of living enemies in the match
 *   near_wall      {number}  1 if within 2 tiles of map boundary, else 0
 */

function matchesCondition(rule, gameState) {
  const value = gameState[rule.condition_key];
  if (value === undefined || value === null) return false;

  switch (rule.condition_op) {
    case '<=': return value <= rule.condition_value;
    case '>=': return value >= rule.condition_value;
    case '<':  return value <  rule.condition_value;
    case '>':  return value >  rule.condition_value;
    case '==': return value === rule.condition_value;
    default:   return false;
  }
}

/**
 * Evaluate a single character's rules table against game state.
 *
 * @param {object} rulesTable  - Parsed rules_table from the characters row
 * @param {object} gameState   - Current per-character game state snapshot
 * @returns {{ action: string, damage_multiplier: number }}
 */
function evaluateAction(rulesTable, gameState) {
  if (!rulesTable || !Array.isArray(rulesTable.rules)) {
    return { action: 'idle', damage_multiplier: 1.0 };
  }

  const { rules, default_action = 'idle', damage_multiplier: baseMult = 1.0 } = rulesTable;

  // Sort by priority descending so the most important rule fires first
  const sorted = [...rules].sort((a, b) => (b.priority || 0) - (a.priority || 0));

  for (const rule of sorted) {
    if (matchesCondition(rule, gameState)) {
      return {
        action: rule.action,
        damage_multiplier: rule.damage_multiplier_override ?? baseMult,
      };
    }
  }

  return { action: default_action, damage_multiplier: baseMult };
}

/**
 * Decide actions for all participants in a single turn.
 *
 * @param {Array<{ characterId: number, rulesTable: object, gameState: object }>} participants
 * @returns {Array<{ characterId: number, action: string, damage_multiplier: number }>}
 */
function decideTurnActions(participants) {
  return participants.map(({ characterId, rulesTable, gameState }) => ({
    characterId,
    ...evaluateAction(rulesTable, gameState),
  }));
}

module.exports = { evaluateAction, decideTurnActions };
