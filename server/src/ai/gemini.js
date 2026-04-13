const { GoogleGenerativeAI } = require('@google/generative-ai');

const EXTRACTION_SYSTEM_PROMPT = `You are a battle royale game AI rules extractor.
Given a character description in any language, extract a structured decision rules table.

Return ONLY a valid JSON object matching this schema (no markdown fences, no explanation):
{
  "class": "warrior|archer|berserk|mage|custom",
  "default_action": "move_toward_nearest_enemy|attack_melee|attack_ranged|retreat|idle",
  "damage_multiplier": <number 0.5-2.0>,
  "rules": [
    {
      "condition_key": "hp_percent|enemy_distance|enemy_count|near_wall",
      "condition_op": "<=|>=|==|>|<",
      "condition_value": <number>,
      "action": "move_toward_nearest_enemy|attack_melee|attack_ranged|retreat|move_to_wall|idle",
      "priority": <integer 1-100, higher checked first>
    }
  ]
}

condition_key meanings:
- hp_percent: current HP as 0-100 percentage
- enemy_distance: tiles to nearest living enemy (1=adjacent)
- enemy_count: number of living enemies remaining in match
- near_wall: 1 if within 2 tiles of map boundary, 0 otherwise

action meanings:
- move_toward_nearest_enemy: charge toward closest living enemy
- attack_melee: melee strike at adjacent enemy
- attack_ranged: ranged attack at visible enemy
- retreat: move away from all enemies
- move_to_wall: move toward nearest map boundary
- idle: do not move or attack this turn

damage_multiplier: base damage scaling (1.0 = normal, 1.5 = berserker boost)`;

function buildFallbackRules() {
  return {
    class: 'warrior',
    default_action: 'move_toward_nearest_enemy',
    damage_multiplier: 1.0,
    rules: [
      {
        condition_key: 'enemy_distance',
        condition_op: '<=',
        condition_value: 2,
        action: 'attack_melee',
        priority: 10,
      },
    ],
  };
}

async function extractRulesTable(characterPrompt) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.warn('[gemini] GEMINI_API_KEY not set — returning fallback rules table');
    return buildFallbackRules();
  }

  try {
    const genAI = new GoogleGenerativeAI(apiKey);
    const modelName = process.env.GEMINI_MODEL || 'gemini-1.5-flash';
    const model = genAI.getGenerativeModel({ model: modelName });

    const result = await model.generateContent([
      { text: EXTRACTION_SYSTEM_PROMPT },
      { text: `Character description: ${characterPrompt}` },
    ]);

    const raw = result.response.text().trim();
    // Strip markdown code fences if model wraps output
    const cleaned = raw.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim();
    const rules = JSON.parse(cleaned);
    return rules;
  } catch (err) {
    console.error('[gemini] rules extraction failed:', err.message);
    return buildFallbackRules();
  }
}

module.exports = { extractRulesTable };
