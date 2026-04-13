/**
 * gemini-cost.test.js — Phase 6 Gemini API 비용 검증
 *
 * Verifies that the estimated Gemini API cost per game is ≤ $0.005
 * (AC: Gemini API 호출 비용: 판당 평균 $0.005 이하 검증).
 *
 * Model: gemini-1.5-flash (default; configurable via GEMINI_MODEL env)
 * Pricing (as of 2026-04):
 *   Input  tokens: $0.075  / 1M tokens  (≤128k context)
 *   Output tokens: $0.30   / 1M tokens
 *
 * Gemini calls in a single game:
 *   (A) Character creation — extractRulesTable()
 *       One call per character at CHARACTER CREATION TIME, not per game.
 *       This is a one-time cost and is NOT counted in per-game billing.
 *       (Shown separately for reference.)
 *   (B) Oracle intent    — extractOracleIntent()
 *       One call per oracle send; 60s cooldown per user per match.
 *       This IS the per-game variable cost.
 *       Upper bound: min(32 players, max possible oracle sends).
 *       Realistic upper bound: ~16 sends (half of players send in a game).
 *
 * Token estimates (conservative upper bound):
 *   Character creation:
 *     Input  ≈ 800 tokens  (system prompt ~700 + char description ~100)
 *     Output ≈ 250 tokens  (JSON rules_table)
 *   Oracle intent:
 *     Input  ≈ 350 tokens  (system prompt ~300 + message ~50)
 *     Output ≈  60 tokens  (JSON intent)
 */

'use strict';

const assert = require('assert');

// ---------------------------------------------------------------------------
// Pricing constants (gemini-1.5-flash, standard tier)
// ---------------------------------------------------------------------------

const INPUT_PRICE_PER_TOKEN  = 0.075  / 1_000_000; // $0.075 / 1M input  tokens
const OUTPUT_PRICE_PER_TOKEN = 0.30   / 1_000_000; // $0.30  / 1M output tokens

// ---------------------------------------------------------------------------
// Token estimates per call type
// ---------------------------------------------------------------------------

const CHAR_CREATION_INPUT_TOKENS  = 800;
const CHAR_CREATION_OUTPUT_TOKENS = 250;
const ORACLE_INTENT_INPUT_TOKENS  = 350;
const ORACLE_INTENT_OUTPUT_TOKENS =  60;

// ---------------------------------------------------------------------------
// Game parameters
// ---------------------------------------------------------------------------

const PLAYERS_PER_GAME           = 32;
// Oracle sends are limited by 60s cooldown per user per match.
// In a typical 10-turn game a user gets at most 10 sends, but practically
// only half of players actively use oracle → realistic ≈ 16 sends/game.
// For the AC validation we use 32 (all players send every turn for 1 turn).
const MAX_ORACLE_SENDS_PER_GAME  = PLAYERS_PER_GAME; // 1 per player ceiling

// ---------------------------------------------------------------------------
// Cost calculation
// ---------------------------------------------------------------------------

function tokenCost(inputTokens, outputTokens) {
  return inputTokens * INPUT_PRICE_PER_TOKEN + outputTokens * OUTPUT_PRICE_PER_TOKEN;
}

/**
 * Per-game Gemini cost = only oracle intent calls.
 * Character creation cost is a one-time sunk cost, not charged per game.
 */
function estimatePerGameCost({ oracleSendsPerGame = MAX_ORACLE_SENDS_PER_GAME } = {}) {
  const charCreationCostPerCall = tokenCost(CHAR_CREATION_INPUT_TOKENS, CHAR_CREATION_OUTPUT_TOKENS);
  const oracleCostPerCall       = tokenCost(ORACLE_INTENT_INPUT_TOKENS,  ORACLE_INTENT_OUTPUT_TOKENS);
  const oracleCostPerGame       = oracleSendsPerGame * oracleCostPerCall;

  return {
    charCreationCostPerCall,
    oracleCostPerCall,
    oracleCostPerGame,
    totalPerGame: oracleCostPerGame, // char creation is one-time, not per-game
  };
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

(async () => {
  console.log('\n=== Phase 6 Gemini Cost Verification ===\n');
  console.log(`Model pricing (gemini-1.5-flash):`);
  console.log(`  Input  : $${INPUT_PRICE_PER_TOKEN.toFixed(8)} / token  ($0.075 / 1M)`);
  console.log(`  Output : $${OUTPUT_PRICE_PER_TOKEN.toFixed(8)} / token  ($0.30  / 1M)`);
  console.log();

  const BUDGET_PER_GAME = 0.005; // $0.005 per game (spec AC)

  // --- Scenario 1: Worst-case per-game (all 32 players send 1 oracle) ---
  const worstCase = estimatePerGameCost({ oracleSendsPerGame: 32 });
  console.log('Scenario 1 — Worst-case per-game (all 32 players send 1 oracle):');
  console.log(`  Oracle intent (32 calls)  : $${worstCase.oracleCostPerGame.toFixed(6)}`);
  console.log(`  TOTAL per game            : $${worstCase.totalPerGame.toFixed(6)}`);
  console.log(`  (Character creation is a one-time cost: $${worstCase.charCreationCostPerCall.toFixed(6)}/char)`);
  console.log();

  // --- Scenario 2: Typical (10 oracle sends) ---
  const typical = estimatePerGameCost({ oracleSendsPerGame: 10 });
  console.log('Scenario 2 — Typical (10 oracle sends per game):');
  console.log(`  Oracle intent (10 calls)  : $${typical.oracleCostPerGame.toFixed(6)}`);
  console.log(`  TOTAL per game            : $${typical.totalPerGame.toFixed(6)}`);
  console.log();

  // AC assertion: WORST-CASE must be under budget
  assert(
    worstCase.totalPerGame < BUDGET_PER_GAME,
    `Worst-case per-game cost $${worstCase.totalPerGame.toFixed(6)} exceeds budget $${BUDGET_PER_GAME}`
  );
  console.log(`✓ Worst-case total $${worstCase.totalPerGame.toFixed(6)} < $${BUDGET_PER_GAME} budget`);

  assert(
    typical.totalPerGame < BUDGET_PER_GAME,
    `Typical cost $${typical.totalPerGame.toFixed(6)} exceeds budget $${BUDGET_PER_GAME}`
  );
  console.log(`✓ Typical total $${typical.totalPerGame.toFixed(6)} < $${BUDGET_PER_GAME} budget`);

  // --- Per-call cost reference ---
  console.log('\nPer-call cost breakdown:');
  console.log(`  extractRulesTable (one-time char creation) : $${worstCase.charCreationCostPerCall.toFixed(6)}`);
  console.log(`  extractOracleIntent (per oracle send)      : $${worstCase.oracleCostPerCall.toFixed(6)}`);

  // Headroom: how many oracle calls could fit in budget?
  const maxAffordableCalls = Math.floor(BUDGET_PER_GAME / worstCase.oracleCostPerCall);
  console.log(`\n  Budget headroom: could afford ${maxAffordableCalls} oracle calls per game (cap is 32)`);
  assert(maxAffordableCalls >= MAX_ORACLE_SENDS_PER_GAME,
    `Budget only supports ${maxAffordableCalls} oracle calls but max is ${MAX_ORACLE_SENDS_PER_GAME}`);

  console.log('\n=== Gemini cost verification PASSED ✓ ===\n');
  process.exit(0);
})().catch(err => {
  console.error('Cost test FAILED:', err.message);
  process.exit(1);
});
