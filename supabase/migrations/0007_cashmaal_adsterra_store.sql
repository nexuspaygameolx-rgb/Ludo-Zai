-- 0007_cashmaal_adsterra_store.sql: Wallets, Immutable Ledger, CashMaal Buy/Sell, Adsterra, 3D Dices, Custom Rules, Match History

create table if not exists public.wallets (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  coins bigint not null default 2500 check (coins >= 0),
  gems bigint not null default 25 check (gems >= 0),
  escrow_locked_coins bigint not null default 0 check (escrow_locked_coins >= 0),
  escrow_locked_gems bigint not null default 0 check (escrow_locked_gems >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  coins_delta bigint not null default 0,
  gems_delta bigint not null default 0,
  trophies_delta int not null default 0,
  reason text not null,
  reference_id text,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.cashmaal_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  order_type text not null check (order_type in ('buy', 'sell')),
  asset_type text not null check (asset_type in ('coins', 'gems', 'trophies')),
  asset_amount bigint not null check (asset_amount > 0),
  pkr_amount numeric(12, 2) not null check (pkr_amount > 0),
  rate_applied numeric(12, 4) not null,
  cashmaal_account text,
  gateway_txn_id text unique,
  status text not null default 'pending' check (status in ('pending', 'processing', 'completed', 'failed', 'rejected')),
  audit_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.adsterra_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  reward_type text not null check (reward_type in ('coins', 'gems', 'chest_skip', 'double_win', 'dice_shard')),
  status text not null default 'issued' check (status in ('issued', 'claimed', 'expired')),
  issued_at timestamptz not null default now(),
  claimed_at timestamptz
);

create table if not exists public.daily_free_claims (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  last_four_hour_claim timestamptz,
  login_streak_day int not null default 0,
  last_streak_claim_date date,
  spins_used_today int not null default 0,
  last_spin_date date
);

create table if not exists public.dice_catalog (
  id text primary key,
  name text not null,
  rarity text not null check (rarity in ('common', 'rare', 'epic', 'legendary')),
  shards_per_level int[] not null default '{10,25,50,100}',
  gem_cost_per_level int[] not null default '{20,50,120,250}',
  kuti_vfx_style text not null default 'flame_burst',
  is_active boolean not null default true
);

insert into public.dice_catalog (id, name, rarity, shards_per_level, gem_cost_per_level, kuti_vfx_style) values
  ('dice_classic_ivory', 'Classic Ivory 3D', 'common', '{5,15,30,60}', '{10,25,60,120}', 'spark_ring'),
  ('dice_truck_art', 'Pakistani Truck Art 3D', 'rare', '{10,25,50,100}', '{20,50,100,200}', 'dhol_fireworks'),
  ('dice_mughal_emerald', 'Shahi Mughal Emerald', 'epic', '{15,35,75,150}', '{40,90,180,350}', 'royal_emerald_nova'),
  ('dice_kuti_inferno', 'Ulti Kuti Dragon Fire', 'legendary', '{20,50,100,200}', '{60,140,280,500}', 'inferno_crown_smash')
on conflict (id) do nothing;

create table if not exists public.user_inventory (
  user_id uuid not null references public.profiles(id) on delete cascade,
  item_type text not null check (item_type in ('dice', 'board', 'token', 'frame')),
  item_id text not null,
  level int not null default 1 check (level between 1 and 5),
  shards int not null default 0 check (shards >= 0),
  is_equipped boolean not null default false,
  acquired_at timestamptz not null default now(),
  primary key (user_id, item_type, item_id)
);

create table if not exists public.user_custom_rules (
  id uuid primary key default gen_random_uuid(),
  creator_id uuid not null references public.profiles(id) on delete cascade,
  share_code text unique not null,
  title text not null,
  description text,
  rules_json jsonb not null,
  is_community_approved boolean not null default false,
  plays_count bigint not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.match_history (
  id uuid primary key default gen_random_uuid(),
  match_id uuid,
  mode text not null,
  rules_config jsonb not null,
  participants jsonb not null,
  winner_ids uuid[] not null,
  prize_pool_coins bigint not null default 0,
  played_at timestamptz not null default now()
);

-- RLS Policies
alter table public.wallets enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.cashmaal_orders enable row level security;
alter table public.user_inventory enable row level security;
alter table public.user_custom_rules enable row level security;
alter table public.match_history enable row level security;

create policy "wallets_select_own" on public.wallets for select to authenticated using (auth.uid() = user_id);
create policy "ledger_select_own" on public.wallet_ledger for select to authenticated using (auth.uid() = user_id);
create policy "cashmaal_orders_select_own" on public.cashmaal_orders for select to authenticated using (auth.uid() = user_id);
create policy "inventory_select_own" on public.user_inventory for select to authenticated using (auth.uid() = user_id);
create policy "custom_rules_select_all" on public.user_custom_rules for select to authenticated using (true);
create policy "custom_rules_insert_own" on public.user_custom_rules for insert to authenticated with check (auth.uid() = creator_id);
create policy "match_history_select_all" on public.match_history for select to authenticated using (true);

-- Atomic Wallet Mutation Function
create or replace function public.apply_wallet_delta(
  p_user_id uuid,
  p_coins_delta bigint,
  p_gems_delta bigint,
  p_reason text,
  p_reference_id text default null,
  p_note text default null
)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.wallets
  set
    coins = coins + p_coins_delta,
    gems = gems + p_gems_delta,
    updated_at = now()
  where user_id = p_user_id
    and coins + p_coins_delta >= 0
    and gems + p_gems_delta >= 0;

  if not found then
    raise exception 'Insufficient wallet balance or wallet not found';
  end if;

  insert into public.wallet_ledger (user_id, coins_delta, gems_delta, reason, reference_id, note)
  values (p_user_id, p_coins_delta, p_gems_delta, p_reason, p_reference_id, p_note);
end;
$$;
