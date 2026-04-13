---
specId: server-unit-tests-expansion
title: 서버 단위 테스트 확장 (리더보드 + 신탁 쿨다운)
status: in-flight
owner: partner
runnerProfile: developer
runnerExecution: assistant
createdAt: 2026-04-13
updatedAt: 2026-04-13
dependsOn:
  - oracle-ranking-leaderboard
  - oracle-cooldown
  - server-test-ci
---

# server-unit-tests-expansion: 서버 단위 테스트 확장

## 목표

`server-test-ci` 스펙에서 "별도 구현 필요(P1-4, P1-5)"로 명시된 두 테스트 파일을 작성하여
기존 `npm test` 체인에 포함시킨다.

- `server/test/leaderboard.test.js` — 리더보드 정렬·tiebreak·LEFT JOIN·limit 검증
- `server/test/oracle-cooldown.test.js` — Redis 기반 쿨다운 60초 강제 검증

## 배경

- `oracle-ranking-leaderboard` 스펙 "단위 테스트 명세(P1-5)" 섹션에 8개 케이스 사전 정의됨
- `oracle-cooldown` 구현(`server/src/oracle/routes.js`)은 완료됐으나 테스트 커버리지 없음
- `server-test-ci` 워크플로 추가 전에 테스트가 통과해야 AC2(전체 통과) 충족 가능
- 기존 테스트는 custom minimal harness(`assert` 함수 + passed/failed 카운터) 패턴 사용 — 동일 패턴 유지

---

## 파일 1: `server/test/leaderboard.test.js` (신규)

테스트 환경: `pg-mem` (PostgreSQL in-memory) 또는 DB mock (기존 `points.test.js` 패턴 참고)

| # | 케이스 | 검증 내용 |
|---|--------|-----------|
| 1 | 기본 정렬 | constellation_points DESC로 최대 20개 반환 |
| 2 | tiebreak — total_wins | 동점 시 total_wins DESC 우선 |
| 3 | tiebreak — created_at | total_wins도 동점 시 created_at ASC (먼저 가입한 순) |
| 4 | limit 적용 | DB 30개 항목 시 기본 limit=20으로 상위 20개만 반환 |
| 5 | limit 파라미터 | limit=5 요청 → 5개, limit=200 요청 → 상한 100개 |
| 6 | player_stats 행 없는 계정 | LEFT JOIN → total_matches=0, total_wins=0, winRate=0 |
| 7 | 빈 리더보드 | `{ "entries": [] }` 반환, 오류 없음 |
| 8 | displayName 빈 문자열 | NULLIF 패턴으로 "(이름 없음)" fallback 반환 |

### 구현 가이드

> ⚠️ **주의**: `getLeaderboard(limit)` 함수는 `pool` 인자를 받지 않음. `pool`은 `server/src/db/pool.js`에서 모듈 수준으로 require됨.
> 따라서 `require.cache` 방식으로 `../src/db/pool` 모듈 전체를 mock 한 뒤 `getLeaderboard`를 require해야 함.

```js
/**
 * leaderboard.test.js — Unit tests for oracle-ranking-leaderboard spec
 * Run: node test/leaderboard.test.js
 *
 * Mocks the DB pool via require.cache injection (same pattern as points.test.js).
 * getLeaderboard(limit) — pool은 모듈 레벨 require이므로 cache injection 사용.
 */
'use strict';

let passed = 0, failed = 0;
function assert(cond, label) {
  if (cond) { console.log(`  ✓ ${label}`); passed++; }
  else { console.error(`  ✗ ${label}`); failed++; }
}

// --- Mock pool before requiring leaderboard.js ---
let mockRows = [];
const poolMock = {
  query: async () => ({ rows: mockRows }),
};
require.cache[require.resolve('../src/db/pool')] = {
  id: require.resolve('../src/db/pool'),
  filename: require.resolve('../src/db/pool'),
  loaded: true,
  exports: { pool: poolMock },
};

const { getLeaderboard } = require('../src/leaderboard/leaderboard');

// 각 테스트마다 mockRows를 교체하여 시나리오 설정
// 예: 기본 정렬 테스트
mockRows = [
  { rank: '1', account_id: 1, display_name: '알파', oracle_points: '100', total_wins: '5', total_matches: '10', win_rate: '50', oracle_sent: '20' },
  // ... 나머지 rows
];
const result = await getLeaderboard(20);
assert(result[0].oraclePoints === 100, '기본 정렬: 첫 항목 oraclePoints=100');

// 실행 종료 시:
if (failed > 0) { console.error(`\n${failed} test(s) failed`); process.exit(1); }
else { console.log(`\nAll ${passed} tests passed`); }
```

---

## 파일 2: `server/test/oracle-cooldown.test.js` (신규)

테스트 환경: Redis mock (in-memory Map) + `setRedisClient()` 주입

> ⚠️ **접근 방식**: `cooldownKey` 함수는 `oracle/routes.js`에서 비공개. `setRedisClient(client)` 는 exported되므로,
> `redisMock`을 주입 후 `cooldownKey`는 inline 재현(`oracle:cooldown:{userId}:{matchId}`)으로 테스트.
> HTTP 429/200 검증은 쿨다운 키 존재 여부를 Redis mock에서 직접 확인하는 방식으로 대체.
> 전체 HTTP 라우트 테스트가 필요하면 `supertest` devDependency 추가 후 별도 e2e 테스트로 분리 권장.



| # | 케이스 | 검증 내용 |
|---|--------|-----------|
| 1 | 첫 신탁 전송 | 쿨다운 키 없음 → POST /oracle 처리 후 Redis에 `oracle:cooldown:{uid}:{matchId}` EX 60 설정 |
| 2 | 쿨다운 중 재전송 | 키 존재 → HTTP 429 `{ "error": "Cooldown active. Try again in Ns" }` 반환 |
| 3 | TTL 만료 후 재전송 | TTL 0 (만료) → 정상 처리 (HTTP 200) |
| 4 | 다른 경기 독립 쿨다운 | matchId A 쿨다운 중 matchId B 전송 → 정상 처리 |
| 5 | 다른 유저 독립 쿨다운 | userId X 쿨다운 중 userId Y 전송 → 정상 처리 |
| 6 | cooldownKey 형식 | `oracle:cooldown:{userId}:{matchId}` 형식 검증 |

### 구현 가이드

```js
/**
 * oracle-cooldown.test.js — Unit tests for oracle-cooldown spec
 * Run: node test/oracle-cooldown.test.js
 *
 * Mocks Redis client with an in-memory store to test cooldown enforcement.
 */
'use strict';

// In-memory Redis mock
const store = new Map();
const redisMock = {
  get: async (key) => store.has(key) ? '1' : null,
  set: async (key, val, opts) => {
    store.set(key, val);
    if (opts && opts.EX) {
      setTimeout(() => store.delete(key), opts.EX * 1000);
    }
  },
  ttl: async (key) => store.has(key) ? 60 : -2,
};

// cooldownKey 함수 직접 import 또는 inline 재현
function cooldownKey(userId, matchId) {
  return `oracle:cooldown:${userId}:${matchId}`;
}

// ... 각 케이스 테스트
```

---

## `server/package.json` 수정 (test 스크립트 추가)

```json
"test": "node test/combat.test.js && node test/points.test.js && node test/e2e-flow.test.js && node test/matchmaker.test.js && node test/load-32players.test.js && node test/gemini-cost.test.js && node test/leaderboard.test.js && node test/oracle-cooldown.test.js"
```

> 기존 6개 테스트 뒤에 2개 추가. `server-test-ci` AC2 충족 조건 갱신 필요.

---

## 완료 기준 (AC)

| AC | 내용 |
|----|------|
| AC1 | `node test/leaderboard.test.js` 8개 테스트 모두 통과 |
| AC2 | `node test/oracle-cooldown.test.js` 6개 테스트 모두 통과 |
| AC3 | `server/package.json` test 스크립트에 두 파일 추가, `npm test` 전체 통과 |
| AC4 | leaderboard tiebreak 테스트: constellation_points 동점 시 total_wins DESC → created_at ASC 순서 검증 |
| AC5 | oracle-cooldown 테스트: 쿨다운 중 재전송 시 HTTP 429 검증 (Redis mock 사용) |

---

## 엣지케이스

| 케이스 | 처리 |
|--------|------|
| Redis mock TTL 경쟁 조건 | setTimeout 기반 TTL은 테스트에서 직접 store.delete()로 즉시 만료 처리 |
| leaderboard.js DB 연결 필요 | pool mock 주입 패턴 (points.test.js 동일 방식) 사용 |
| `npm test` 체인 중 하나 실패 | process.exit(1) → 이후 테스트 실행 중단 (기존 패턴과 동일) |

---

## 제약

- 외부 테스트 프레임워크(Jest/Mocha) 미사용 — 기존 custom harness 패턴 유지
- 실제 Redis/PostgreSQL 미사용 — in-memory mock 전용
- `server-test-ci` AC2 업데이트: "combat(17), points(18), matchmaker, e2e-flow(7단계), load, gemini-cost, **leaderboard(8), oracle-cooldown(6)**" 로 갱신 필요

## 예상 기간
0.5일 (파일 2개, 각 ~100줄)
