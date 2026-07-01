function MembersSection({ iconBase }) {
  const { Avatar, Badge, Button, Icon } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const members = [
    { name: 'You', role: 'Owner' },
    { name: 'Alex Kim', role: 'Editor' },
    { name: 'Josh Park', role: 'Editor' },
    { name: 'Matt Lee', role: 'Editor' },
  ];
  return (
    <div style={{ padding: '28px 36px', maxWidth: 640 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 18 }}>
        <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>Members</div>
        <Button size="sm" icon={<Icon src={I('user-plus')} />}>Invite friends</Button>
      </div>
      <div style={{ background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-sm)' }}>
        {members.map((m, i) => (
          <div key={m.name} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 18px', borderBottom: i < members.length - 1 ? '1px solid var(--color-border)' : 'none' }}>
            <Avatar name={m.name} size="md" />
            <span style={{ flex: 1, fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>{m.name}</span>
            <Badge tone={m.role === 'Owner' ? 'primary' : 'neutral'}>{m.role}</Badge>
          </div>
        ))}
      </div>
    </div>
  );
}
window.MembersSection = MembersSection;
