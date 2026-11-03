-- Reference-only: not applied by the local app. Back up before applying.
-- Existing ownership and RLS policies are unchanged. No sync is implemented.
begin;
alter table public.assets add column if not exists legacy_category text;
alter table public.assets drop constraint if exists assets_category_check;
update public.assets set legacy_category = category
where category not in ('vehicle','air_conditioner','refrigerator','laptop',
                      'water_filter','washing_machine','custom');
-- Cloud v1 has no subtype evidence. Broad categories require owner selection.
update public.assets set category = case
  when category in ('vehicle','air_conditioner','refrigerator','laptop',
                    'water_filter','washing_machine','custom') then category
  when category = 'car' then 'vehicle'
  else 'custom' end;
alter table public.assets add constraint assets_category_check check (
  category in ('vehicle','air_conditioner','refrigerator','laptop',
               'water_filter','washing_machine','custom'));
commit;
