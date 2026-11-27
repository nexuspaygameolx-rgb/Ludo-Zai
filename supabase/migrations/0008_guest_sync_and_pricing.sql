-- 0008_guest_sync_and_pricing.sql: Exact 100 PKR = 1000 Coins, 100 PKR = 100 Gems, 30% Sell Fee, Gems->Coins & Guest Merge RPC

update public.app_remote_config
set cashmaal_public_config = '{
  "enabled": true,
  "auto_payout_enabled": true,
  "coins_buy_rate_pkr_per_1000": 100.0,
  "gems_buy_rate_pkr_per_100": 100.0,
  "gems_to_coins_ratio": 10,
  "sell_fee_percent": 30,
  "coins_sell_net_pkr_per_1000": 70.0,
  "gems_sell_net_pkr_per_100": 70.0,
  "min_sell_coins": 1000,
  "min_sell_gems": 100
}'::jsonb,
updated_at = now()
where id = 1;

-- Exchange Gems -> Coins (100 PKR = 100 Gems, 100 PKR = 1000 Coins => 1 Gem = 10 Coins)
create or replace function public.exchange_gems_to_coins(
  p_user_id uuid,
  p_gems_to_spend bigint
)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_coins_gained bigint;
begin
  if p_gems_to_spend <= 0 then
    raise exception 'Gems amount must be positive';
  end if;
  v_coins_gained := p_gems_to_spend * 10;

  perform public.apply_wallet_delta(
    p_user_id,
    v_coins_gained,
    -p_gems_to_spend,
    'gems_to_coins_exchange',
    null,
    format('Converted %s Gems into %s Coins', p_gems_to_spend, v_coins_gained)
  );

  return v_coins_gained;
end;
$$;

-- One-time merge of local device guest progress when user signs in with Gmail
create or replace function public.merge_guest_progress_once(
  p_user_id uuid,
  p_guest_xp bigint,
  p_guest_trophies int,
  p_guest_matches int,
  p_guest_wins int,
  p_guest_kuti int
)
returns void language plpgsql security definer set search_path = public as $$
begin
  update public.profiles
  set
    xp = xp + greatest(0, p_guest_xp),
    level = public.calculate_level_from_xp(xp + greatest(0, p_guest_xp)),
    trophies = trophies + greatest(0, p_guest_trophies),
    league = public.calculate_league_from_trophies(trophies + greatest(0, p_guest_trophies)),
    total_matches = total_matches + greatest(0, p_guest_matches),
    total_wins = total_wins + greatest(0, p_guest_wins),
    total_kuti_captures = total_kuti_captures + greatest(0, p_guest_kuti),
    updated_at = now()
  where id = p_user_id;
end;
$$;
