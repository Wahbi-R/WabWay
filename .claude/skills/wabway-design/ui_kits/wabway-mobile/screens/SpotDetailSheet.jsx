function SpotDetailSheet({ spot, onClose, iconBase }) {
  const { Icon, IconButton, Badge, VoteChipGroup, CommentThread, PhotoSlot, Tabs, Button } = window.WabwayDesignSystem_4e50d7;
  const I = (n) => iconBase + 'assets/icons/' + n + '.svg';
  const [vote, setVote] = React.useState('must');
  const [tab, setTab] = React.useState('details');
  const s = spot || { name: 'New spot', city: 'Tokyo', category: 'Food', status: 'Idea' };

  return (
    <div style={{ position: 'absolute', inset: 0, background: 'var(--color-bg)', display: 'flex', flexDirection: 'column', zIndex: 30 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '14px 12px', borderBottom: '1px solid var(--color-border)', background: 'var(--color-surface)' }}>
        <IconButton icon={<Icon src={I('arrow-left')} />} label="Back" onClick={onClose} />
        <span style={{ flex: 1, fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.name}</span>
        <IconButton icon={<Icon src={I('ellipsis')} />} label="More" />
      </div>
      <div style={{ flex: 1, overflowY: 'auto' }}>
        <PhotoSlot icon={<Icon src={I('image')} />} label="Add a photo" aspect="auto" style={{ height: 180, borderRadius: 0, border: 'none' }} />
        <div style={{ padding: '16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-xl)', color: 'var(--color-text-primary)' }}>{s.name}</div>
            <Badge tone="accent">{s.status}</Badge>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 6, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>
            <Icon src={I('map-pin')} size={14} color="var(--color-text-tertiary)" />{s.city} · {s.category}
          </div>
          <div style={{ marginTop: 16 }}>
            <Tabs tabs={[{ value: 'details', label: 'Details' }, { value: 'comments', label: 'Comments' }]} value={tab} onChange={setTab} />
          </div>
          {tab === 'details' ? (
            <div style={{ marginTop: 16, display: 'flex', flexDirection: 'column', gap: 14 }}>
              <div>
                <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)', marginBottom: 8 }}>Your vote</div>
                <VoteChipGroup value={vote} onChange={setVote} />
              </div>
              <div>
                <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)', marginBottom: 6 }}>Notes</div>
                <p style={{ margin: 0, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-secondary)', lineHeight: 'var(--leading-normal)' }}>
                  We should go early before it gets packed — sunrise is supposedly the move.
                </p>
              </div>
              <Button variant="ghost" icon={<Icon src={I('map-pin')} />}>Open in Google Maps</Button>
            </div>
          ) : (
            <div style={{ marginTop: 16 }}>
              <CommentThread comments={[
                { author: 'Josh Park', text: 'We should go early before it gets packed.', time: '2d ago', vote: 'must' },
                { author: 'Matt Lee', text: 'Agreed, heard sunrise is the move.', time: '1d ago' },
              ]} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
window.SpotDetailSheet = SpotDetailSheet;
