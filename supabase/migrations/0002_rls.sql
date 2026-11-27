-- 0002_rls.sql: Strict Zero-Trust Row-Level Security
alter table public.profiles enable row level security;
alter table public.clubs enable row level security;
alter table public.club_members enable row level security;
alter table public.club_messages enable row level security;

-- Profiles: anyone authenticated can read non-sensitive public columns; user can only update display_name/avatar
create policy "profiles_select_all" on public.profiles
  for select to authenticated using (true);

create policy "profiles_update_safe_fields" on public.profiles
  for update to authenticated
  using (auth.uid() = id and is_banned = false)
  with check (
    auth.uid() = id
    and is_admin = (select is_admin from public.profiles where id = auth.uid())
    and is_banned = (select is_banned from public.profiles where id = auth.uid())
    and xp = (select xp from public.profiles where id = auth.uid())
    and level = (select level from public.profiles where id = auth.uid())
    and trophies = (select trophies from public.profiles where id = auth.uid())
  );

-- Clubs
create policy "clubs_select_all" on public.clubs for select to authenticated using (true);
create policy "club_members_select_all" on public.club_members for select to authenticated using (true);
create policy "club_messages_select_member" on public.club_messages
  for select to authenticated
  using (exists (select 1 from public.club_members m where m.club_id = club_id and m.user_id = auth.uid()));
create policy "club_messages_insert_member" on public.club_messages
  for insert to authenticated
  with check (auth.uid() = user_id and exists (select 1 from public.club_members m where m.club_id = club_id and m.user_id = auth.uid()));
