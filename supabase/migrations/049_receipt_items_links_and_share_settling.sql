-- Build 419: itemized receipts, Receipts links, and per-share settling.
-- (049 — the live DB already has an unrelated 048_ai_access_tokens.)
--
-- 1. receipts.items         — the itemized bill (items, tax/tip/discount and
--                              who had what), so editing keeps the breakdown.
-- 2. receipts.split_link_*  — the receipts.wabble.ca split published from this
--                              receipt (id, member order, last-synced hash).
-- 3. Shares are the one source of truth for "who owes whom": a share is either
--    open or settled. Settle Up marks every open share between two people as
--    settled and logs one settlements row (settlement_id) so it can be undone.
-- 4. Fix: splits saved by the app in home currency are converted to the
--    receipt's own currency (what balances and the detail screen assume).
-- 5. Fix: receipt_splits had no DELETE policy, so editing a receipt could not
--    replace its splits; and a receipt could only be inserted with yourself as
--    the payer even though the form has a "Paid by" picker.

-- ── 1 + 2. receipts columns ──────────────────────────────────────────────────
alter table public.receipts
  add column if not exists items             jsonb,
  add column if not exists split_link_id     text,
  add column if not exists split_link_members jsonb,
  add column if not exists split_link_hash   text,
  add column if not exists created_by        uuid references public.profiles(id) default auth.uid();

update public.receipts set created_by = paid_by where created_by is null;

-- ── 3. per-share settling ────────────────────────────────────────────────────
alter table public.receipt_splits
  add column if not exists settlement_id uuid references public.settlements(id) on delete set null;

alter table public.cash_distributions
  add column if not exists is_settled    boolean     not null default false,
  add column if not exists settled_at    timestamptz,
  add column if not exists settlement_id uuid references public.settlements(id) on delete set null;

-- Old settlements cleared "everything between these two people" — mark the
-- shares that existed at the time as settled by them (oldest settlement first).
do $$
declare s record;
begin
  for s in select * from public.settlements order by settled_at loop
    update public.receipt_splits rs
       set is_settled = true, settled_at = s.settled_at, settlement_id = s.id
      from public.receipts r
     where rs.receipt_id = r.id
       and r.trip_id = s.trip_id
       and r.currency = s.currency
       and r.created_at <= s.settled_at
       and not rs.is_settled
       and ((r.paid_by = s.to_member_id   and rs.user_id = s.from_member_id)
         or (r.paid_by = s.from_member_id and rs.user_id = s.to_member_id));

    update public.cash_distributions d
       set is_settled = true, settled_at = s.settled_at, settlement_id = s.id
      from public.cash_withdrawals w
     where d.withdrawal_id = w.id
       and w.trip_id = s.trip_id
       and w.currency = s.currency
       and w.created_at <= s.settled_at
       and not d.is_settled
       and ((w.withdrawn_by = s.to_member_id   and d.user_id = s.from_member_id)
         or (w.withdrawn_by = s.from_member_id and d.user_id = s.to_member_id));
  end loop;
end $$;

-- ── 4. home-currency splits → receipt currency ───────────────────────────────
with t as (
  select r.id, r.amount, r.home_amount, sum(rs.amount) as total
    from public.receipts r
    join public.receipt_splits rs on rs.receipt_id = r.id
   where r.home_amount > 0 and abs(r.amount - r.home_amount) > 0.01
   group by r.id, r.amount, r.home_amount
)
update public.receipt_splits rs
   set amount = greatest(0.01, round(rs.amount * t.amount / t.home_amount, 2))
  from t
 where rs.receipt_id = t.id
   and abs(t.total - t.home_amount) < abs(t.total - t.amount);

-- ── 5. policies ──────────────────────────────────────────────────────────────
-- New DELETE policies (guarded so the file can be re-run); existing receipts
-- policies are changed in place with ALTER POLICY.
do $$
begin
  if not exists (select 1 from pg_policies where tablename = 'receipt_splits'
                  and policyname = 'receipt_splits: payer or owner can delete') then
    create policy "receipt_splits: payer or owner can delete"
      on public.receipt_splits for delete
      using (exists (
        select 1 from public.receipts r
         where r.id = receipt_splits.receipt_id
           and (r.paid_by = auth.uid() or r.created_by = auth.uid() or private.is_trip_owner(r.trip_id))
      ));
  end if;
  if not exists (select 1 from pg_policies where tablename = 'cash_distributions'
                  and policyname = 'cash_distributions: members can delete') then
    create policy "cash_distributions: members can delete"
      on public.cash_distributions for delete
      using (private.is_trip_member(private.withdrawal_trip_id(withdrawal_id)));
  end if;
end $$;

-- Any member can log a receipt paid by any other member of the trip.
alter policy "receipts: members can insert" on public.receipts
  with check (
    private.is_trip_member(trip_id)
    and exists (select 1 from public.trip_members tm
                 where tm.trip_id = receipts.trip_id and tm.user_id = receipts.paid_by)
  );

alter policy "receipts: payer or owner can update" on public.receipts
  using     (paid_by = auth.uid() or created_by = auth.uid() or private.is_trip_owner(trip_id))
  with check (private.is_trip_member(trip_id));

alter policy "receipts: payer or owner can delete" on public.receipts
  using (paid_by = auth.uid() or created_by = auth.uid() or private.is_trip_owner(trip_id));

-- Any trip member may publish / refresh a receipt's Receipts link (the
-- receipts UPDATE policy is payer/creator/owner only).
create or replace function public.set_receipt_split_link(
  p_receipt_id uuid,
  p_link_id    text,
  p_members    jsonb,
  p_hash       text
) returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if not private.is_trip_member(private.receipt_trip_id(p_receipt_id)) then
    raise exception 'not a trip member' using errcode = '42501';
  end if;
  update public.receipts
     set split_link_id      = p_link_id,
         split_link_members = coalesce(p_members, split_link_members),
         split_link_hash    = p_hash
   where id = p_receipt_id;
end;
$$;

revoke execute on function public.set_receipt_split_link(uuid, text, jsonb, text) from public, anon;
grant  execute on function public.set_receipt_split_link(uuid, text, jsonb, text) to authenticated;
