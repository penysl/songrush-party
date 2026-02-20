-- ============================================
-- MIGRATION 006: Playlist System
-- ============================================
-- Replaces genre-based track selection with
-- curated and user-imported Spotify playlists.

ALTER TABLE public.parties
  ADD COLUMN IF NOT EXISTS playlist_id text,
  ADD COLUMN IF NOT EXISTS playlist_name text,
  ADD COLUMN IF NOT EXISTS used_track_ids jsonb DEFAULT '[]'::jsonb;
