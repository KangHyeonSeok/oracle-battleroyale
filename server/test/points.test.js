/**
 * points.test.js — Unit tests for oracle-point-system spec
 *
 * Run: node test/points.test.js
 *
 * Uses an in-memory mock of the DB pool so no real Postgres is required.
 * Tests: initial balance, deductPoint, awardPoints, grantDailyBonus (dedup).
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

// ---------------------------------------------------------------------------
// Mock dependencies before requiring points.js
// ---------------------------------------------------------------------------

// Mock room-manager broadcastToUser (no-op in tests)
const broadcastCalls = [];
require.cache[require.resolve('../src/game/room-manager')] = {
  id: require.resolve('../src/game/room-manager'),
  filename: require.resolve('../src/game/room-manager'),
  loaded: true,
  exports: {
    broadcastToUser(userId, message) {
      broadcastCalls.push({ userId, message });
    },
  },
};

// Fake DB state
const fakeUsers = {
  1: { id: 1, constellation_points: 100 },
  2: { id: 2, constellation_points: 5 },  // insufficient for deduct
};
const fakeTransactions = [];

function fakePool() {
  return {
    query(sql, params) {
      const s = sql.replace(/\s+/g, ' ').trim();

      // getPoints
      if (s.startsWith('SELECT constellation_points FROM users WHERE id =')) {
        const id = params[0];
        const user = fakeUsers[id];
        return Promise.resolve({ rows: user ? [{ constellation_points: user.constellation_points }] : [] });
      }

      // deductPoint UPDATE
      if (s.startsWith('UPDATE users SET constellation_points = constellation_points -')) {
        const cost = params[0];
        const id = params[1];
        const user = fakeUsers[id];
        if (!user || user.constellation_points < cost) return Promise.resolve({ rows: [] });
        user.constellation_points -= cost;
        return Promise.resolve({ rows: [{ constellation_points: user.constellation_points }] });
      }

      // awardPoints UPDATE
      if (s.startsWith('UPDATE users SET constellation_points = constellation_points +')) {
        const delta = params[0];
        const id = params[1];
        const user = fakeUsers[id];
        if (!user) return Promise.resolve({ rows: [] });
        user.constellation_points += delta;
        return Promise.resolve({ rows: [{ constellation_points: user.constellation_points }] });
      }

      // _logTransaction INSERT
      if (s.startsWith('INSERT INTO point_transactions')) {
        const [accountId, matchId, delta, reason] = params;
        fakeTransactions.push({ accountId, matchId, delta, reason, created_at: new Date() });
        return Promise.resolve({ rows: [] });
      }

      // grantDailyBonus SELECT (check existing daily_login today)
      if (s.startsWith('SELECT id FROM point_transactions')) {
        const accountId = params[0];
        const today = new Date();
        today.setHours(0, 0, 0, 0);
        const already = fakeTransactions.some(
          (t) => t.accountId === accountId && t.reason === 'daily_login' && t.created_at >= today
        );
        return Promise.resolve({ rows: already ? [{ id: 1 }] : [] });
      }

      return Promise.resolve({ rows: [] });
    },
  };
}

// Inject fake pool
require.cache[require.resolve('../src/db/pool')] = {
  id: require.resolve('../src/db/pool'),
  filename: require.resolve('../src/db/pool'),
  loaded: true,
  exports: { pool: fakePool() },
};

// Now safe to load points module
const {
  getPoints,
  deductPoint,
  awardPoints,
  grantDailyBonus,
  ORACLE_COST,
  WIN_REWARD,
  COMPLETION_REWARD,
  DAILY_BONUS,
} = require('../src/oracle/points');

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

async function run() {
  console.log('\n=== oracle-point-system unit tests ===\n');

  // AC1 — initial balance
  console.log('AC1: Initial balance');
  const balance = await getPoints(1);
  assert(balance === 100, `new user starts with 100pt (got ${balance})`);

  // AC2 — insufficient_points when balance < 10
  console.log('\nAC2: Deduct with insufficient balance');
  const result2 = await deductPoint(2, null, 'oracle_send');
  assert(result2.error === 'insufficient_points', 'returns { error: "insufficient_points" } when balance < 10');
  assert(fakeUsers[2].constellation_points === 5, 'balance unchanged on failure');

  // AC3 — deduct succeeds, balance -10, transaction logged
  console.log('\nAC3: Deduct success → -10pt + transaction');
  const before = fakeUsers[1].constellation_points;
  const result3 = await deductPoint(1, 42, 'oracle_send');
  assert(!result3.error, 'no error on sufficient balance');
  assert(result3.points === before - ORACLE_COST, `balance reduced by ${ORACLE_COST}pt`);
  const tx3 = fakeTransactions.find((t) => t.accountId === 1 && t.reason === 'oracle_send');
  assert(tx3 !== undefined, 'point_transactions record created');
  assert(tx3.delta === -ORACLE_COST, `transaction delta = -${ORACLE_COST}`);
  assert(tx3.matchId === 42, 'transaction.match_id set');
  const wsMsg3 = broadcastCalls.find((c) => c.userId === 1 && c.message.type === 'points_update');
  assert(wsMsg3 !== undefined, 'points_update WS event broadcast after deduct');

  // AC4 — awardPoints win_bonus +50
  console.log('\nAC4: Win bonus +50pt');
  const beforeWin = fakeUsers[1].constellation_points;
  await awardPoints(1, 99, 'win_bonus', WIN_REWARD);
  assert(fakeUsers[1].constellation_points === beforeWin + WIN_REWARD, `balance +${WIN_REWARD}pt after win`);
  const txWin = fakeTransactions.find((t) => t.accountId === 1 && t.reason === 'win_bonus');
  assert(txWin !== undefined, 'win_bonus transaction logged');
  assert(txWin.delta === WIN_REWARD, `win_bonus delta = +${WIN_REWARD}`);

  // AC5 — daily bonus idempotency
  console.log('\nAC5: Daily login bonus (no duplicate)');
  fakeTransactions.length = 0; // clear for clean test
  const beforeDaily = fakeUsers[1].constellation_points;
  const bonus1 = await grantDailyBonus(1);
  assert(bonus1 !== null, 'first call grants bonus');
  assert(fakeUsers[1].constellation_points === beforeDaily + DAILY_BONUS, `balance +${DAILY_BONUS}pt`);
  const bonus2 = await grantDailyBonus(1);
  assert(bonus2 === null, 'second call same day returns null (no duplicate)');
  assert(fakeUsers[1].constellation_points === beforeDaily + DAILY_BONUS, 'balance unchanged on second call');

  // AC6 — WS points_update emitted on balance change
  console.log('\nAC6: WS points_update on balance change');
  broadcastCalls.length = 0;
  await awardPoints(1, null, 'completion_bonus', COMPLETION_REWARD);
  const wsMsg6 = broadcastCalls.find((c) => c.userId === 1 && c.message.type === 'points_update');
  assert(wsMsg6 !== undefined, 'points_update event fired');
  assert(typeof wsMsg6.message.points === 'number', 'event carries numeric points value');

  // ---------------------------------------------------------------------------
  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===\n`);
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error('Test runner error:', err);
  process.exit(1);
});
