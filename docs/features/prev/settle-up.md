# Settle Up Flow

## Overview

Displays per-member net balances and suggested payment steps to zero out shared expenses. Users can mark individual settlements as paid; settlements are persisted to Supabase and shared in real-time across all trip members.

## Components

- **`SettleUpPanel`** (`lib/screens/money/settle_up_panel.dart`) — balance overview, "owed to you / you owe" rows, and suggested payment rows. Accepts `existingSettlements` to pre-mark already-paid suggestions.
- **`SettlementService`** (`lib/core/supabase/settlement_service.dart`) — `loadSettlements`, `createSettlement`, `deleteSettlement`.
- **`Settlement`** model (`lib/data/money_data.dart`) — immutable record with `matches(fromId, toId)` helper.
- **`suggestSettlements`** (`lib/data/money_data.dart`) — derives minimal payment steps from `MemberBalance` list.

## Data model

```sql
CREATE TABLE IF NOT EXISTS settlements (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  trip_id        UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
  from_member_id UUID NOT NULL REFERENCES auth.users(id),
  to_member_id   UUID NOT NULL REFERENCES auth.users(id),
  amount         NUMERIC NOT NULL,
  currency       TEXT NOT NULL DEFAULT 'JPY',
  note           TEXT,
  settled_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_by     UUID NOT NULL REFERENCES auth.users(id)
);
```

## Flow

1. `MoneyScreen._loadAll` fetches receipts, withdrawals, and settlements in parallel via `Future.wait`.
2. `calculateBalances` derives net per-member balances; `suggestSettlements` turns those into payment steps.
3. `SettleUpPanel._initSuggestions` cross-references suggestions against `existingSettlements` and sets `isSettled` on any already-persisted pair.
4. Tapping "Mark settled" calls `SettlementService.createSettlement`, triggers `onSettled` callback which silently reloads, and updates Realtime subscribers.
5. Realtime subscription on `settlements` table ensures other members see the update instantly.
