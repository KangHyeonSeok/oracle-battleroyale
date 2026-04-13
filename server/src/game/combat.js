/**
 * Combat Resolution Module
 *
 * Game constants:
 *   Map:          800×800 px
 *   Melee range:  80 px  → base damage 15/turn
 *   Ranged range: 300 px → base damage 10/turn
 *   Move speed:   120 px/turn
 *
 * Damage formula:
 *   effective_damage = max(1, base_damage * (atk/10) - def * 0.5)
 *   Assassin crit: 25% chance × 2
 */

const MAP_SIZE = 800;
const MELEE_RANGE = 80;
const RANGED_RANGE = 300;
const MELEE_DAMAGE = 15;
const RANGED_DAMAGE = 10;
const MOVE_SPEED = 120;
// CHARACTER_HP kept for backwards compatibility but deprecated — use character.max_hp instead
const CHARACTER_HP = 100; // @deprecated

/** Euclidean distance between two positions */
function distance(a, b) {
  const dx = a.x - b.x;
  const dy = a.y - b.y;
  return Math.sqrt(dx * dx + dy * dy);
}

/** Clamp a value to [min, max] */
function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

/**
 * Move character toward a target by MOVE_SPEED px, clamped to map bounds.
 * Returns new position.
 */
function moveToward(from, target) {
  const dx = target.x - from.x;
  const dy = target.y - from.y;
  const dist = Math.sqrt(dx * dx + dy * dy);
  if (dist <= 0) return { x: from.x, y: from.y };

  const ratio = Math.min(MOVE_SPEED / dist, 1);
  return {
    x: clamp(Math.round(from.x + dx * ratio), 0, MAP_SIZE),
    y: clamp(Math.round(from.y + dy * ratio), 0, MAP_SIZE),
  };
}

/**
 * Move character away from a target by MOVE_SPEED px, clamped to map bounds.
 */
function moveAway(from, target) {
  const dx = from.x - target.x;
  const dy = from.y - target.y;
  const dist = Math.sqrt(dx * dx + dy * dy);
  if (dist <= 0) {
    // Move in a default direction if overlapping
    return { x: clamp(from.x + MOVE_SPEED, 0, MAP_SIZE), y: from.y };
  }
  const ratio = MOVE_SPEED / dist;
  return {
    x: clamp(Math.round(from.x + dx * ratio), 0, MAP_SIZE),
    y: clamp(Math.round(from.y + dy * ratio), 0, MAP_SIZE),
  };
}

/**
 * Move character toward nearest map wall.
 */
function moveToWall(from) {
  const distLeft = from.x;
  const distRight = MAP_SIZE - from.x;
  const distTop = from.y;
  const distBottom = MAP_SIZE - from.y;
  const minDist = Math.min(distLeft, distRight, distTop, distBottom);

  let target;
  if (minDist === distLeft) target = { x: 0, y: from.y };
  else if (minDist === distRight) target = { x: MAP_SIZE, y: from.y };
  else if (minDist === distTop) target = { x: from.x, y: 0 };
  else target = { x: from.x, y: MAP_SIZE };

  return moveToward(from, target);
}

/**
 * Find the nearest living enemy to a character.
 * @param {object} character - { id, x, y }
 * @param {Array} allCharacters - array of { id, x, y, hp, alive }
 * @returns nearest enemy object or null
 */
function findNearestEnemy(character, allCharacters) {
  let nearest = null;
  let nearestDist = Infinity;

  for (const other of allCharacters) {
    if (other.id === character.id || !other.alive) continue;
    const d = distance(character, other);
    if (d < nearestDist) {
      nearestDist = d;
      nearest = other;
    }
  }
  return nearest;
}

/**
 * Find the ally with lowest hp_percent (for healer).
 */
function findLowestHpAlly(actor, allCharacters) {
  let lowest = null;
  let lowestPct = Infinity;
  for (const other of allCharacters) {
    if (other.id === actor.id || !other.alive) continue;
    // In a 1v1 or FFA context all others are enemies; healer heals itself if no true ally
    const maxHp = other.max_hp || CHARACTER_HP;
    const pct = other.hp / maxHp;
    if (pct < lowestPct) {
      lowestPct = pct;
      lowest = other;
    }
  }
  return lowest;
}

/**
 * Build per-character game state snapshot for AI engine.
 * Uses tile-based distance where 1 tile ≈ 80px (melee range).
 */
function buildCharacterGameState(character, allCharacters) {
  const TILE_SIZE = 80;
  const nearest = findNearestEnemy(character, allCharacters);
  const enemyDistance = nearest
    ? Math.max(1, Math.round(distance(character, nearest) / TILE_SIZE))
    : 999;

  const distLeft = character.x;
  const distRight = MAP_SIZE - character.x;
  const distTop = character.y;
  const distBottom = MAP_SIZE - character.y;
  const minWallDist = Math.min(distLeft, distRight, distTop, distBottom);
  const nearWall = minWallDist <= TILE_SIZE * 2 ? 1 : 0;

  const livingEnemies = allCharacters.filter(
    (c) => c.id !== character.id && c.alive
  ).length;

  const maxHp = character.max_hp || CHARACTER_HP;

  return {
    hp_percent: Math.round((character.hp / maxHp) * 100),
    enemy_distance: enemyDistance,
    enemy_count: livingEnemies,
    near_wall: nearWall,
  };
}

/**
 * Compute effective damage using ATK/DEF formula.
 * effective_damage = max(1, base_damage * (atk/10) - def * 0.5)
 * Assassin crit: 25% chance × 2
 */
function computeDamage(baseDmg, actor, target, dmgMult) {
  const atk = actor.attack !== undefined ? actor.attack : 10;
  const def = target.defense !== undefined ? target.defense : 0;
  const rawDmg = baseDmg * (atk / 10) * dmgMult - def * 0.5;
  let dmg = Math.max(1, Math.round(rawDmg));
  if (actor.class === 'assassin' && Math.random() < 0.25) dmg *= 2;
  return dmg;
}

/**
 * Resolve a single character's action for this turn.
 * Modifies the characters array in-place (hp, alive, x, y).
 *
 * @param {object} actor       - character performing action { id, x, y, hp, max_hp, attack, defense, class, alive, heal_cooldown }
 * @param {string} action      - action name from AI engine
 * @param {number} dmgMult     - damage multiplier from AI engine
 * @param {Array}  allCharacters - full array of character states (mutated in-place for hp)
 * @returns {object} event describing what happened
 */
function resolveAction(actor, action, dmgMult, allCharacters) {
  if (!actor.alive) return { type: 'skip', actorId: actor.id, reason: 'dead' };

  const nearest = findNearestEnemy(actor, allCharacters);

  switch (action) {
    case 'attack_melee': {
      if (!nearest) {
        // No enemy — idle
        return { type: 'idle', actorId: actor.id };
      }
      const dist = distance(actor, nearest);
      if (dist <= MELEE_RANGE) {
        const dmg = computeDamage(MELEE_DAMAGE, actor, nearest, dmgMult);
        nearest.hp = Math.max(0, nearest.hp - dmg);
        if (nearest.hp <= 0) nearest.alive = false;
        return {
          type: 'attack_melee',
          actorId: actor.id,
          targetId: nearest.id,
          damage: dmg,
          targetHp: nearest.hp,
          targetDied: !nearest.alive,
        };
      }
      // Out of melee range — move toward instead
      const newPos = moveToward(actor, nearest);
      actor.x = newPos.x;
      actor.y = newPos.y;
      return { type: 'move', actorId: actor.id, x: actor.x, y: actor.y, reason: 'out_of_melee_range' };
    }

    case 'attack_ranged': {
      if (!nearest) return { type: 'idle', actorId: actor.id };
      const dist = distance(actor, nearest);
      if (dist <= RANGED_RANGE) {
        const dmg = computeDamage(RANGED_DAMAGE, actor, nearest, dmgMult);
        nearest.hp = Math.max(0, nearest.hp - dmg);
        if (nearest.hp <= 0) nearest.alive = false;
        return {
          type: 'attack_ranged',
          actorId: actor.id,
          targetId: nearest.id,
          damage: dmg,
          targetHp: nearest.hp,
          targetDied: !nearest.alive,
        };
      }
      // Too far — move toward
      const newPos = moveToward(actor, nearest);
      actor.x = newPos.x;
      actor.y = newPos.y;
      return { type: 'move', actorId: actor.id, x: actor.x, y: actor.y, reason: 'out_of_ranged_range' };
    }

    case 'heal': {
      // Healer heals the ally with the lowest HP% (or self if no allies)
      const cooldown = actor.heal_cooldown || 0;
      if (cooldown > 0) {
        actor.heal_cooldown = cooldown - 1;
        // Fall back to ranged attack while on cooldown
        return resolveAction(actor, 'attack_ranged', dmgMult, allCharacters);
      }
      const target = findLowestHpAlly(actor, allCharacters);
      const healTarget = target || actor;
      const maxHp = healTarget.max_hp || CHARACTER_HP;
      const before = healTarget.hp;
      healTarget.hp = Math.min(maxHp, healTarget.hp + 20);
      actor.heal_cooldown = 3;
      return {
        type: 'heal',
        actorId: actor.id,
        targetId: healTarget.id,
        healAmount: healTarget.hp - before,
        targetHp: healTarget.hp,
      };
    }

    case 'move_toward_nearest_enemy': {
      if (!nearest) return { type: 'idle', actorId: actor.id };
      const newPos = moveToward(actor, nearest);
      actor.x = newPos.x;
      actor.y = newPos.y;
      return { type: 'move', actorId: actor.id, x: actor.x, y: actor.y };
    }

    case 'retreat': {
      if (!nearest) return { type: 'idle', actorId: actor.id };
      const newPos = moveAway(actor, nearest);
      actor.x = newPos.x;
      actor.y = newPos.y;
      return { type: 'move', actorId: actor.id, x: actor.x, y: actor.y, reason: 'retreat' };
    }

    case 'move_to_wall': {
      const newPos = moveToWall(actor);
      actor.x = newPos.x;
      actor.y = newPos.y;
      return { type: 'move', actorId: actor.id, x: actor.x, y: actor.y, reason: 'move_to_wall' };
    }

    case 'idle':
    default:
      return { type: 'idle', actorId: actor.id };
  }
}

/**
 * Count living characters.
 */
function countAlive(characters) {
  return characters.filter((c) => c.alive).length;
}

/**
 * Get the last surviving character, or null if multiple alive.
 */
function getWinner(characters) {
  const alive = characters.filter((c) => c.alive);
  return alive.length === 1 ? alive[0] : null;
}

module.exports = {
  MAP_SIZE,
  MELEE_RANGE,
  RANGED_RANGE,
  MELEE_DAMAGE,
  RANGED_DAMAGE,
  MOVE_SPEED,
  CHARACTER_HP,
  distance,
  findNearestEnemy,
  buildCharacterGameState,
  computeDamage,
  resolveAction,
  countAlive,
  getWinner,
};
