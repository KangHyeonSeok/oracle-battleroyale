/**
 * matchmaker.test.js — Unit tests for Matchmaker (no DB/Redis required)
 *
 * Tests:
 *   1. 32 players → immediate match start (AC1)
 *   2. 10 players + 60 s timeout → NPC fill (AC2)
 *   3. Duplicate enqueue prevention (AC3)
 *   4. queue_leave removes entry + broadcasts (AC4/AC5)
 */

'use strict';

const assert = require('assert');

// ---------------------------------------------------------------------------
// Minimal stubs — no real DB or Redis needed
// ---------------------------------------------------------------------------

let matchRecords = [];
let broadcastHistory = [];

// Stub the pool module before requiring matchmaker
const Module = require('module');
const originalLoad = Module._load;

Module._load = function (request, parent, isMain) {
  if (request === '../db/pool' || request.endsWith('/db/pool')) {
    return {
      pool: {
        query: async (sql, params) => {
          if (sql.includes('INSERT INTO matches')) {
            const id = matchRecords.length + 1;
            matchRecords.push({ id, status: 'waiting' });
            return { rows: [{ id }] };
          }
          if (sql.includes('INSERT INTO match_participants')) {
            return { rows: [] };
          }
          if (sql.includes('SELECT mp.character_id')) {
            // Return stub participants
            return { rows: (params || []).map((_, i) => ({
              character_id: i + 1,
              is_npc: false,
              name: `char${i}`,
              class: 'warrior',
              rules_table: null,
              credulity: 50,
            })) };
          }
          if (sql.includes('UPDATE matches')) {
            return { rows: [] };
          }
          return { rows: [] };
        },
      },
    };
  }
  if (request === '../ai/npc-presets' || request.endsWith('/ai/npc-presets')) {
    return {
      ensureNpcCharactersExist: async () => [101, 102, 103, 104, 105],
    };
  }
  if (request === './redis-state' || request.endsWith('/game/redis-state')) {
    return {
      buildInitialState: () => ({ turn: 0, characters: [] }),
      saveMatchState: async () => {},
    };
  }
  if (request === './turn-scheduler' || request.endsWith('/game/turn-scheduler')) {
    return {
      startMatchTimer: () => {},
    };
  }
  return originalLoad.apply(this, arguments);
};

// Now require matchmaker with stubs in place
const { matchmaker } = require('../src/game/matchmaker');

// Stub wss for broadcast capture
const stubWss = {
  clients: new Set(),
};
matchmaker._wss = stubWss;
matchmaker._redisClient = {};

// Helper: create a fake WebSocket
function fakeWs() {
  const messages = [];
  return {
    readyState: 1,
    _messages: messages,
    send(data) { messages.push(JSON.parse(data)); },
  };
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

function resetState() {
  matchmaker.queue = [];
  if (matchmaker.matchTimerRef) {
    clearTimeout(matchmaker.matchTimerRef);
    matchmaker.matchTimerRef = null;
  }
  matchRecords = [];
  stubWss.clients = new Set();
}

// ---------------------------------------------------------------------------
// Test 1: 32 players → immediate match start (AC1)
// ---------------------------------------------------------------------------
async function test_32_players_immediate_start() {
  resetState();

  const broadcastReceiver = fakeWs();
  stubWss.clients.add(broadcastReceiver);

  const players = [];
  for (let i = 1; i <= 32; i++) {
    const ws = fakeWs();
    stubWss.clients.add(ws);
    players.push({ userId: i, ws });
    matchmaker.enqueue(i, i * 10, ws);
  }

  // Queue should be empty (all taken for match)
  assert.strictEqual(matchmaker.queue.length, 0, 'Queue should be empty after 32 players');
  assert(matchmaker.matchTimerRef === null, 'No pending timer after immediate start');

  // Wait for async match creation to complete
  await new Promise(r => setTimeout(r, 50));

  // Match record should be created
  assert(matchRecords.length >= 1, 'Match record should exist (AC6)');

  // broadcast receiver should have received match_starting
  const matchStartingMsg = broadcastReceiver._messages.find(m => m.type === 'match_starting');
  assert(matchStartingMsg, 'match_starting broadcast should be sent (AC1)');
  assert.strictEqual(matchStartingMsg.playerCount, 32, 'playerCount should be 32');
  assert.strictEqual(matchStartingMsg.npcCount, 0, 'npcCount should be 0');
  assert.strictEqual(matchStartingMsg.startsIn, 5, 'startsIn should be 5');

  console.log('✓ Test 1 passed: 32 players → immediate match start');
}

// ---------------------------------------------------------------------------
// Test 2: 10 players + timeout → NPC fill (AC2)
// ---------------------------------------------------------------------------
async function test_10_players_npc_fill() {
  resetState();

  const broadcastReceiver = fakeWs();
  stubWss.clients.add(broadcastReceiver);

  for (let i = 1; i <= 10; i++) {
    const ws = fakeWs();
    stubWss.clients.add(ws);
    matchmaker.enqueue(i, i * 10, ws);
  }

  assert.strictEqual(matchmaker.queue.length, 10, 'Queue should have 10 players');
  assert(matchmaker.matchTimerRef !== null, '60 s timer should be set');

  // Manually fire timeout
  clearTimeout(matchmaker.matchTimerRef);
  matchmaker.matchTimerRef = null;
  await matchmaker.tryStartMatch();

  assert.strictEqual(matchmaker.queue.length, 0, 'Queue should be empty after timeout start');
  assert(matchRecords.length >= 1, 'Match record should exist (AC6)');

  const matchStartingMsg = broadcastReceiver._messages.find(m => m.type === 'match_starting');
  assert(matchStartingMsg, 'match_starting broadcast should be sent (AC2)');
  assert.strictEqual(matchStartingMsg.playerCount, 10, 'playerCount should be 10');
  assert.strictEqual(matchStartingMsg.npcCount, 22, 'npcCount should be 22 (32 - 10)');

  console.log('✓ Test 2 passed: 10 players + timeout → NPC 22명 충원 after 60 s');
}

// ---------------------------------------------------------------------------
// Test 3: Duplicate enqueue prevention (AC3)
// ---------------------------------------------------------------------------
async function test_duplicate_enqueue() {
  resetState();

  const ws1 = fakeWs();
  const ws2 = fakeWs();

  matchmaker.enqueue(42, 100, ws1); // first entry
  matchmaker.enqueue(42, 200, ws2); // duplicate — should replace

  const entries = matchmaker.queue.filter(e => e.userId === 42);
  assert.strictEqual(entries.length, 1, 'Only one entry per userId (AC3)');
  assert.strictEqual(entries[0].characterId, 200, 'Should use latest characterId');
  assert.strictEqual(matchmaker.queue.length, 1, 'Total queue size should be 1');

  console.log('✓ Test 3 passed: duplicate enqueue prevention (AC3)');
}

// ---------------------------------------------------------------------------
// Test 4: queue_leave removes player + broadcasts (AC4)
// ---------------------------------------------------------------------------
async function test_queue_leave() {
  resetState();

  const observer = fakeWs();
  stubWss.clients.add(observer);

  const ws = fakeWs();
  matchmaker.enqueue(7, 70, ws);
  const countBefore = matchmaker.queue.length;

  matchmaker.dequeue(7);

  assert.strictEqual(matchmaker.queue.length, 0, 'Queue should be empty after dequeue (AC4)');

  // Should have received queue_update messages
  const updates = observer._messages.filter(m => m.type === 'queue_update');
  assert(updates.length >= 2, 'Should broadcast queue_update on join and leave (AC5)');

  // Last update should show count 0
  const last = updates[updates.length - 1];
  assert.strictEqual(last.count, 0, 'Last queue_update count should be 0');

  console.log('✓ Test 4 passed: queue_leave removes entry and broadcasts (AC4/AC5)');
}

// ---------------------------------------------------------------------------
// Run all tests
// ---------------------------------------------------------------------------
(async () => {
  try {
    await test_32_players_immediate_start();
    await test_10_players_npc_fill();
    await test_duplicate_enqueue();
    await test_queue_leave();
    console.log('\nAll matchmaker tests passed.');
    process.exit(0);
  } catch (err) {
    console.error('\nTest failed:', err.message);
    console.error(err.stack);
    process.exit(1);
  }
})();
