/**
 * Oracle Intent Extraction via Gemini
 *
 * Classifies a free-text oracle message into:
 *   type: 'buff' | 'debuff' | 'lure'
 *   actionOverride: the action to force on the target character next turn
 *   damageMultiplierOverride: optional damage scaling, or null
 */

const { GoogleGenerativeAI } = require('@google/generative-ai');

const ORACLE_INTENT_PROMPT = `You are an oracle intent classifier for a fantasy battle royale game.
Spectators send messages to influence character behaviour via an oracle system.

Three oracle types exist:
- buff: empowers the sender's own character (e.g. "지금 도망쳐" / "run now", "공격해" / "attack")
- debuff: discourages another character (e.g. "저 녀석은 겁쟁이야" / "that guy is a coward")
- lure: deceives another character with false promises (e.g. "저쪽에 보물이 있어" / "treasure over there")

Valid actions: move_toward_nearest_enemy | attack_melee | attack_ranged | retreat | idle

Return ONLY a valid JSON object with no markdown fences or explanation:
{
  "type": "buff|debuff|lure",
  "actionOverride": "<valid action>",
  "damageMultiplierOverride": <number 0.5-2.0 or null>
}

Rules:
- buff → choose the action that best matches the intent (retreat for flee commands, attack_melee/attack_ranged for fight commands)
- debuff → typically force retreat or idle (make them seem weak/scared)
- lure → typically force move_toward_nearest_enemy (lure them toward danger)
- damageMultiplierOverride is null unless the message explicitly references strength/power boost`;

const VALID_ACTIONS = new Set([
  'move_toward_nearest_enemy',
  'attack_melee',
  'attack_ranged',
  'retreat',
  'idle',
]);

const VALID_TYPES = new Set(['buff', 'debuff', 'lure']);

function buildFallbackIntent(message) {
  const lower = (message || '').toLowerCase();
  if (lower.includes('retreat') || lower.includes('run') || lower.includes('도망') || lower.includes('피해')) {
    return { type: 'buff', actionOverride: 'retreat', damageMultiplierOverride: null };
  }
  if (lower.includes('attack') || lower.includes('fight') || lower.includes('공격') || lower.includes('싸워')) {
    return { type: 'buff', actionOverride: 'attack_melee', damageMultiplierOverride: null };
  }
  if (lower.includes('treasure') || lower.includes('보물') || lower.includes('저쪽')) {
    return { type: 'lure', actionOverride: 'move_toward_nearest_enemy', damageMultiplierOverride: null };
  }
  if (lower.includes('coward') || lower.includes('겁쟁이') || lower.includes('무서워')) {
    return { type: 'debuff', actionOverride: 'retreat', damageMultiplierOverride: null };
  }
  return { type: 'buff', actionOverride: 'idle', damageMultiplierOverride: null };
}

async function extractOracleIntent(message) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.warn('[oracle-intent] GEMINI_API_KEY not set — using keyword fallback');
    return buildFallbackIntent(message);
  }

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const modelName = process.env.GEMINI_MODEL || 'gemini-1.5-flash';
    const model = genAI.getGenerativeModel({ model: modelName });

    const result = await model.generateContent([
      { text: ORACLE_INTENT_PROMPT },
      { text: `Oracle message: ${message}` },
    ]);

    const raw = result.response.text().trim();
    const cleaned = raw.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim();
    const intent = JSON.parse(cleaned);

    // Validate and sanitise
    if (!VALID_TYPES.has(intent.type)) intent.type = 'buff';
    if (!VALID_ACTIONS.has(intent.actionOverride)) intent.actionOverride = 'idle';
    if (intent.damageMultiplierOverride !== null) {
      const dmg = parseFloat(intent.damageMultiplierOverride);
      intent.damageMultiplierOverride = (isNaN(dmg) || dmg < 0.5 || dmg > 2.0) ? null : dmg;
    }

    return intent;
  } catch (err) {
    console.error('[oracle-intent] Gemini extraction failed:', err.message);
    return buildFallbackIntent(message);
  }
}

module.exports = { extractOracleIntent };
