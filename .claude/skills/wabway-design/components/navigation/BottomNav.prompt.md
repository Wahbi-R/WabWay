Fixed 5-item bottom tab bar for mobile: Spots, Plan, Money, Docs, More — matches the product's mobile nav spec exactly (Plan = itinerary/flights/hotels, Money = receipts/cash/balances, Docs = files, More = members/settings/invite).

```jsx
<BottomNav active="spots" onChange={setTab} iconBase="../../" />
```
