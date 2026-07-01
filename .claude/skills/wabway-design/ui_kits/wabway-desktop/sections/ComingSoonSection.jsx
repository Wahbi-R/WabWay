function ComingSoonSection({ iconBase, label }) {
  const { EmptyState, Icon } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  return (
    <div style={{ padding: '60px 36px' }}>
      <EmptyState icon={<Icon src={I('folder')} />} title={label + ' isn\u2019t mocked up yet'} description="This design system covers Home, Spots, Plan, Money, Documents, and Members in depth — the rest follow the same patterns." />
    </div>
  );
}
window.ComingSoonSection = ComingSoonSection;
