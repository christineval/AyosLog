-- STARTER ONLY: read docs/SECURITY.md and docs/DATABASE.md before production.
-- AyosLog cloud starter database for Supabase Postgres
-- RUN in a dedicated project. RLS policies are a starting point; test permissions thoroughly.
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  timezone text not null default 'Asia/Manila',
  currency char(3) not null default 'PHP',
  created_at timestamptz not null default now()
);

create table public.assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  name text not null check (length(trim(name)) > 0),
  category text not null check (category in ('vehicle','appliance','electronics','home','other')),
  brand text, model text, serial_number text,
  purchase_date date, purchase_price numeric(12,2) check (purchase_price >= 0),
  warranty_expires_on date,
  is_archived boolean not null default false,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index assets_owner_idx on public.assets(owner_id) where deleted_at is null;

create table public.asset_photos (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets(id),
  storage_path text not null,
  mime_type text not null,
  sort_order int not null default 0,
  created_at timestamptz not null default now()
);

create table public.maintenance_plans (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets(id),
  title text not null,
  cadence_unit text not null check (cadence_unit in ('days','weeks','months','years','km','hours','cycles')),
  cadence_value int not null check (cadence_value > 0),
  next_due_on date,
  next_due_usage numeric(14,2),
  active boolean not null default true,
  version bigint not null default 1,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (next_due_on is not null or next_due_usage is not null)
);
create index plans_asset_idx on public.maintenance_plans(asset_id);

create table public.maintenance_events (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets(id),
  plan_id uuid references public.maintenance_plans(id) on delete set null,
  created_by uuid not null references public.profiles(id),
  service_type text not null check (service_type in ('routine','repair','inspection','other')),
  performed_on date not null,
  description text not null default '',
  cost numeric(12,2) not null default 0 check (cost >= 0),
  service_provider text,
  usage_reading numeric(14,2),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index service_asset_idx on public.maintenance_events(asset_id, performed_on desc);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets(id),
  event_id uuid references public.maintenance_events(id) on delete set null,
  kind text not null check (kind in ('receipt','warranty','manual','registration','other')),
  storage_path text not null,
  file_name text not null,
  mime_type text,
  expiry_date date,
  ocr_status text not null default 'not_scanned' check (ocr_status in ('not_scanned','scanned','failed')),
  created_at timestamptz not null default now()
);

create table public.usage_readings (
  id uuid primary key default gen_random_uuid(),
  asset_id uuid not null references public.assets(id),
  reading_type text not null check (reading_type in ('km','hours','cycles')),
  value numeric(14,2) not null check (value >= 0),
  recorded_on date not null,
  created_at timestamptz not null default now()
);

create table public.reminder_preferences (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  plan_id uuid not null references public.maintenance_plans(id),
  lead_days int not null default 7 check (lead_days between 0 and 365),
  enabled boolean not null default true,
  unique(owner_id,plan_id)
);

-- Optional cloud sync feed: populate via server-side trigger/function, NOT mobile clients.
create table public.change_log (
  id bigint generated always as identity primary key,
  owner_id uuid not null references public.profiles(id),
  entity_type text not null,
  entity_id uuid not null,
  action text not null check (action in ('insert','update','delete')),
  version bigint not null,
  occurred_at timestamptz not null default now()
);
create index change_log_owner_cursor_idx on public.change_log(owner_id,id);

-- Restrict each user's cloud data using ownership chains.
alter table public.profiles enable row level security;
alter table public.assets enable row level security;
alter table public.asset_photos enable row level security;
alter table public.maintenance_plans enable row level security;
alter table public.maintenance_events enable row level security;
alter table public.documents enable row level security;
alter table public.usage_readings enable row level security;
alter table public.reminder_preferences enable row level security;
alter table public.change_log enable row level security;

create policy profiles_own on public.profiles for all to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy assets_own on public.assets for all to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy photos_own on public.asset_photos for all to authenticated
  using (exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())))
  with check (exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())));
create policy plans_own on public.maintenance_plans for all to authenticated
  using (exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())))
  with check (exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())));
create policy events_own on public.maintenance_events for all to authenticated
  using (exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())))
  with check (created_by=(select auth.uid()) and exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())));
create policy docs_own on public.documents for all to authenticated
  using (exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())))
  with check (exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())));
create policy readings_own on public.usage_readings for all to authenticated
  using (exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())))
  with check (exists(select 1 from public.assets a where a.id=asset_id and a.owner_id=(select auth.uid())));
create policy reminders_own on public.reminder_preferences for all to authenticated
  using (owner_id=(select auth.uid()) and exists(select 1 from public.maintenance_plans p join public.assets a on a.id=p.asset_id where p.id=plan_id and a.owner_id=(select auth.uid())))
  with check (owner_id=(select auth.uid()) and exists(select 1 from public.maintenance_plans p join public.assets a on a.id=p.asset_id where p.id=plan_id and a.owner_id=(select auth.uid())));
create policy changes_read_own on public.change_log for select to authenticated using (owner_id=(select auth.uid()));

-- Explicitly prevent direct client writes to the change log.
revoke insert, update, delete on public.change_log from anon, authenticated;

-- NOTE before production:
-- 1. Add a trigger/transaction API for atomic server-side versions and change_log rows.
-- 2. Enforce asset_id consistency for plan_id/event_id references in a trusted trigger or service.
-- 3. Enforce immutability of created_by and owner_id after creation where required.
-- 4. Implement private Supabase Storage policies for asset owners: object paths alone are not access control.
-- 5. Set updated_at via server trigger, and protect version increment from client tampering.
-- 6. Create profiles via onboarding code or secure auth-user trigger; users cannot insert records without profile.
