-- ============================================
-- SONGRUSH PARTY - SUPABASE INITIAL SCHEMA
-- ============================================

-- UUID Extension
create extension if not exists "uuid-ossp";

-- ============================================
-- ENUMS
-- ============================================

create type party_status as enum (
  'lobby',
  'playing',
  'finished'
);

-- ============================================
-- TABLE: parties
-- ============================================

create table public.parties (
  id uuid primary key default uuid_generate_v4(),
  code varchar(6) not null unique,
  host_id uuid not null,
  status party_status default 'lobby',
  current_round_id uuid,
  created_at timestamp with time zone default now()
);

create index idx_parties_code on public.parties(code);

-- ============================================
-- TABLE: players
-- ============================================

create table public.players (
  id uuid primary key default uuid_generate_v4(),
  party_id uuid references public.parties(id) on delete cascade,
  name varchar(50) not null,
  score integer default 0,
  is_host boolean default false,
  joined_at timestamp with time zone default now()
);

create index idx_players_party on public.players(party_id);

-- ============================================
-- TABLE: rounds
-- ============================================

create table public.rounds (
  id uuid primary key default uuid_generate_v4(),
  party_id uuid references public.parties(id) on delete cascade,
  spotify_track_id varchar not null,
  started_at timestamp with time zone default now(),
  winner_id uuid references public.players(id),
  is_active boolean default true
);

create index idx_rounds_party on public.rounds(party_id);

-- ============================================
-- TABLE: buzzers
-- ============================================

create table public.buzzers (
  id uuid primary key default uuid_generate_v4(),
  round_id uuid references public.rounds(id) on delete cascade,
  player_id uuid references public.players(id) on delete cascade,
  buzzed_at timestamp with time zone default now()
);

create index idx_buzzers_round on public.buzzers(round_id);

-- ============================================
-- UNIQUE CONSTRAINT: FIRST BUZZER ONLY
-- ============================================

create unique index unique_first_buzzer
on public.buzzers(round_id);

-- ============================================
-- HOST MIGRATION FUNCTION
-- ============================================

create or replace function public.assign_new_host(p_party_id uuid)
returns void as $$
declare
  new_host uuid;
begin
  select id into new_host
  from public.players
  where party_id = p_party_id
  order by joined_at asc
  limit 1;

  if new_host is not null then
    update public.players
    set is_host = true
    where id = new_host;

    update public.parties
    set host_id = new_host
    where id = p_party_id;
  end if;
end;
$$ language plpgsql;

-- ============================================
-- ENABLE ROW LEVEL SECURITY
-- ============================================

alter table public.parties enable row level security;
alter table public.players enable row level security;
alter table public.rounds enable row level security;
alter table public.buzzers enable row level security;

-- ============================================
-- RLS POLICIES (OPEN MVP MODE)
-- ============================================

create policy "Allow all for MVP - parties"
on public.parties
for all
using (true)
with check (true);

create policy "Allow all for MVP - players"
on public.players
for all
using (true)
with check (true);

create policy "Allow all for MVP - rounds"
on public.rounds
for all
using (true)
with check (true);

create policy "Allow all for MVP - buzzers"
on public.buzzers
for all
using (true)
with check (true);

-- ============================================
-- REALTIME ENABLE
-- ============================================

alter publication supabase_realtime add table public.parties;
alter publication supabase_realtime add table public.players;
alter publication supabase_realtime add table public.rounds;
alter publication supabase_realtime add table public.buzzers;

-- ============================================
-- DONE
-- ============================================
