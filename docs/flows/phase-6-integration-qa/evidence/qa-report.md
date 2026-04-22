# Phase 6 QA Report — oracle-battleroyale

Generated: 2026-04-11

## Test Suites Added

| File | Description |
|------|-------------|
| `server/test/e2e-flow.test.js`       | Full E2E lifecycle: login → char create → match join → oracle → game end → points |
| `server/test/load-32players.test.js` | 32-character turn processing load test |
| `server/test/gemini-cost.test.js`    | Gemini API cost-per-game verification |

---

## AC1: Full Flow — 전 구간 정상

**Test**: `e2e-flow.test.js`  
**Result**: PASSED

```
✓ Step 1 (Login): user session created, initial balance = 100pt
✓ Step 2 (Character Create): Gemini fallback → type=buff action=attack_melee
✓ Step 3 (Match Join): player 1 joined match 999
✓ Step 4 (Oracle Send): points deducted (100→90), override queued
✓ Step 5 (Game Turns): match ended after 14 turns — winner: Beta
✓ Step 6 (Game Over): game_over broadcast confirmed
✓ Step 7 (Points Settlement): win_bonus(1) + completion_bonus(2) transactions logged
=== All E2E steps passed ✓ ===
```

Each phase of the pipeline was exercised:
- Login: `users.constellation_points` initialised to 100 (DB default)
- Character create: `extractOracleIntent` keyword fallback confirmed
- Match join: `matchRows` / `participantRows` created correctly
- Oracle send: 10pt deducted, `override_queue` written & popped successfully
- Game turns: `resolveAction` + `evaluateAction` loop ran 14 turns to completion
- game_over: event broadcast captured in `broadcastedRoomMessages`
- Points settlement: `awardMatchEndPoints` issued `win_bonus` (+50) and `completion_bonus` (+5) transactions

---

## AC2: 32-Player Load Test — 턴 처리 1,000ms 이내

**Test**: `load-32players.test.js`  
**Result**: PASSED

```
Turns executed : 50
p50 (median)   : 0.239 ms
p95            : 1.946 ms
p99            : 2.296 ms
max            : 2.296 ms
avg            : 0.415 ms

✓ All 50 turns completed under 1000ms SLA (max=2.296ms)
Estimated full turn time (CPU + I/O): 7.3ms
✓ Estimated total (CPU + I/O overhead) also under 1000ms SLA
```

- CPU-bound turn logic (ai-engine + combat for 32 characters): max **2.3ms**
- Estimated I/O overhead (Redis SET/GET ~0.3ms × N + DB ~2ms): **+5ms**
- Total estimated per-turn latency: **~7ms**, 143× headroom under 1,000ms SLA

---

## AC3: Gemini Cost — 판당 $0.005 이하

**Test**: `gemini-cost.test.js`  
**Result**: PASSED

```
Model: gemini-1.5-flash
Pricing: $0.075/1M input tokens, $0.30/1M output tokens

Scenario 1 — Worst-case (all 32 players send oracle × 1):
  Oracle intent (32 calls)  : $0.001416
  TOTAL per game            : $0.001416   ✓ < $0.005

Scenario 2 — Typical (10 oracle sends):
  Oracle intent (10 calls)  : $0.000442
  TOTAL per game            : $0.000442   ✓ < $0.005

Budget headroom: could afford 112 oracle calls before hitting $0.005
```

- Character creation (`extractRulesTable`) is a **one-time** cost ($0.000135/char), not charged per game
- Per-game cost = only oracle intent calls (`extractOracleIntent`)
- 60-second cooldown per user per match caps oracle calls at ≤ PLAYERS_PER_GAME = 32
- Worst-case 32 calls: **$0.0014**, well within $0.005 budget

---

## AC4: P0/P1 Bug Findings & Fixes

No P0/P1 regressions introduced by phases 1–5. The following pre-existing issues were identified during code review:

| Severity | Location | Issue | Status |
|----------|----------|-------|--------|
| P1 | `oracle/routes.js:78` | Points check reads from session (`req.user.constellation_points`) which may be stale if points changed during session; race window before atomic deduct | Accepted — `deductPoint` is atomic (conditional UPDATE), double-check acts as UX guard only |
| P2 | `turn-scheduler.js:259` | `totalPlayers` counts alive + dead non-NPC characters; correct behaviour confirmed | No fix needed |
| P2 | `oracle/intent.js` | No `move_to_wall` in VALID_ACTIONS set but it appears in gemini.js rule schema | Informational — oracle overrides use a different action set |

All existing unit tests (combat, points, matchmaker) pass with 0 failures (17+18+4 = 39 tests total).

---

## Regression Test Summary

```
combat.test.js    : 17 passed, 0 failed
points.test.js    : 18 passed, 0 failed
matchmaker.test.js:  4 passed, 0 failed
e2e-flow.test.js  :  7 steps, all passed
load-32players.test.js: 50 turn iterations, all under SLA
gemini-cost.test.js   :  2 scenarios, both under budget
```
