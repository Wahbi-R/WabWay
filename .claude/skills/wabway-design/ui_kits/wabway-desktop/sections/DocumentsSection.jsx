function DocumentsSection({ iconBase }) {
  const { DocumentTile, Button, Icon } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const docs = [
    { title: 'Air Canada flight confirmation', type: 'Flight', dateLabel: 'Nov 8' },
    { title: 'Shinjuku Granbell Hotel', type: 'Hotel', dateLabel: 'Nov 8' },
    { title: 'Shinkansen ticket', type: 'Train', dateLabel: 'Nov 13' },
    { title: 'TeamLab tickets', type: 'Ticket', dateLabel: 'Nov 12' },
    { title: 'Ramen dinner receipt', type: 'Receipt', dateLabel: 'Nov 10' },
    { title: 'Travel insurance form', type: 'Insurance', dateLabel: 'Nov 1' },
    { title: 'Airport parking screenshot', type: 'Screenshot', dateLabel: 'Nov 7' },
  ];
  return (
    <div style={{ padding: '28px 36px' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 20 }}>
        <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>All documents</div>
        <Button size="sm" icon={<Icon src={I('upload')} />}>Upload</Button>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, 168px)', gap: 16 }}>
        {docs.map((d) => <DocumentTile key={d.title} {...d} iconBase={iconBase} />)}
      </div>
    </div>
  );
}
window.DocumentsSection = DocumentsSection;
