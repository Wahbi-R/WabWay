function WabwayMobileApp() {
  const { BottomNav } = window.WabwayDesignSystem_4e50d7;
  const iconBase = '../../';
  const [tab, setTab] = React.useState('spots');
  const [openSpot, setOpenSpot] = React.useState(undefined); // undefined = closed, object|null = open
  const [addReceiptOpen, setAddReceiptOpen] = React.useState(false);

  const screens = {
    spots: <window.SpotsScreen iconBase={iconBase} onOpenSpot={setOpenSpot} />,
    plan: <window.PlanScreen iconBase={iconBase} />,
    money: <window.MoneyScreen iconBase={iconBase} onAddReceipt={() => setAddReceiptOpen(true)} />,
    docs: <window.DocsScreen iconBase={iconBase} />,
    more: <window.MoreScreen iconBase={iconBase} />,
  };

  return (
    <AndroidDevice width={412} height={892}>
      <div style={{ position: 'relative', height: '100%', display: 'flex', flexDirection: 'column', fontFamily: 'var(--font-sans)' }}>
        <div style={{ flex: 1, minHeight: 0 }}>{screens[tab]}</div>
        <BottomNav active={tab} onChange={setTab} iconBase={iconBase} />
        {openSpot !== undefined && (
          <window.SpotDetailSheet spot={openSpot} iconBase={iconBase} onClose={() => setOpenSpot(undefined)} />
        )}
        {addReceiptOpen && (
          <window.AddReceiptSheet iconBase={iconBase} onClose={() => setAddReceiptOpen(false)} />
        )}
      </div>
    </AndroidDevice>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<WabwayMobileApp />);
