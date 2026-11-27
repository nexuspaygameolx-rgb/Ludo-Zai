-- 0001_schema.sql: Core user profiles, XP levels, trophies, leagues, and clubs
create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null,
  display_name text not null,
  avatar_url text,
  avatar_frame_id text default 'frame_default',
  xp bigint not null default 0,
  level int not null default 1,
  trophies int not null default 0,
  league text not null default 'Bronze',
  total_matches int not null default 0,
  total_wins int not null default 0,
  total_kuti_captures int not null default 0,
  is_vip boolean not null default false,
  vip_expires_at timestamptz,
  is_admin boolean not null default false,
  is_banned boolean not null default false,
  ban_reason text,
  device_fingerprint text,
  last_ip inet,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.clubs (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  tag text unique not null,
  badge_icon text not null default 'shield_gold',
  owner_id uuid not null references public.profiles(id) on delete cascade,
  weekly_trophies bigint not null default 0,
  member_count int not null default 1,
  max_members int not null default 50,
  is_public boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.club_members (
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'co_leader', 'member')),
  weekly_contribution int not null default 0,
  joined_at timestamptz not null default now(),
  primary key (club_id, user_id)
);

create table if not exists public.club_messages (
  id uuid primary key default gen_random_uuid(),
  club_id uuid not null references public.clubs(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);
