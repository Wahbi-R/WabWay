function SpotsSection({ iconBase }) {
  const { SpotCard, VoteChipGroup, CommentThread, Tag, Badge, Icon, Tabs, PhotoSlot, Button } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const spots = [
    { id: 1, name: 'Fushimi Inari Shrine', city: 'Kyoto', category: 'Temple', status: 'Must-do', votes: { must: 3 } },
    { id: 2, name: 'Ichiran Ramen', city: 'Shinjuku', category: 'Food', status: 'Want to go', votes: { want: 2, maybe: 1 } },
    { id: 3, name: 'TeamLab Borderless', city: 'Tokyo', category: 'Activity', status: 'Booked', votes: { must: 4 } },
    { id: 4, name: 'Nishiki Market', city: 'Kyoto', category: 'Shopping', status: 'Idea', votes: { maybe: 2 } },
  ];
  const [filter, setFilter] = React.useState('all');
  const [selected, setSelected] = React.useState(spots[0]);
  const [vote, setVote] = React.useState('must');
  const [tab, setTab] = React.useState('details');
  const categories = ['all', 'Temple', 'Food', 'Activity', 'Shopping'];
  const shown = filter === 'all' ? spots : spots.filter((s) => s.category === filter);

  return (
    <div style={{ display: 'flex', height: '100%' }}>
      <div style={{ width: 380, borderRight: '1px solid var(--color-border)', display: 'flex', flexDirection: 'column', minHeight: 0 }}>
        <div style={{ display: 'flex', gap: 8, padding: '16px 20px 10px', overflowX: 'auto' }}>
          {categories.map((c) => <Tag key={c} selected={filter === c} onClick={() => setFilter(c)}>{c === 'all' ? 'All' : c}</Tag>)}
        </div>
        <div style={{ flex: 1, overflowY: 'auto', padding: '6px 20px 20px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          {shown.map((s) => (
            <SpotCard key={s.id} {...s} iconBase={iconBase} onClick={() => setSelected(s)} />
          ))}
        </div>
      </div>
      <div style={{ flex: 1, overflowY: 'auto', padding: '28px 36px', maxWidth: 640 }}>
        {selected && (
          <>
            <div style={{ display: 'flex', gap: 20 }}>
              <div style={{ width: 160, flexShrink: 0 }}>
                <PhotoSlot icon={<Icon src={I('image')} />} aspect="1/1" />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                  <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-2xl)', color: 'var(--color-text-primary)' }}>{selected.name}</div>
                  <Badge tone="accent">{selected.status}</Badge>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-secondary)' }}>
                  <Icon src={I('map-pin')} size={16} color="var(--color-text-tertiary)" />{selected.city} · {selected.category}
                </div>
                <div style={{ marginTop: 14 }}>
                  <Button variant="ghost" size="sm" icon={<Icon src={I('map-pin')} />}>Open in Google Maps</Button>
                </div>
              </div>
            </div>
            <div style={{ marginTop: 24 }}>
              <Tabs tabs={[{ value: 'details', label: 'Details' }, { value: 'comments', label: 'Comments' }]} value={tab} onChange={setTab} />
            </div>
            {tab === 'details' ? (
              <div style={{ marginTop: 18, display: 'flex', flexDirection: 'column', gap: 16 }}>
                <div>
                  <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)', marginBottom: 8 }}>Your vote</div>
                  <VoteChipGroup value={vote} onChange={setVote} />
                </div>
                <p style={{ margin: 0, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-secondary)', lineHeight: 'var(--leading-normal)' }}>
                  We should go early before it gets packed — sunrise is supposedly the move.
                </p>
              </div>
            ) : (
              <div style={{ marginTop: 18 }}>
                <CommentThread comments={[
                  { author: 'Josh Park', text: 'We should go early before it gets packed.', time: '2d ago', vote: 'must' },
                  { author: 'Matt Lee', text: 'Agreed, heard sunrise is the move.', time: '1d ago' },
                ]} />
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
window.SpotsSection = SpotsSection;
