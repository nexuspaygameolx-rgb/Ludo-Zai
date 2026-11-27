-- 0005_live_matches.sql: Server-Authoritative Live Match State & Anti-Cheat Strikes
create table if not exists public.live_matches (
  id uuid primary key default gen_random_uuid(),
  room_code text unique not null,
  mode text not null check (mode in ('online_1v1', 'online_4p', 'team_2v2', 'private_custom')),
  entry_coins bigint not null default 0,
  prize_pool_coins bigint not null default 0,
  rules_config jsonb not null,
  status text not null default 'waiting' check (status in ('waiting', 'active', 'finished', 'cancelled')),
  active_seat_index int not null default 0,
  active_dice jsonb,
  turn_deadline timestamptz,
  players_state jsonb not null default '[]'::jsonb,
  winner_color text,
  created_by uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  finished_at timestamptz
);

create table if not exists public.anticheat_strikes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  match_id uuid references public.live_matches(id) on delete set null,
  reason text not null,
  created_at timestamptz not null default now()
);

alter table public.live_matches enable row level security;
create policy "live_matches_select_authenticated" on public.live_matches for select to authenticated using (true);
