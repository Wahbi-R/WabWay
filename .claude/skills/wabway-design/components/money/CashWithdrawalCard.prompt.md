An ATM withdrawal record — amount, fee, who pulled it out, and (if expanded) the per-person cash distribution beneath it via `CashDistributionRow`-shaped data.

```jsx
<CashWithdrawalCard withdrawnBy="You" amount="50,000" atmFee="220" dateLabel="Nov 10" distributed={[{name:'Alex Kim',amount:'15,000'},{name:'Matt Lee',amount:'15,000'}]} />
```
