/**
 * Credulity Check
 *
 * Determines whether an oracle message successfully influences a target character.
 *
 * buff  (own character): always succeeds — the user controls their own fate.
 * debuff / lure (other character): probability = credulity / 100
 *   credulity 0   → 0%  chance of being influenced (immune)
 *   credulity 50  → 50% chance (default)
 *   credulity 100 → 100% chance (fully gullible)
 *
 * @param {string} type       - 'buff' | 'debuff' | 'lure'
 * @param {number} credulity  - target character's credulity score (0–100)
 * @returns {{ success: boolean, roll: number }}
 */
function checkCredulity(type, credulity) {
  if (type === 'buff') {
    return { success: true, roll: 100 };
  }
  const roll = Math.random() * 100;
  const success = roll < (credulity || 50);
  return { success, roll: Math.round(roll) };
}

module.exports = { checkCredulity };
