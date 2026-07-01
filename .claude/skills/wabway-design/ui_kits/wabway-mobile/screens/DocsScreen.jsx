function DocsScreen({ iconBase }) {
  const { DocumentTile, IconButton, Icon } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const docs = [
    { title: 'Air Canada flight confirmation', type: 'Flight', dateLabel: 'Nov 8' },
    { title: 'Shinjuku Granbell Hotel', type: 'Hotel', dateLabel: 'Nov 8' },
    { title: 'Shinkansen ticket', type: 'Train', dateLabel: 'Nov 13' },
    { title: 'TeamLab tickets', type: 'Ticket', dateLabel: 'Nov 12' },
    { title: 'Ramen dinner receipt', type: 'Receipt', dateLabel: 'Nov 10' },
    { title: 'Travel insurance form', type: 'Insurance', dateLabel: 'Nov 1' },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--color-bg)' }}>
      <div style={{ padding: '18px 16px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: 'var(--font-sans)', fontSize: 11, color: 'var(--color-text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>PDFs · Tickets · Receipts</div>
          <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>Documents</div>
        </div>
        <IconButton icon={<Icon src={I('upload')} />} label="Upload" variant="solid" />
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '8px 16px 96px' }}>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
          {docs.map((d) => <DocumentTile key={d.title} {...d} iconBase={iconBase} />)}
        </div>
      </div>
    </div>
  );
}
window.DocsScreen = DocsScreen;
