# Database integration and migration plan

**Important:** This is a schema design, not an applied migration. Inspect the existing Drift and Supabase schemas and reuse `assets`, `maintenance_plans`, `service_records` columns and ownership strategy. Add migration versions and rollback strategy. All IDs UUID text on device; native UUID in Postgres.

```sql
-- Reference PostgreSQL DDL fragment; integrate into your actual migrations.
create table if not exists public.asset_usage_observations (
  id uuid primary key,
  owner_id uuid not null references auth.users(id),
  asset_id uuid not null references public.assets(id) on delete cascade,
  metric_key text not null,
  numeric_value numeric(16,4) not null,
  canonical_unit text not null,
  observed_at timestamptz not null,
  source text not null check (source in ('manual','imported','sensor')),
  notes text,
  version integer not null default 1,
  created_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint metric_key_nonempty check(length(trim(metric_key))>0)
);
create index if not exists idx_usage_asset_metric_time
  on public.asset_usage_observations(asset_id,metric_key,observed_at desc);

create table if not exists public.asset_condition_observations (
  id uuid primary key,
  owner_id uuid not null references auth.users(id),
  asset_id uuid not null references public.assets(id) on delete cascade,
  condition_key text not null,
  enum_value text not null,
  observed_at timestamptz not null,
  source text not null check (source in ('manual','imported','sensor')),
  notes text,
  version integer not null default 1,
  created_at timestamptz not null default now()
);

create table if not exists public.prediction_results (
  id uuid primary key,
  owner_id uuid not null references auth.users(id),
  asset_id uuid not null references public.assets(id) on delete cascade,
  maintenance_plan_id uuid not null references public.maintenance_plans(id) on delete cascade,
  state text not null,
  due_at timestamptz,
  remaining_usage numeric(16,4),
  usage_unit text,
  reliability text not null,
  explanation jsonb not null default '[]'::jsonb,
  input_snapshot jsonb not null default '{}'::jsonb,
  algorithm_version text not null,
  calculated_at timestamptz not null default now(),
  unique (maintenance_plan_id, algorithm_version)
);
```

**Do not blindly execute** the fragment: the sample `assets` and `maintenance_plans` table IDs/types and ownership may differ in your scaffold. Do not store sensitive ownership via client-controlled owner IDs without policy and FK checks. The schema must include an ownership-consistency mechanism (composite FK, trigger, or secured insert path) ensuring `owner_id` matches `assets.owner_id`; RLS alone should not rely on a forged owner_id.

**RLS policy pattern** (adapt columns and ensure asset ownership by a real JOIN rather than trusting client input):

```sql
alter table public.asset_usage_observations enable row level security;
create policy usage_select_own on public.asset_usage_observations
for select to authenticated using (
  owner_id=auth.uid() and exists (
    select 1 from public.assets a
    where a.id=asset_id and a.owner_id=auth.uid()
  )
);
-- Repeat secure select/insert/update/delete policies for each table using
-- WITH CHECK ownership and consistent related-task ownership.
```

**Drift additions:** `AssetUsageObservations`, `AssetConditionObservations`, `PredictionResults` plus plan extension fields (`intervalUsage`, `usageUnit`, `baselineUsage`, `sourceType`, `sourceReference`, policy version); optional `AssetSubtypes` or subtype string column. Use nullable fields for existing assets and migration backfill. Treat `predictions` as derived caches: offline sync only source observations/plans, or carefully reconcile algorithm versions.

**Data retention/audit:** Version changes, correct/delete reading via tombstone, record actor and UTC timestamps. Support export/deletion. RLS, private buckets, and two-user isolation tests required before production.
