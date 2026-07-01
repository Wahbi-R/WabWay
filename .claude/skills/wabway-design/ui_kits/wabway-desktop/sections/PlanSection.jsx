function PlanSection({ iconBase }) {
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
    { date: 'Nov 14', city: 'Kyoto', items: [
      { time: '11:00', title: 'Nishiki Market' },
      { time: '18:00', title: 'Pontocho dinner' },
    ]},
  ];
  const { ItineraryDayCard } = window.WabwayDesignSystem_4e50d7;
  return (
    <div style={{ padding: '28px 36px', maxWidth: 720, display: 'flex', flexDirection: 'column', gap: 18 }}>
      <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>Day-by-day plan</div>
      {days.map((d) => <ItineraryDayCard key={d.date} {...d} />)}
    </div>
  );
}
window.PlanSection = PlanSection;
