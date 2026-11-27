-- 0006_rooms_settlement.sql: Atomic Escrow Lock & Match Settlement RPC
create or replace function public.settle_online_match(
  p_match_id uuid,
  p_winner_ids uuid[],
  p_participant_stats jsonb
)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_match public.live_matches%rowtype;
  v_prize_each bigint;
  v_uid uuid;
  v_stat jsonb;
  v_xp_gain bigint;
  v_trophy_delta int;
  v_kuti_count int;
begin
  select * into v_match from public.live_matches where id = p_match_id for update;
  if not found or v_match.status = 'finished' then
    return;
  end if;

  if array_length(p_winner_ids, 1) > 0 then
    v_prize_each := v_match.prize_pool_coins / array_length(p_winner_ids, 1);
    foreach v_uid in array p_winner_ids loop
      perform public.apply_wallet_delta(
        v_uid,
        v_prize_each,
        10,
        'match_win',
        p_match_id::text,
        'Online match victory prize'
      );
    end loop;
  end if;

  for v_stat in select * from jsonb_array_elements(p_participant_stats) loop
    v_uid := (v_stat->>'user_id')::uuid;
    v_xp_gain := coalesce((v_stat->>'xp_gain')::bigint, 50);
    v_trophy_delta := coalesce((v_stat->>'trophy_delta')::int, 0);
    v_kuti_count := coalesce((v_stat->>'kuti_count')::int, 0);

    update public.profiles
    set
      xp = xp + v_xp_gain,
      level = public.calculate_level_from_xp(xp + v_xp_gain),
      trophies = greatest(0, trophies + v_trophy_delta),
      league = public.calculate_league_from_trophies(greatest(0, trophies + v_trophy_delta)),
      total_matches = total_matches + 1,
      total_wins = total_wins + case when v_uid = any(p_winner_ids) then 1 else 0 end,
      total_kuti_captures = total_kuti_captures + v_kuti_count,
      updated_at = now()
    where id = v_uid;
  end loop;

  insert into public.match_history (
    match_id, mode, rules_config, participants, winner_ids, prize_pool_coins
  ) values (
    p_match_id, v_match.mode, v_match.rules_config, p_participant_stats, p_winner_ids, v_match.prize_pool_coins
  );

  update public.live_matches
  set status = 'finished', finished_at = now()
  where id = p_match_id;
end;
$$;
