# map-combat-config

## Goal
맵 크기 확장(100×100 타일), 기본 전투 수치 조정, FFA 힐러 self-only 정책 적용.

## Decision Log
- A. 맵 크기: 800×800px → 8000×8000px (100 tiles × 100 tiles, 1 tile = 80px)
- B. 이동속도: 120px/턴 → 200px/턴 (맵 확장 반영), 원거리 사거리: 300px → 320px
- C. NPC 프리셋: 현행 6종 유지 (warrior/archer/berserk/mage/assassin/healer) — 변경 없음
- D. FFA 힐러: 자신만 치료 (`findLowestHpAlly` 제거, 항상 actor 자신 heal)

## Scope
- `server/src/game/combat.js` — 상수 및 heal 로직 수정

## Changes

### 1. 상수 변경 (`server/src/game/combat.js`)
```js
const MAP_SIZE = 8000;       // 800 → 8000 (100M×100M)
const MOVE_SPEED = 200;      // 120 → 200 (맵 확장 반영)
const RANGED_RANGE = 320;    // 300 → 320 (4 tiles)
// MELEE_RANGE, MELEE_DAMAGE, RANGED_DAMAGE 유지
```

### 2. FFA 힐러 self-only (`server/src/game/combat.js`)
- `findLowestHpAlly` 함수 제거 (또는 항상 null 반환으로 변경)
- `heal` case: `const healTarget = actor;` (target 파라미터 무시)
- 주석 업데이트: "FFA policy: healer heals self only (confirmed 2026-04-17)"

## Acceptance Criteria
- [ ] AC1: MAP_SIZE = 8000, MOVE_SPEED = 200, RANGED_RANGE = 320 상수 적용
- [ ] AC2: `resolveAction('heal', actor, null, allCharacters)` → actor.hp 증가, 다른 캐릭터 hp 변화 없음
- [ ] AC3: 기존 unit tests 전부 통과 (combat/*.test.js)
- [ ] AC4: npc-presets.js 변경 없음 확인

## Constraints
- `npc-presets.js` 수정 금지 (C 결정: 현행 유지)
- 서버 API 변경 없음
- 클라이언트 변경 없음 (맵 크기는 서버 기준, 클라이언트는 서버 이벤트 기반 렌더링)

## Dependencies
- phase-3-game-server (done)
- class-balance (done)
