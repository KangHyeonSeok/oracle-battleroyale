-- 005_oracle_points.sql
-- Oracle Points transaction log table
-- Note: point balance lives in users.constellation_points (already DEFAULT 100 per 001_initial_schema.sql)

CREATE TABLE IF NOT EXISTS point_transactions (
  id         SERIAL PRIMARY KEY,
  account_id INTEGER NOT NULL REFERENCES users(id),
  match_id   INTEGER REFERENCES matches(id),
  delta      INTEGER NOT NULL,           -- positive: gained, negative: spent
  reason     VARCHAR(50) NOT NULL,       -- 'oracle_send' | 'win_bonus' | 'top25_bonus' | 'completion_bonus' | 'daily_login' | 'initial'
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS point_transactions_account_id_idx ON point_transactions(account_id);
