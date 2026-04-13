---
specId: class-balance
title: 클래스 밸런스 스탯 & 전투 공식 구현
status: done
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-09
updatedAt: 2026-04-13
---

# class-balance: 클래스 밸런스 스탯 & 전투 공식 구현

## 목표
5개 클래스(전사/궁수/마법사/암살자/힐러)의 스탯을 확정하고, ATK/DEF 기반 데미지 공식과 max_hp 필드를 적용한다.

## 배경
- 현재 `combat.js`는 `MELEE_DAMAGE=15`, `RANGED_DAMAGE=10` 고정값만 사용. 개별 ATK/DEF가 전투에 반영되지 않음
- `buildCharacterGameState()`가 HP% 계산 시 `CHARACTER_HP=100` 고정 사용 → 전사(120HP), 궁수(80HP) 버그
- NPC 프리셋에 마법사/암살자/힐러 없음 (전사/궁수/광전사 3종만 존재)

---

## 확정 클래스 스탯

| 클래스 | Max HP | ATK | DEF | Speed | 공격 유형 | 특성 |
|--------|--------|-----|-----|-------|---------|------|
| warrior  | 150 | 10 | 10 | 1.0 | melee | 균형형 탱커. 돌진 우선 |
| archer   |  85 | 12 |  4 | 1.5 | ranged | 원거리·기동형. HP<50% 후퇴 |
| mage     |  70 | 16 |  2 | 0.9 | ranged | 고화력·저체력. 원거리 집중 |
| assassin |  90 | 14 |  4 | 1.6 | melee  | 고속 돌격. 치명타 25%(×2) |
| healer   | 120 |  6 |  8 | 1.0 | heal+ranged | 아군 회복. 공격 약함 |

---

## 데미지 공식

```
effective_damage = max(1, base_damage × (atk/10) - def × 0.5)
```

- `base_damage`: melee=15, ranged=10
- 암살자 치명타: 25% 확률로 effective_damage × 2
- 힐러 heal: 1회 = +20HP, 쿨다운 3턴

---

## 구현 범위

### 파일 1: `server/src/game/combat.js`

1. `resolveAction()` — `MELEE_DAMAGE`, `RANGED_DAMAGE` 고정값 대신 공식 적용
   ```js
   const baseDmg = attackType === 'melee' ? MELEE_DAMAGE : RANGED_DAMAGE;
   const rawDmg = baseDmg * (actor.attack / 10) - target.defense * 0.5;
   let dmg = Math.max(1, Math.round(rawDmg));
   // 암살자 치명타
   if (actor.class === 'assassin' && Math.random() < 0.25) dmg *= 2;
   ```
2. `buildCharacterGameState()` — hp_percent 수정
   ```js
   hp_percent: Math.round((character.hp / character.max_hp) * 100),
   ```
3. 힐러 heal 액션 추가: `action_type === 'heal'` 시 가장 HP% 낮은 아군에게 +20HP (쿨다운 3턴은 rules_table로 제어)
4. `CHARACTER_HP` 상수 제거 또는 deprecated 표시

### 파일 2: `server/src/ai/npc-presets.js`

1. 기존 전사(`철혈 검사`) hp 120 → 150, attack 15 → 10
2. 기존 궁수(`그림자 궁수`) hp 80 → 85
3. 마법사 NPC 추가 — `마법의 현자`, class: mage
4. 암살자 NPC 추가 — `그림자 암살자`, class: assassin
5. 힐러 NPC 추가 — `빛의 힐러`, class: healer
6. NPC INSERT 쿼리에 `max_hp` 컬럼 포함

### 파일 3: `server/migrations/004_class_balance.sql`

```sql
-- max_hp 컬럼 추가
ALTER TABLE characters ADD COLUMN IF NOT EXISTS max_hp INTEGER;

-- 기존 행 max_hp = hp 으로 초기화
UPDATE characters SET max_hp = hp WHERE max_hp IS NULL;

-- max_hp NOT NULL 제약 적용 (초기화 후)
ALTER TABLE characters ALTER COLUMN max_hp SET NOT NULL;
ALTER TABLE characters ALTER COLUMN max_hp SET DEFAULT 100;
```

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | `combat.js` 전사 vs 전사 1v1 시뮬레이션 — 전사 처치에 10±5타 이내 (5–15턴 수용) |
| AC2 | 전사 vs 마법사 1v1 10판 — 마법사 3판 이상 승리 |
| AC3 | 암살자 vs 힐러 1v1 10판 — 암살자 우세 (7판 이상 승리) |
| AC4 | NPC 프리셋 5종 DB insert 확인 (전사/궁수/마법사/암살자/힐러) |
| AC5 | `hp_percent` 계산이 `max_hp` 기준으로 올바르게 동작 (전사 150HP → 75% at 112HP) |
| AC6 | migration 004 실행 후 에러 없음, `max_hp` 컬럼 존재 확인 |

---

## 테스트 방법

`server/src/game/combat.js` 내 또는 별도 `test/combat.test.js`에 1v1 시뮬레이션 함수 작성:

```js
function simulate1v1(classA, classB, rounds = 10) {
  // classA, classB: { hp, max_hp, attack, defense, class }
  // resolveAction() 루프로 승패 카운트
}
```

단위 테스트 실행: `cd server && node test/combat.test.js`
