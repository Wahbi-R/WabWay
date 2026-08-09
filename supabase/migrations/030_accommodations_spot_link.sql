alter table accommodations
  add column if not exists spot_id uuid references spots(id) on delete set null;
