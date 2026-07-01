import React from 'react';

const VOTES = [
  { key: 'must', label: 'Must-do', color: 'var(--color-primary)' },
  { key: 'want', label: 'Want', color: 'var(--color-secondary)' },
  { key: 'maybe', label: 'Maybe', color: 'var(--color-accent)' },
  { key: 'skip', label: 'Skip', color: 'var(--color-text-tertiary)' },
];

/** One tappable vote pill. Render four side-by-side (must/want/maybe/skip) for a spot's vote row. */
export function VoteChip({ vote, selected, onClick }) {
  const v = VOTES.find((x) => x.key === vote) || VOTES[0];
  return (
    <button
      onClick={onClick}
      style={{
        height: 30,
        padding: '0 12px',
        borderRadius: 'var(--radius-pill)',
        border: `1.5px solid ${selected ? v.color : 'var(--color-border)'}`,
        background: selected ? `color-mix(in oklch, ${v.color} 16%, var(--color-surface))` : 'var(--color-surface)',
        color: selected ? 'var(--color-text-primary)' : 'var(--color-text-secondary)',
        fontFamily: 'var(--font-sans)',
        fontWeight: selected ? 'var(--weight-semibold)' : 'var(--weight-medium)',
        fontSize: 'var(--text-xs)',
        cursor: 'pointer',
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
      }}
    >
      <span style={{ width: 7, height: 7, borderRadius: '50%', background: v.color, display: 'inline-block' }} />
      {v.label}
    </button>
  );
}

/** Full must/want/maybe/skip row, one VoteChip each. */
export function VoteChipGroup({ value, onChange }) {
  return (
    <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
      {VOTES.map((v) => (
        <VoteChip key={v.key} vote={v.key} selected={value === v.key} onClick={() => onChange && onChange(v.key)} />
      ))}
    </div>
  );
}
