-- 0004_seed_config.sql: Dynamic Remote Config controlled live from Admin Panel
create table if not exists public.app_remote_config (
  id int primary key default 1 check (id = 1),
  maintenance_mode boolean not null default false,
  maintenance_message text not null default 'Server upgrade in progress. Back shortly!',
  min_supported_build int not null default 1,
  force_update_apk_url text not null default '',
  adsterra_config jsonb not null default '{
    "enabled": true,
    "direct_link_url": "",
    "rewarded_ad_url": "",
    "banner_zone_id": "",
    "interstitial_zone_id": "",
    "daily_rewarded_cap": 10,
    "cooldown_seconds": 45,
    "reward_coins": 500,
    "reward_gems": 5,
    "chest_skip_minutes": 30
  }'::jsonb,
  cashmaal_public_config jsonb not null default '{
    "enabled": true,
    "auto_payout_enabled": true,
    "coins_buy_rate_pkr_per_1000": 15.0,
    "coins_sell_rate_pkr_per_1000": 11.0,
    "gems_buy_rate_pkr_per_10": 25.0,
    "gems_sell_rate_pkr_per_10": 18.0,
    "trophies_sell_rate_pkr_per_100": 20.0,
    "min_sell_coins": 10000,
    "min_sell_gems": 100,
    "min_sell_trophies": 500
  }'::jsonb,
  default_rules jsonb not null default '{
    "kutiMode": true,
    "autoSingleDiceOnLastToken": true,
    "kutiKillScope": "sweepKill",
    "kutiBypassSafeZones": true,
    "kutiVulnerable": true,
    "jotaEnabled": true,
    "tiggiRule": "delayedRemainingKill",
    "katiBaghairGharBand": false,
    "tripleSixForfeit": true,
    "openRule": "sixOnly",
    "safeZoneCount": 8,
    "winningTokensCount": 4,
    "teamMode2v2": false
  }'::jsonb,
  gemini_ai_global_enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

insert into public.app_remote_config (id) values (1) on conflict (id) do nothing;

alter table public.app_remote_config enable row level security;
create policy "remote_config_read_all" on public.app_remote_config for select using (true);
create policy "remote_config_admin_update" on public.app_remote_config
  for update to authenticated
  using (exists (select 1 from public.profiles where id = auth.uid() and is_admin = true));
