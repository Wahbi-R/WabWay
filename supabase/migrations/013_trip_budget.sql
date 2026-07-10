-- Optional trip-level budget in the home currency.
-- NULL means no budget set (progress bar hidden).
alter table trips
  add column if not exists budget numeric(12,2) check (budget > 0);
