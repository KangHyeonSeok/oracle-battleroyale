/**
 * leaderboard.test.js — Unit tests for oracle-ranking-leaderboard spec
 *
 * Run: node test/leaderboard.test.js
 *
 * Uses an in-memory mock of the DB pool so no real Postgres is required.
 * Tests: sorting, tiebreak, limit, LEFT JOIN nulls, empty results, displayName fallback.
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
// DB stub helpers
// ---------------------------------------------------------------------------

// Simulates ORDER BY constellation_points DESC, total_wins DESC, created_at ASC
// and LIMIT, matching the SQL in leaderboard.js.
function buildRows(users, stats, limit) {
  const statsMap = {};
  for (const s of stats) statsMap[s.account_id] = s;

  const joined = users.map((u) => {
    const ps = statsMap[u.id] || null;
    return {
      id: u.id,
      display_name: u.display_name,
      constellation_points: u.constellation_points,
      created_at: u.created_at,
      total_wins:    ps ? ps.total_wins    : 0,
      total_matches: ps ? ps.total_matches : 0,
      oracle_sent:   ps ? ps.oracle_sent   : 0,
    };
  });

  joined.sort((a, b) => {
    if (b.constellation_points !== a.constellation_points)
      return b.constellation_points - a.constellation_points;
    if (b.total_wins !== a.total_wins)
      return b.total_wins - a.total_wins;
    return new Date(a.created_at) - new Date(b.created_at);
  });

  return joined.slice(0, limit).map((r, i) => ({
    rank:          i + 1,
    account_id:    r.id,
    display_name:  r.display_name === '' ? '(이름 없음)' : r.display_name,
    oracle_points: r.constellation_points,
    total_wins:    r.total_wins,
    total_matches: r.total_matches,
    win_rate:      r.total_matches > 0 ? Math.round(100 * r.total_wins / r.total_matches) : 0,
    oracle_sent:   r.oracle_sent,
  }));
}

// Installs a mock pool that returns pre-built rows for the next query call.
function mockPool(rows) {
  const resolved = require.resolve('../src/db/pool');
  require.cache[resolved] = {
    id: resolved,
    filename: resolved,
    loaded: true,
    exports: {
      pool: {
        query: async () => ({ rows }),
      },
    },
  };
  // Clear leaderboard.js cache so it picks up the new pool mock.
  const lbResolved = require.resolve('../src/leaderboard/leaderboard');
  delete require.cache[lbResolved];
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const BASE_DATE = '2024-01-01T00:00:00Z';
const LATER_DATE = '2024-06-01T00:00:00Z';

// 30 users for limit tests
const thirtyUsers = Array.from({ length: 30 }, (_, i) => ({
  id: i + 1,
  display_name: `Player${i + 1}`,
  constellation_points: 1000 - i * 10,
  created_at: BASE_DATE,
}));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

async function runTests() {
  console.log('\n=== leaderboard.test.js ===\n');

  // ── Test 1: Basic sort — constellation_points DESC, top 20 ──────────────────
  console.log('Test 1: Basic sort (constellation_points DESC, default limit 20)');
  {
    const rows = buildRows(thirtyUsers, [], 20);
    mockPool(rows);
    const { getLeaderboard } = require('../src/leaderboard/leaderboard');
    const result = await getLeaderboard(20);
    assertEqual(result.length, 20, 'Returns exactly 20 entries');
    assertEqual(result[0].oraclePoints, 1000, 'First entry has highest points (1000)');
    assertEqual(result[19].oraclePoints, 810, 'Last entry (#20) has points 810');
    let sorted = true;
    for (let i = 1; i < result.length; i++) {
      if (result[i].oraclePoints > result[i - 1].oraclePoints) { sorted = false; break; }
    }
    assert(sorted, 'Entries are in descending oracle_points order');
  }

  // ── Test 2: Tiebreak — total_wins DESC ──────────────────────────────────────
  console.log('\nTest 2: Tiebreak — total_wins DESC');
  {
    const users = [
      { id: 1, display_name: 'A', constellation_points: 500, created_at: BASE_DATE },
      { id: 2, display_name: 'B', constellation_points: 500, created_at: BASE_DATE },
      { id: 3, display_name: 'C', constellation_points: 500, created_at: BASE_DATE },
    ];
    const stats = [
      { account_id: 1, total_wins: 3, total_matches: 10, oracle_sent: 0 },
      { account_id: 2, total_wins: 7, total_matches: 10, oracle_sent: 0 },
      { account_id: 3, total_wins: 5, total_matches: 10, oracle_sent: 0 },
    ];
    const rows = buildRows(users, stats, 20);
    mockPool(rows);
    const { getLeaderboard } = require('../src/leaderboard/leaderboard');
    const result = await getLeaderboard(20);
    assertEqual(result[0].displayName, 'B', 'Rank 1 is player with most wins (B=7)');
    assertEqual(result[1].displayName, 'C', 'Rank 2 is second most wins (C=5)');
    assertEqual(result[2].displayName, 'A', 'Rank 3 is least wins (A=3)');
  }

  // ── Test 3: Tiebreak — created_at ASC ───────────────────────────────────────
  console.log('\nTest 3: Tiebreak — created_at ASC (earlier account wins)');
  {
    const users = [
      { id: 1, display_name: 'Later',  constellation_points: 500, created_at: LATER_DATE },
      { id: 2, display_name: 'Earlier', constellation_points: 500, created_at: BASE_DATE },
    ];
    const stats = [
      { account_id: 1, total_wins: 5, total_matches: 10, oracle_sent: 0 },
      { account_id: 2, total_wins: 5, total_matches: 10, oracle_sent: 0 },
    ];
    const rows = buildRows(users, stats, 20);
    mockPool(rows);
    const { getLeaderboard } = require('../src/leaderboard/leaderboard');
    const result = await getLeaderboard(20);
    assertEqual(result[0].displayName, 'Earlier', 'Earlier account ranks higher when points and wins are tied');
    assertEqual(result[1].displayName, 'Later', 'Later account ranks lower when tied');
  }

  // ── Test 4: Limit=20 with 30 entries ────────────────────────────────────────
  console.log('\nTest 4: Default limit=20 returns only 20 of 30 entries');
  {
    const rows = buildRows(thirtyUsers, [], 20);
    mockPool(rows);
    const { getLeaderboard } = require('../src/leaderboard/leaderboard');
    const result = await getLeaderboard(20);
    assertEqual(result.length, 20, 'Exactly 20 entries returned from 30-user pool');
  }

  // ── Test 5: Limit parameter ──────────────────────────────────────────────────
  console.log('\nTest 5: Limit parameter (limit=5 and limit=200 capped to 100)');
  {
    const rows5 = buildRows(thirtyUsers, [], 5);
    mockPool(rows5);
    let { getLeaderboard } = require('../src/leaderboard/leaderboard');
    let result = await getLeaderboard(5);
    assertEqual(result.length, 5, 'limit=5 returns 5 entries');

    // Test limit=200 is capped at 100 by capturing the query param
    let capturedLimit = null;
    const resolvedPool = require.resolve('../src/db/pool');
    const resolvedLb = require.resolve('../src/leaderboard/leaderboard');
    require.cache[resolvedPool] = {
      id: resolvedPool, filename: resolvedPool, loaded: true,
      exports: {
        pool: {
          query: async (_sql, params) => {
            capturedLimit = params[0];
            return { rows: buildRows(thirtyUsers, [], params[0]) };
          },
        },
      },
    };
    delete require.cache[resolvedLb];
    ({ getLeaderboard } = require('../src/leaderboard/leaderboard'));
    result = await getLeaderboard(200);
    assertEqual(capturedLimit, 100, 'limit=200 is capped to 100 before SQL query');
    assert(result.length <= 100, 'limit=200 returns at most 100 entries');
  }

  // ── Test 6: player_stats row missing (LEFT JOIN) ─────────────────────────────
  console.log('\nTest 6: No player_stats row → defaults to 0s');
  {
    const users = [{ id: 1, display_name: 'Newbie', constellation_points: 100, created_at: BASE_DATE }];
    const rows = buildRows(users, [], 20); // no stats entry for id=1
    mockPool(rows);
    const { getLeaderboard } = require('../src/leaderboard/leaderboard');
    const result = await getLeaderboard(20);
    assertEqual(result.length, 1, 'One entry returned');
    assertEqual(result[0].totalMatches, 0, 'totalMatches defaults to 0');
    assertEqual(result[0].totalWins, 0, 'totalWins defaults to 0');
    assertEqual(result[0].oracleSent, 0, 'oracleSent defaults to 0');
    assertEqual(result[0].winRate, 0, 'winRate defaults to 0');
  }

  // ── Test 7: Empty leaderboard ────────────────────────────────────────────────
  console.log('\nTest 7: Empty DB → entries: []');
  {
    mockPool([]);
    const { getLeaderboard } = require('../src/leaderboard/leaderboard');
    const result = await getLeaderboard(20);
    assert(Array.isArray(result), 'Result is an array');
    assertEqual(result.length, 0, 'Empty array when no users exist');
  }

  // ── Test 8: displayName empty string fallback ────────────────────────────────
  console.log('\nTest 8: displayName empty string → "(이름 없음)"');
  {
    const users = [{ id: 1, display_name: '', constellation_points: 200, created_at: BASE_DATE }];
    const rows = buildRows(users, [], 20);
    mockPool(rows);
    const { getLeaderboard } = require('../src/leaderboard/leaderboard');
    const result = await getLeaderboard(20);
    assertEqual(result[0].displayName, '(이름 없음)', 'Empty display_name falls back to "(이름 없음)"');
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
