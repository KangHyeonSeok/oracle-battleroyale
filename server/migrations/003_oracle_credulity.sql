-- 003_oracle_credulity.sql
-- Add credulity stat to characters for oracle debuff/lure success checks.
-- credulity 0-100: higher = more susceptible to other players' oracle messages.

ALTER TABLE characters
  ADD COLUMN IF NOT EXISTS credulity INTEGER NOT NULL DEFAULT 50;
