-- 001_initial_schema.sql
-- Users (Google OAuth)
CREATE TABLE IF NOT EXISTS users (
  id                   SERIAL PRIMARY KEY,
  google_id            TEXT NOT NULL UNIQUE,
  email                TEXT NOT NULL,
  display_name         TEXT NOT NULL,
  avatar_url           TEXT,
  constellation_points INTEGER NOT NULL DEFAULT 100,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Characters (one or more per user)
CREATE TABLE IF NOT EXISTS characters (
  id          SERIAL PRIMARY KEY,
  user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  class       TEXT NOT NULL DEFAULT 'warrior',   -- warrior | mage | archer | etc.
  hp          INTEGER NOT NULL DEFAULT 100,
  attack      INTEGER NOT NULL DEFAULT 10,
  defense     INTEGER NOT NULL DEFAULT 5,
  speed       NUMERIC(5,2) NOT NULL DEFAULT 1.0,
  ai_persona  TEXT,                               -- LLM system prompt fragment
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Matches
CREATE TABLE IF NOT EXISTS matches (
  id           SERIAL PRIMARY KEY,
  status       TEXT NOT NULL DEFAULT 'waiting',   -- waiting | in_progress | finished
  max_players  INTEGER NOT NULL DEFAULT 32,
  started_at   TIMESTAMPTZ,
  finished_at  TIMESTAMPTZ,
  winner_id    INTEGER REFERENCES characters(id),
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Match participants
CREATE TABLE IF NOT EXISTS match_participants (
  id           SERIAL PRIMARY KEY,
  match_id     INTEGER NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  character_id INTEGER NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
  is_npc       BOOLEAN NOT NULL DEFAULT FALSE,
  placement    INTEGER,                            -- final rank (1 = winner)
  eliminated_at TIMESTAMPTZ,
  UNIQUE (match_id, character_id)
);

-- Oracle (신탁) invocations log
CREATE TABLE IF NOT EXISTS oracle_invocations (
  id           SERIAL PRIMARY KEY,
  match_id     INTEGER NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  user_id      INTEGER NOT NULL REFERENCES users(id),
  character_id INTEGER NOT NULL REFERENCES characters(id),
  prompt       TEXT NOT NULL,
  response     TEXT,
  points_spent INTEGER NOT NULL DEFAULT 5,
  invoked_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Match history view (convenience)
CREATE OR REPLACE VIEW match_history AS
SELECT
  m.id           AS match_id,
  m.status,
  m.started_at,
  m.finished_at,
  c.id           AS character_id,
  c.name         AS character_name,
  u.id           AS user_id,
  u.display_name AS player_name,
  mp.placement,
  mp.is_npc,
  mp.eliminated_at
FROM match_participants mp
JOIN matches    m ON m.id = mp.match_id
JOIN characters c ON c.id = mp.character_id
LEFT JOIN users u ON u.id = c.user_id;
