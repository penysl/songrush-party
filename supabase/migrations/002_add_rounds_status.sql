-- ============================================
-- ADD STATUS COLUMN TO ROUNDS TABLE
-- ============================================
-- The code uses round statuses (playing, buzzer_locked, answered, finished)

ALTER TABLE public.rounds
ADD COLUMN IF NOT EXISTS status varchar DEFAULT 'playing';
