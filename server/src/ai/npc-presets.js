const pool = require('../db/pool');

// Confirmed NPC presets — approved by hyeonseok 2026-04-05
// Updated 2026-04-09: class-balance spec — 5 classes with confirmed stats + max_hp
const NPC_PRESETS = [
  {
    name: '철혈 검사',
    class: 'warrior',
    hp: 150,
    max_hp: 150,
    attack: 10,
    defense: 10,
    speed: 1.0,
    ai_persona: '항상 가장 가까운 적을 향해 돌진. 근접 공격 우선, 체력 무시.',
    rules_table: {
      class: 'warrior',
      default_action: 'move_toward_nearest_enemy',
      damage_multiplier: 1.0,
      rules: [
        { condition_key: 'enemy_distance', condition_op: '<=', condition_value: 2, action: 'attack_melee', priority: 20 },
        { condition_key: 'enemy_distance', condition_op: '>', condition_value: 2, action: 'move_toward_nearest_enemy', priority: 10 },
      ],
    },
  },
  {
    name: '그림자 궁수',
    class: 'archer',
    hp: 85,
    max_hp: 85,
    attack: 12,
    defense: 4,
    speed: 1.5,
    ai_persona: 'HP 50% 이하면 거리 유지 우선. 원거리 공격, 벽 근처 이동 선호.',
    rules_table: {
      class: 'archer',
      default_action: 'attack_ranged',
      damage_multiplier: 1.0,
      rules: [
        { condition_key: 'hp_percent', condition_op: '<=', condition_value: 50, action: 'retreat', priority: 30 },
        { condition_key: 'enemy_distance', condition_op: '<=', condition_value: 3, action: 'move_to_wall', priority: 20 },
        { condition_key: 'enemy_distance', condition_op: '>', condition_value: 3, action: 'attack_ranged', priority: 10 },
      ],
    },
  },
  {
    name: '피에 굶주린 전사',
    class: 'berserk',
    hp: 100,
    max_hp: 100,
    attack: 18,
    defense: 3,
    speed: 1.3,
    ai_persona: 'HP 낮을수록 데미지 배율 증가(×1.5). 무조건 근접 돌격.',
    rules_table: {
      class: 'berserk',
      default_action: 'move_toward_nearest_enemy',
      damage_multiplier: 1.0,
      rules: [
        {
          condition_key: 'hp_percent',
          condition_op: '<=',
          condition_value: 50,
          action: 'attack_melee',
          priority: 30,
          damage_multiplier_override: 1.5,
        },
        { condition_key: 'enemy_distance', condition_op: '<=', condition_value: 2, action: 'attack_melee', priority: 20 },
        { condition_key: 'enemy_distance', condition_op: '>', condition_value: 2, action: 'move_toward_nearest_enemy', priority: 10 },
      ],
    },
  },
  {
    name: '마법의 현자',
    class: 'mage',
    hp: 70,
    max_hp: 70,
    attack: 16,
    defense: 2,
    speed: 0.9,
    ai_persona: '고화력 원거리 마법사. 항상 원거리 유지, 근접 시 후퇴.',
    rules_table: {
      class: 'mage',
      default_action: 'attack_ranged',
      damage_multiplier: 1.0,
      rules: [
        { condition_key: 'enemy_distance', condition_op: '<=', condition_value: 2, action: 'retreat', priority: 30 },
        { condition_key: 'enemy_distance', condition_op: '>', condition_value: 2, action: 'attack_ranged', priority: 10 },
      ],
    },
  },
  {
    name: '그림자 암살자',
    class: 'assassin',
    hp: 90,
    max_hp: 90,
    attack: 14,
    defense: 4,
    speed: 1.6,
    ai_persona: '고속 근접 돌격. 치명타 25% 확률(×2 데미지). 항상 공격 우선.',
    rules_table: {
      class: 'assassin',
      default_action: 'move_toward_nearest_enemy',
      damage_multiplier: 1.0,
      rules: [
        { condition_key: 'enemy_distance', condition_op: '<=', condition_value: 2, action: 'attack_melee', priority: 20 },
        { condition_key: 'enemy_distance', condition_op: '>', condition_value: 2, action: 'move_toward_nearest_enemy', priority: 10 },
      ],
    },
  },
  {
    name: '빛의 힐러',
    class: 'healer',
    hp: 120,
    max_hp: 120,
    attack: 6,
    defense: 8,
    speed: 1.0,
    ai_persona: '아군 회복 우선. HP가 낮은 아군을 치료. 공격력 약함.',
    rules_table: {
      class: 'healer',
      default_action: 'heal',
      damage_multiplier: 1.0,
      rules: [
        { condition_key: 'hp_percent', condition_op: '<=', condition_value: 80, action: 'heal', priority: 30 },
        { condition_key: 'enemy_distance', condition_op: '<=', condition_value: 3, action: 'attack_ranged', priority: 20 },
        { condition_key: 'enemy_distance', condition_op: '>', condition_value: 3, action: 'heal', priority: 10 },
      ],
    },
  },
];

// Upsert NPC characters into DB (user_id = NULL for NPCs) and return their IDs
async function ensureNpcCharactersExist() {
  const ids = [];
  for (const preset of NPC_PRESETS) {
    const existing = await pool.query(
      'SELECT id FROM characters WHERE name = $1 AND user_id IS NULL',
      [preset.name]
    );
    if (existing.rows.length > 0) {
      // Update stats in case they changed
      await pool.query(
        `UPDATE characters SET hp = $1, max_hp = $2, attack = $3, defense = $4, speed = $5, rules_table = $6
         WHERE name = $7 AND user_id IS NULL`,
        [preset.hp, preset.max_hp, preset.attack, preset.defense, preset.speed, JSON.stringify(preset.rules_table), preset.name]
      );
      ids.push(existing.rows[0].id);
    } else {
      const result = await pool.query(
        `INSERT INTO characters (user_id, name, class, hp, max_hp, attack, defense, speed, ai_persona, rules_table)
         VALUES (NULL, $1, $2, $3, $4, $5, $6, $7, $8, $9)
         RETURNING id`,
        [
          preset.name,
          preset.class,
          preset.hp,
          preset.max_hp,
          preset.attack,
          preset.defense,
          preset.speed,
          preset.ai_persona,
          JSON.stringify(preset.rules_table),
        ]
      );
      ids.push(result.rows[0].id);
    }
  }
  return ids;
}

// Insert NPC participants into a match until participant count >= minCount (default 4)
// Returns array of inserted character IDs
async function autoFillNpcs(matchId, minCount = 4) {
  const { rows: countRows } = await pool.query(
    'SELECT COUNT(*)::int AS cnt FROM match_participants WHERE match_id = $1',
    [matchId]
  );
  const currentCount = countRows[0].cnt;
  if (currentCount >= minCount) return [];

  const npcIds = await ensureNpcCharactersExist();
  const inserted = [];

  for (const npcId of npcIds) {
    if (currentCount + inserted.length >= minCount) break;
    const dup = await pool.query(
      'SELECT 1 FROM match_participants WHERE match_id = $1 AND character_id = $2',
      [matchId, npcId]
    );
    if (dup.rows.length === 0) {
      await pool.query(
        'INSERT INTO match_participants (match_id, character_id, is_npc) VALUES ($1, $2, TRUE)',
        [matchId, npcId]
      );
      inserted.push(npcId);
    }
  }
  return inserted;
}

module.exports = { NPC_PRESETS, ensureNpcCharactersExist, autoFillNpcs };
