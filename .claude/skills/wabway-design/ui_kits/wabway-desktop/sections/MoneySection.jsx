function MoneySection({ iconBase }) {
  const { BalanceSummaryCard, ReceiptCard, SplitMemberRow, Tabs, Button, Icon } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const receipts = [
    { id: 1, title: 'Ramen dinner', amount: '8,400', paidBy: 'Alex Kim', category: 'Food', splitCount: 4, dateLabel: 'Nov 10' },
    { id: 2, title: 'TeamLab tickets', amount: '12,000', paidBy: 'You', category: 'Activity', splitCount: 4, dateLabel: 'Nov 12' },
    { id: 3, title: 'Convenience store snacks', amount: '1,860', paidBy: 'Josh Park', category: 'Food', splitCount: 3, dateLabel: 'Nov 13' },
  ];
  const [tab, setTab] = React.useState('receipts');
  const [selected, setSelected] = React.useState(receipts[0]);

  return (
    <div style={{ display: 'flex', height: '100%' }}>
      <div style={{ width: 420, borderRight: '1px solid var(--color-border)', display: 'flex', flexDirection: 'column', minHeight: 0 }}>
        <div style={{ padding: '16px 20px 0' }}>
          <BalanceSummaryCard youOwe={[{ name: 'Alex Kim', amount: '3,200' }]} youAreOwed={[{ name: 'Josh Park', amount: '5,000' }, { name: 'Matt Lee', amount: '2,100' }]} />
        </div>
        <div style={{ padding: '16px 20px 0' }}>
          <Tabs tabs={[{ value: 'receipts', label: 'Receipts' }, { value: 'cash', label: 'Cash / ATM' }]} value={tab} onChange={setTab} />
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '14px 20px 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          {receipts.map((r) => <ReceiptCard key={r.id} {...r} iconBase={iconBase} onClick={() => setSelected(r)} />)}
        </div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '28px 36px', maxWidth: 520 }}>
        {selected && (
          <>
            <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>{selected.title}</div>
            <div style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: 'var(--text-3xl)', color: 'var(--color-primary-dark)', marginTop: 6 }}>¥{selected.amount}</div>
            <div style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-secondary)', marginTop: 4 }}>
              Paid by {selected.paidBy} · {selected.category} · {selected.dateLabel}
            </div>
            <div style={{ marginTop: 22 }}>
              <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)', marginBottom: 4 }}>Split with</div>
              <SplitMemberRow name="You" amount="2,100" selected />
              <SplitMemberRow name="Alex Kim" amount="2,100" selected />
              <SplitMemberRow name="Josh Park" amount="2,100" selected />
              <SplitMemberRow name="Matt Lee" amount="2,100" selected={false} />
            </div>
            <div style={{ marginTop: 20 }}>
              <Button variant="ghost" size="sm" icon={<Icon src={I('pencil')} />}>Edit receipt</Button>
            </div>
          </>
        )}
      </div>
    </div>
  );
}
window.MoneySection = MoneySection;
