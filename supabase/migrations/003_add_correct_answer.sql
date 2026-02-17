-- ============================================
-- ADD CORRECT_ANSWER TO ROUNDS TABLE
-- ============================================
-- Stores the expected song title for answer validation.
-- For now the host enters it manually.
-- Later this will be auto-populated from the Spotify track name.

ALTER TABLE public.rounds
ADD COLUMN IF NOT EXISTS correct_answer varchar;
