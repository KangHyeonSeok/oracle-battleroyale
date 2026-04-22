-- Leaderboard: per-player match statistics cache
-- Updated by turn-scheduler on match end and oracle/routes on oracle send

CREATE TABLE IF NOT EXISTS player_stats (
  account_id   INTEGER PRIMARY KEY REFERENCES users(id),
  total_matches INTEGER NOT NULL DEFAULT 0,
  total_wins    INTEGER NOT NULL DEFAULT 0,
  oracle_sent   INTEGER NOT NULL DEFAULT 0,
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);
