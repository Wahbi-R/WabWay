-- A home-currency amount typed in on a receipt (what the card actually
-- charged) rather than worked out from a rate. Settle Up settles those
-- receipts' shares in the trip's home currency.
alter table public.receipts
  add column if not exists home_amount_set boolean not null default false;
