function HomeSection({ iconBase }) {
  const { Icon, BalanceSummaryCard, MemberAvatarRow, Avatar, Badge } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const activity = [
    { who: 'Alex Kim', text: 'added Fushimi Inari Shrine to Spots', time: '2h ago', icon: 'map-pin' },
    { who: 'Josh Park', text: 'commented on Ichiran Ramen', time: '5h ago', icon: 'message-circle' },
    { who: 'You', text: 'added a receipt: Ramen dinner ¥8,400', time: '1d ago', icon: 'receipt' },
    { who: 'Matt Lee', text: 'voted Must-do on TeamLab Borderless', time: '1d ago', icon: 'check' },
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 24, padding: '28px 32px', maxWidth: 920 }}>
      <div>
        <div style={{ fontFamily: 'var(--font-sans)', fontSize: 12, color: 'var(--color-text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.06em' }}>Trip</div>
        <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-3xl)', color: 'var(--color-text-primary)' }}>Japan, November</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 6, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-secondary)' }}>
          <Icon src={I('map-pin')} size={16} color="var(--color-text-tertiary)" />Tokyo → Kyoto · Nov 8–18
        </div>
        <div style={{ marginTop: 14 }}>
          <MemberAvatarRow members={[{ name: 'You' }, { name: 'Alex Kim' }, { name: 'Josh Park' }, { name: 'Matt Lee' }]} max={5} size="md" />
        </div>
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        <div>
          <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)', marginBottom: 10 }}>Balances</div>
          <BalanceSummaryCard youOwe={[{ name: 'Alex Kim', amount: '3,200' }]} youAreOwed={[{ name: 'Josh Park', amount: '5,000' }]} />
        </div>
        <div>
          <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)', marginBottom: 10 }}>Recent activity</div>
          <div style={{ background: 'var(--color-surface)', border: '1px solid var(--color-border)', borderRadius: 'var(--radius-lg)', boxShadow: 'var(--shadow-sm)' }}>
            {activity.map((a, i) => (
              <div key={i} style={{ display: 'flex', gap: 10, padding: '12px 16px', borderBottom: i < activity.length - 1 ? '1px solid var(--color-border)' : 'none' }}>
                <Icon src={I(a.icon)} size={16} color="var(--color-text-tertiary)" />
                <span style={{ flex: 1, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>
                  <strong style={{ color: 'var(--color-text-primary)' }}>{a.who}</strong> {a.text}
                </span>
                <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-xs)', color: 'var(--color-text-tertiary)', flexShrink: 0 }}>{a.time}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
window.HomeSection = HomeSection;
