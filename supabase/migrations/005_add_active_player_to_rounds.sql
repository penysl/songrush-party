-- ============================================
-- MIGRATION 005: Active Player per Round
-- ============================================

-- Track which player is currently guessing in this round
ALTER TABLE public.rounds
  ADD COLUMN IF NOT EXISTS active_player_id uuid REFERENCES public.players(id);

-- Track album cover and artist for the reveal view
ALTER TABLE public.rounds
  ADD COLUMN IF NOT EXISTS album_cover_url text;

ALTER TABLE public.rounds
  ADD COLUMN IF NOT EXISTS artist_name text;
