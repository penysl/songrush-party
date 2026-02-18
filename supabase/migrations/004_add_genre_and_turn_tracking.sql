-- ============================================
-- MIGRATION 004: Genre & Turn-Tracking
-- ============================================

-- Add genre selection to parties (default: pop)
ALTER TABLE public.parties
  ADD COLUMN IF NOT EXISTS genre text DEFAULT 'pop';

-- Track which player's turn it is (index into players ordered by joined_at)
ALTER TABLE public.parties
  ADD COLUMN IF NOT EXISTS current_player_index integer DEFAULT 0;
