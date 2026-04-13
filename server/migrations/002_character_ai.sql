-- 002_character_ai.sql
-- Allow NPCs without a user (user_id nullable)
ALTER TABLE characters ALTER COLUMN user_id DROP NOT NULL;

-- Store Gemini-extracted decision rules as JSONB
ALTER TABLE characters ADD COLUMN IF NOT EXISTS rules_table JSONB;
