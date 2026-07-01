function SpotsScreen({ onOpenSpot, iconBase }) {
  const { SpotCard, Tag, Icon, IconButton } = window.WabwayDesignSystem_4e50d7;
  const [filter, setFilter] = React.useState('all');
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';

  const spots = [
    { id: 1, name: 'Fushimi Inari Shrine', city: 'Kyoto', category: 'Temple', status: 'Must-do', votes: { must: 3 } },
    { id: 2, name: 'Ichiran Ramen', city: 'Shinjuku', category: 'Food', status: 'Want to go', votes: { want: 2, maybe: 1 } },
    { id: 3, name: 'TeamLab Borderless', city: 'Tokyo', category: 'Activity', status: 'Booked', votes: { must: 4 } },
    { id: 4, name: 'Nishiki Market', city: 'Kyoto', category: 'Shopping', status: 'Idea', votes: { maybe: 2 } },
    { id: 5, name: 'Golden Gai', city: 'Shinjuku', category: 'Nightlife', status: 'Want to go', votes: { want: 3 } },
  ];

  const categories = ['all', 'Temple', 'Food', 'Activity', 'Shopping', 'Nightlife'];
  const shown = filter === 'all' ? spots : spots.filter((s) => s.category === filter);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', height: '100%', background: 'var(--color-bg)' }}>
      <div style={{ padding: '18px 16px 10px', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <div>
          <div style={{ fontFamily: 'var(--font-sans)', fontSize: 11, color: 'var(--color-text-tertiary)', textTransform: 'uppercase', letterSpacing: '0.05em' }}>Japan, November</div>
          <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>Spots</div>
        </div>
        <IconButton icon={<Icon src={I('search')} />} label="Search" />
      </div>
      <div style={{ display: 'flex', gap: 8, padding: '4px 16px 14px', overflowX: 'auto' }}>
        {categories.map((c) => (
          <Tag key={c} selected={filter === c} onClick={() => setFilter(c)}>{c === 'all' ? 'All' : c}</Tag>
        ))}
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '0 16px 96px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        {shown.map((s) => (
          <SpotCard key={s.id} name={s.name} city={s.city} category={s.category} status={s.status} votes={s.votes} iconBase={iconBase} onClick={() => onOpenSpot(s)} />
        ))}
      </div>
      <button
        onClick={() => onOpenSpot(null)}
        style={{
          position: 'absolute', right: 18, bottom: 92, width: 56, height: 56, borderRadius: '50%',
          background: 'var(--color-primary)', color: '#fff', border: 'none', boxShadow: 'var(--shadow-lg)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', cursor: 'pointer',
        }}
      >
        <Icon src={I('plus')} size={24} color="#fff" />
      </button>
    </div>
  );
}
window.SpotsScreen = SpotsScreen;
