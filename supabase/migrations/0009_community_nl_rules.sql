-- 0009_community_nl_rules.sql: User Natural-Language Rules -> Auto-Compiled & Shared Globally

create table if not exists public.community_nl_rules (
  id uuid primary key default gen_random_uuid(),
  rule_code text unique not null,
  creator_id uuid references public.profiles(id) on delete set null,
  creator_name text not null default 'Desi Player',
  title text not null,
  natural_instruction text not null,
  trigger_type text not null,
  condition_type text not null,
  condition_value int,
  action_type text not null,
  is_approved boolean not null default true,
  usage_count int not null default 1,
  created_at timestamptz not null default now()
);

alter table public.community_nl_rules enable row level security;

drop policy if exists "Anyone can read approved community rules" on public.community_nl_rules;
create policy "Anyone can read approved community rules"
  on public.community_nl_rules for select
  using (is_approved = true);

drop policy if exists "Anyone can publish natural language rules" on public.community_nl_rules;
create policy "Anyone can publish natural language rules"
  on public.community_nl_rules for insert
  with check (true);
