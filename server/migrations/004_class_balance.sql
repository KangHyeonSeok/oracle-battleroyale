-- Migration 004: Class Balance Stats & Combat Formula
-- Adds max_hp column to characters table for per-class HP tracking

-- max_hp 컬럼 추가
ALTER TABLE characters ADD COLUMN IF NOT EXISTS max_hp INTEGER;

-- 기존 행 max_hp = hp 으로 초기화
UPDATE characters SET max_hp = hp WHERE max_hp IS NULL;

-- max_hp NOT NULL 제약 적용 (초기화 후)
ALTER TABLE characters ALTER COLUMN max_hp SET NOT NULL;
ALTER TABLE characters ALTER COLUMN max_hp SET DEFAULT 100;
