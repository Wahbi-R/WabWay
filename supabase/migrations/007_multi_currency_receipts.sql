-- ── 007 Multi-currency receipt settlement ──────────────────────────────────────
-- Adds home_currency to trips and conversion fields to receipts so that
-- every receipt records the locked home-currency equivalent at time of entry.

-- trips: settlement currency (separate from default_currency / trip's local currency)
alter table trips
  add column home_currency text not null default 'CAD';

alter table trips
  add constraint trips_home_currency_fmt
    check (home_currency ~ '^[A-Z]{3}$');

-- receipts: conversion fields
alter table receipts
  add column home_amount         numeric(12,2),
  add column exchange_rate       numeric(16,8),
  add column transaction_fee_pct numeric(5,2) not null default 0;

-- Backfill: existing receipts treat amount as already in home currency
-- (exchange_rate = 1 means no conversion was applied).
-- In-app, these receipts will show a "rate not set" nudge until edited.
update receipts
set home_amount   = amount,
    exchange_rate = 1
where home_amount is null;

-- Enforce not-null now that backfill is done
alter table receipts
  alter column home_amount   set not null,
  alter column exchange_rate set not null;
