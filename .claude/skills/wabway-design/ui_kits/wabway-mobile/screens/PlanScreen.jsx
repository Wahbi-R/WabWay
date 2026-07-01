function PlanScreen({ iconBase }) {
  const { ItineraryDayCard, IconButton, Icon } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const days = [
    { date: 'Nov 12', city: 'Tokyo', items: [
      { time: '10:00', title: 'TeamLab Borderless' },
      { time: '13:00', title: 'Lunch in Ginza' },
      { time: '20:00', title: 'Shinjuku food & drinks', notes: 'Meet at Golden Gai entrance' },
    ]},
    { date: 'Nov 13', city: 'Tokyo → Kyoto', items: [
      { time: '09:00', title: 'Shinkansen to Kyoto', notes: 'Nozomi 203' },
      { time: '15:00', title: 'Fushimi Inari Shrine' },
    ]},
  ];
  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--color-bg)' }}>
      <div style={{ padding: '18px 16px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: 'var(--font-sans)', fontSize: 11, color: 'var(--color-text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Itinerary · Flights · Hotels</div>
          <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>Plan</div>
        </div>
        <IconButton icon={<Icon src={I('plus')} />} label="Add day" variant="solid" />
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '4px 16px 96px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {days.map((d) => <ItineraryDayCard key={d.date} {...d} />)}
      </div>
    </div>
  );
}
window.PlanScreen = PlanScreen;
