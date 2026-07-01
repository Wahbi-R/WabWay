function MoreScreen({ iconBase }) {
  const { Avatar, MemberAvatarRow, Icon, Switch } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const [notifs, setNotifs] = React.useState(true);
  const members = [{ name: 'You' }, { name: 'Alex Kim' }, { name: 'Josh Park' }, { name: 'Matt Lee' }];

  const Row = ({ icon, label, trailing }) => (
    <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '14px 16px', background: 'var(--color-surface)' }}>
      <Icon src={I(icon)} size={20} color="var(--color-text-secondary)" />
      <span style={{ flex: 1, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>{label}</span>
      {trailing}
    </div>
  );

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--color-bg)' }}>
      <div style={{ padding: '18px 16px 10px' }}>
        <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>More</div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 16px 96px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        <div style={{ background: 'var(--color-surface)', borderRadius: 'var(--radius-lg)', border: '1px solid var(--color-border)', padding: 'var(--space-4)', display: 'flex', alignItems: 'center', gap: 12 }}>
          <MemberAvatarRow members={members} max={4} />
          <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>4 members</span>
        </div>
        <div style={{ borderRadius: 'var(--radius-lg)', border: '1px solid var(--color-border)', overflow: 'hidden', display: 'flex', flexDirection: 'column' }}>
          <Row icon="users" label="Members" />
          <div style={{ height: 1, background: 'var(--color-border)' }} />
          <Row icon="link-2" label="Invite friends" />
          <div style={{ height: 1, background: 'var(--color-border)' }} />
          <Row icon="bell" label="Push notifications" trailing={<Switch checked={notifs} onChange={setNotifs} />} />
          <div style={{ height: 1, background: 'var(--color-border)' }} />
          <Row icon="settings" label="Settings" />
          <div style={{ height: 1, background: 'var(--color-border)' }} />
          <Row icon="log-out" label="Leave trip" />
        </div>
      </div>
    </div>
  );
}
window.MoreScreen = MoreScreen;
