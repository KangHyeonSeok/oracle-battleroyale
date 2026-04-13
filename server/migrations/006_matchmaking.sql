-- 006_matchmaking.sql
-- Persistent match queue (mirrors in-memory Matchmaker state for observability/restart)
CREATE TABLE IF NOT EXISTS match_queue (
  id           SERIAL PRIMARY KEY,
  user_id      INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (user_id)
);
