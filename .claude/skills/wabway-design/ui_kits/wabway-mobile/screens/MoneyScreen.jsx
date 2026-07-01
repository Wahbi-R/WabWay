function MoneyScreen({ iconBase, onAddReceipt }) {
  const { BalanceSummaryCard, ReceiptCard, CashWithdrawalCard, Tabs, IconButton, Icon } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const [tab, setTab] = React.useState('receipts');
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--color-bg)' }}>
      <div style={{ padding: '18px 16px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: 'var(--font-sans)', fontSize: 11, color: 'var(--color-text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Receipts · Cash · Balances</div>
          <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>Money</div>
        </div>
        <IconButton icon={<Icon src={I('plus')} />} label="Add" variant="solid" onClick={onAddReceipt} />
      </div>
      <div style={{ padding: '0 16px 12px' }}>
        <BalanceSummaryCard youOwe={[{ name: 'Alex Kim', amount: '3,200' }]} youAreOwed={[{ name: 'Josh Park', amount: '5,000' }, { name: 'Matt Lee', amount: '2,100' }]} />
      </div>
      <div style={{ padding: '0 16px' }}>
        <Tabs tabs={[{ value: 'receipts', label: 'Receipts' }, { value: 'cash', label: 'Cash / ATM' }]} value={tab} onChange={setTab} />
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '14px 16px 96px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {tab === 'receipts' ? (
          <>
            <ReceiptCard title="Ramen dinner" amount="8,400" paidBy="Alex Kim" category="Food" splitCount={4} dateLabel="Nov 10" />
            <ReceiptCard title="TeamLab tickets" amount="12,000" paidBy="You" category="Activity" splitCount={4} dateLabel="Nov 12" />
            <ReceiptCard title="Convenience store snacks" amount="1,860" paidBy="Josh Park" category="Food" splitCount={3} dateLabel="Nov 13" />
          </>
        ) : (
          <CashWithdrawalCard withdrawnBy="You" amount="50,000" atmFee="220" dateLabel="Nov 10" distributed={[{ name: 'Alex Kim', amount: '15,000' }, { name: 'Matt Lee', amount: '15,000' }, { name: 'Josh Park', amount: '10,000' }]} />
        )}
      </div>
    </div>
  );
}
window.MoneyScreen = MoneyScreen;
