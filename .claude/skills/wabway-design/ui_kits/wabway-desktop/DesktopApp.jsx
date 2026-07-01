function WabwayDesktopApp() {
  const { Sidebar, TopBar, Avatar, IconButton, Icon } = window.WabwayDesignSystem_4e50d7;
  const iconBase = '../../';
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const [section, setSection] = React.useState('home');

  const TITLES = {
    home: 'Home', spots: 'Spots', links: 'Links', map: 'Map', plan: 'Plan',
    travel: 'Travel', money: 'Money', documents: 'Documents', members: 'Members', settings: 'Settings',
  };

  const content = {
    home: <window.HomeSection iconBase={iconBase} />,
    spots: <window.SpotsSection iconBase={iconBase} />,
    plan: <window.PlanSection iconBase={iconBase} />,
    money: <window.MoneySection iconBase={iconBase} />,
    documents: <window.DocumentsSection iconBase={iconBase} />,
    members: <window.MembersSection iconBase={iconBase} />,
    links: <window.ComingSoonSection iconBase={iconBase} label="Links" />,
    map: <window.ComingSoonSection iconBase={iconBase} label="Map" />,
    travel: <window.ComingSoonSection iconBase={iconBase} label="Travel" />,
    settings: <window.ComingSoonSection iconBase={iconBase} label="Settings" />,
  };

  return (
    <ChromeWindow width={1280} height={800} url="wabway.app/trips/japan-november">
      <div style={{ display: 'flex', height: '100%', fontFamily: 'var(--font-sans)', background: 'var(--color-bg)' }}>
        <Sidebar active={section} onChange={setSection} tripName="Japan, November" iconBase={iconBase} />
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', minWidth: 0 }}>
          <TopBar title={TITLES[section]}>
            <IconButton icon={<Icon src={I('bell')} />} label="Notifications" />
            <Avatar name="You" size="sm" />
          </TopBar>
          <div style={{ flex: 1, overflowY: 'auto', minHeight: 0 }}>{content[section]}</div>
        </div>
      </div>
    </ChromeWindow>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<WabwayDesktopApp />);
