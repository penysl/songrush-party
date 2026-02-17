-- Create tables for Songrush Party

-- Parties table
create table public.parties (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  host_id uuid not null, -- Anonymous user ID from client
  status text not null default 'waiting', -- waiting, playing, finished
  current_round_id uuid, -- Reference to current round
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Players table
create table public.players (
  id uuid primary key default gen_random_uuid(),
  party_id uuid not null references public.parties(id) on delete cascade,
  name text not null,
  score int not null default 0,
  is_host boolean not null default false,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Rounds table
create table public.rounds (
  id uuid primary key default gen_random_uuid(),
  party_id uuid not null references public.parties(id) on delete cascade,
  song_id text not null, -- Spotify Track ID
  status text not null default 'playing', -- playing, buzzer_locked, answered, finished
  start_time timestamp with time zone not null default timezone('utc'::text, now()),
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Buzzers table
create table public.buzzers (
  id uuid primary key default gen_random_uuid(),
  round_id uuid not null references public.rounds(id) on delete cascade,
  player_id uuid not null references public.players(id) on delete cascade,
  buzzed_at timestamp with time zone default timezone('utc'::text, now()) not null,
  unique (round_id) -- Ensures only ONE buzzer per round (First insert wins db constraint)
);

-- Enable RLS (Row Level Security) - For MVP open access but structured
alter table public.parties enable row level security;
alter table public.players enable row level security;
alter table public.rounds enable row level security;
alter table public.buzzers enable row level security;

-- Policies (Open for MVP demo, restrict later)
create policy "Allow public access to parties" on public.parties for all using (true) with check (true);
create policy "Allow public access to players" on public.players for all using (true) with check (true);
create policy "Allow public access to rounds" on public.rounds for all using (true) with check (true);
create policy "Allow public access to buzzers" on public.buzzers for all using (true) with check (true);

-- Realtime Setup
begin;
  drop publication if exists supabase_realtime;
  create publication supabase_realtime for table public.parties, public.players, public.rounds, public.buzzers;
commit;
