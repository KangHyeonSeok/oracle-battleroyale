# map-combat-config Validation

- Status: completed
- Action: completed-spec
- UpdatedAt: 2026-04-21T09:00:00Z
- Detail: 태연 19:00 버그수정 tick. map-combat-config spec 기준 4개 AC 전부 통과.

## Acceptance Criteria Review

1. AC1: MAP_SIZE=8000, MOVE_SPEED=200, RANGED_RANGE=320 상수 적용
Status: passed
Evidence: combat.js 상수 직접 수정 확인. MAP_SIZE=8000, MOVE_SPEED=200, RANGED_RANGE=320.

2. AC2: resolveAction('heal', actor, null, allCharacters) → actor.hp 증가, 다른 캐릭터 hp 변화 없음
Status: passed
Evidence: heal case에서 `const healTarget = actor;` 적용. findLowestHpAlly 제거. 다른 캐릭터 hp 미변경.

3. AC3: 기존 unit tests 전부 통과 (combat/*.test.js)
Status: passed
Evidence: npm test 전체 통과. 0 failed.

4. AC4: npc-presets.js 변경 없음 확인
Status: passed
Evidence: npc-presets.js 미수정.
