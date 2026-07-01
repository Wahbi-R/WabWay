function AddReceiptSheet({ onClose, iconBase }) {
  const { Icon, IconButton, Input, Select, Radio, SplitMemberRow, Button } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const [method, setMethod] = React.useState('equal');
  const members = [
    { name: 'You', amount: '2,100', selected: true },
    { name: 'Alex Kim', amount: '2,100', selected: true },
    { name: 'Josh Park', amount: '2,100', selected: true },
    { name: 'Matt Lee', amount: '2,100', selected: false },
  ];
  return (
    <div style={{ position: 'absolute', inset: 0, background: 'var(--color-overlay)', display: 'flex', alignItems: 'flex-end', zIndex: 40 }} onClick={onClose}>
      <div onClick={(e) => e.stopPropagation()} style={{ width: '100%', maxHeight: '88%', background: 'var(--color-surface)', borderRadius: 'var(--radius-xl) var(--radius-xl) 0 0', boxShadow: 'var(--shadow-lg)', display: 'flex', flexDirection: 'column' }}>
        <div style={{ display: 'flex', alignItems: 'center', padding: '14px 16px', borderBottom: '1px solid var(--color-border)' }}>
          <span style={{ flex: 1, fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-lg)', color: 'var(--color-text-primary)' }}>Add receipt</span>
          <IconButton icon={<Icon src={I('x')} />} label="Close" onClick={onClose} />
        </div>
        <div style={{ overflowY: 'auto', padding: '16px', display: 'flex', flexDirection: 'column', gap: 14 }}>
          <Input label="Title" placeholder="Ramen dinner" />
          <Input label="Amount" type="number" icon={<Icon src={I('banknote')} />} placeholder="8400" />
          <Select label="Category" placeholder="Choose a category" options={[{ value: 'food', label: 'Food' }, { value: 'transport', label: 'Transport' }, { value: 'shopping', label: 'Shopping' }]} />
          <div>
            <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)', marginBottom: 8 }}>Split method</div>
            <div style={{ display: 'flex', gap: 18 }}>
              <Radio label="Equal" checked={method === 'equal'} onChange={() => setMethod('equal')} />
              <Radio label="Custom" checked={method === 'custom'} onChange={() => setMethod('custom')} />
            </div>
          </div>
          <div>
            <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)', marginBottom: 4 }}>Split with</div>
            {members.map((m) => <SplitMemberRow key={m.name} {...m} editable={method === 'custom'} />)}
          </div>
          <Button variant="primary" fullWidth onClick={onClose}>Save receipt</Button>
        </div>
      </div>
    </div>
  );
}
window.AddReceiptSheet = AddReceiptSheet;
