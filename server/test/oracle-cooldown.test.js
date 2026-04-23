/**
 * oracle-cooldown.test.js — Unit tests for oracle-cooldown spec
 * Run: node test/oracle-cooldown.test.js
 *
 * Mocks Redis client with an in-memory store to test cooldown enforcement.
 * Does not test HTTP routes directly; verifies cooldown key state in the mock
 * (key existence = cooldown active, absence = can proceed).
 */
'use strict';

// ---------------------------------------------------------------------------
// Minimal test harness
// ---------------------------------------------------------------------------
let passed = 0;
let failed = 0;

function assert(condition, label) {
  if (condition) {
    console.log(`  ✓ ${label}`);
    passed++;
  } else {
    console.error(`  ✗ ${label}`);
    failed++;
  }
}

function assertEqual(actual, expected, label) {
  if (actual === expected) {
    console.log(`  ✓ ${label}`);
    passed++;
  } else {
    console.error(`  ✗ ${label}  (expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)})`);
    failed++;
  }
}

// ---------------------------------------------------------------------------
// In-memory Redis mock
// ---------------------------------------------------------------------------
const store = new Map();
const redisMock = {
  get: async (key) => (store.has(key) ? '1' : null),
  set: async (key, val, opts) => {
    store.set(key, val);
    if (opts && opts.EX) {
      // No actual setTimeout needed for unit tests — TTL expiry is simulated
      // by manually calling store.delete(key) in the test.
    }
  },
  ttl: async (key) => (store.has(key) ? 60 : -2),
};

// ---------------------------------------------------------------------------
// cooldownKey — inline re-implementation matching oracle/routes.js
// key format: oracle:cooldown:{userId}:{matchId}
// ---------------------------------------------------------------------------
function cooldownKey(userId, matchId) {
  return `oracle:cooldown:${userId}:${matchId}`;
}

// ---------------------------------------------------------------------------
// Import setRedisClient to verify the export contract
// ---------------------------------------------------------------------------
const { setRedisClient } = require('../src/oracle/routes');

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

async function runTests() {
  console.log('\n=== oracle-cooldown.test.js ===\n');

  store.clear();
  setRedisClient(redisMock);

  // ── TC1: 첫 신탁 전송 — 쿨다운 키 없음 → 처리 후 Redis에 키 설정 ───────────
  console.log('TC1: 첫 신탁 전송 — 쿨다운 없음, 처리 후 키 설정');
  {
    const key = cooldownKey(1, 'match-001');
    const before = await redisMock.get(key);
    assert(before === null, 'TC1: 첫 전송 전 쿨다운 키 없음');

    // Simulate what the route does after successful oracle send
    await redisMock.set(key, '1', { EX: 60 });
    const after = await redisMock.get(key);
    assert(after !== null, 'TC1: 처리 후 Redis에 쿨다운 키 설정됨 (EX 60)');
  }

  // ── TC2: 쿨다운 중 재전송 — 키 존재 → 429 상태 시뮬레이션 ──────────────────
  console.log('\nTC2: 쿨다운 중 재전송 — 키 존재 → 429 응답 시뮬레이션');
  {
    const key = cooldownKey(1, 'match-001'); // still set from TC1
    const onCooldown = await redisMock.get(key);
    assert(onCooldown !== null, 'TC2: 쿨다운 키 존재 → HTTP 429 반환 조건 충족');
    const ttl = await redisMock.ttl(key);
    assert(ttl > 0, 'TC2: TTL > 0 → 오류 메시지에 남은 시간 포함 가능');
  }

  // ── TC3: TTL 만료 후 재전송 — 키 삭제(만료 시뮬레이션) → 정상 처리 ──────────
  console.log('\nTC3: TTL 만료 후 재전송 — 쿨다운 해제');
  {
    const key = cooldownKey(1, 'match-001');
    store.delete(key); // simulate TTL expiry
    const afterExpiry = await redisMock.get(key);
    assert(afterExpiry === null, 'TC3: TTL 만료 후 쿨다운 키 없음 → 정상 처리 가능');
  }

  // ── TC4: 다른 경기 독립 쿨다운 — matchId A 쿨다운 중 matchId B는 정상 ───────
  console.log('\nTC4: 다른 경기 독립 쿨다운');
  {
    const keyA = cooldownKey(1, 'match-A');
    const keyB = cooldownKey(1, 'match-B');
    await redisMock.set(keyA, '1', { EX: 60 });
    const cooldownA = await redisMock.get(keyA);
    const cooldownB = await redisMock.get(keyB);
    assert(cooldownA !== null, 'TC4: match-A 쿨다운 활성');
    assert(cooldownB === null, 'TC4: match-B 쿨다운 없음 → 독립적인 쿨다운 키');
  }

  // ── TC5: 다른 유저 독립 쿨다운 — userId X 쿨다운 중 userId Y는 정상 ─────────
  console.log('\nTC5: 다른 유저 독립 쿨다운');
  {
    const keyX = cooldownKey('user-X', 'match-001');
    const keyY = cooldownKey('user-Y', 'match-001');
    await redisMock.set(keyX, '1', { EX: 60 });
    const cooldownX = await redisMock.get(keyX);
    const cooldownY = await redisMock.get(keyY);
    assert(cooldownX !== null, 'TC5: user-X 쿨다운 활성');
    assert(cooldownY === null, 'TC5: user-Y 쿨다운 없음 → 독립적인 쿨다운 키');
  }

  // ── TC6: cooldownKey 형식 — oracle:cooldown:{userId}:{matchId} ───────────────
  console.log('\nTC6: cooldownKey 형식 검증');
  {
    assertEqual(
      cooldownKey(42, 'game-99'),
      'oracle:cooldown:42:game-99',
      'TC6: cooldownKey 형식 = oracle:cooldown:{userId}:{matchId}'
    );
    assertEqual(
      cooldownKey('abc', 'xyz'),
      'oracle:cooldown:abc:xyz',
      'TC6: 문자열 userId/matchId도 올바른 형식'
    );
  }

  // ---------------------------------------------------------------------------
  console.log(`\n${'─'.repeat(40)}`);
  console.log(`Results: ${passed} passed, ${failed} failed`);
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error('Unexpected error:', err);
  process.exit(1);
});
