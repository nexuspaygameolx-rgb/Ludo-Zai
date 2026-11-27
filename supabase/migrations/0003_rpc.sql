-- 0003_rpc.sql: Atomic SECURITY DEFINER RPCs for XP, Levels, Trophies & Wallets
create or replace function public.calculate_level_from_xp(p_xp bigint)
returns int language sql immutable as $$
  select greatest(1, floor(sqrt(greatest(0, p_xp) / 100.0))::int + 1);
$$;

create or replace function public.calculate_league_from_trophies(p_trophies int)
returns text language sql immutable as $$
  select case
    when p_trophies >= 5000 then 'Legend'
    when p_trophies >= 3000 then 'Diamond'
    when p_trophies >= 1500 then 'Gold'
    when p_trophies >= 500 then 'Silver'
    else 'Bronze'
  end;
$$;

create or replace function public.handle_new_user_setup()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    'player_' || substr(replace(new.id::text, '-', ''), 1, 8),
    coalesce(new.raw_user_meta_data->>'display_name', 'Desi Player')
  )
  on conflict (id) do nothing;

  insert into public.wallets (user_id, coins, gems)
  values (new.id, 2500, 25)
  on conflict (user_id) do nothing;

  insert into public.user_inventory (user_id, item_type, item_id, level, shards, is_equipped)
  values
    (new.id, 'dice', 'dice_classic_ivory', 1, 0, true),
    (new.id, 'board', 'board_truck_art_3d', 1, 0, true),
    (new.id, 'token', 'token_royal_crown', 1, 0, true)
  on conflict do nothing;

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user_setup();
