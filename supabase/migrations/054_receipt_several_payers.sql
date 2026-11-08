-- Build 440: several people paid one receipt (e.g. Ber put in ¥10,000 and
-- you ¥1,000 of an ¥11,000 bill).
--
-- receipt_splits.contributed — what that person handed over towards the bill,
-- in the receipt's currency. receipts.paid_by stays the main payer (whoever
-- put in the most); everyone else's share is settled with them:
--   what they owe the main payer = amount (their share) − contributed
-- (negative = the main payer owes them). Single-payer receipts keep every
-- contributed at 0, so nothing changes for them.
--
-- Someone can chip in without sharing the cost, so a share can now be 0 as
-- long as they contributed something.

alter table public.receipt_splits
  add column if not exists contributed numeric(12, 2) not null default 0;

alter table public.receipt_splits
  drop constraint if exists receipt_splits_amount_check;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'receipt_splits_amount_nonneg') then
    alter table public.receipt_splits
      add constraint receipt_splits_amount_nonneg check (amount >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'receipt_splits_contributed_nonneg') then
    alter table public.receipt_splits
      add constraint receipt_splits_contributed_nonneg check (contributed >= 0);
  end if;
  if not exists (select 1 from pg_constraint where conname = 'receipt_splits_share_or_contribution') then
    alter table public.receipt_splits
      add constraint receipt_splits_share_or_contribution check (amount > 0 or contributed > 0);
  end if;
end $$;
