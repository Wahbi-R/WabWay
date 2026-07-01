import React from 'react';
import { Badge } from '../core/Badge.jsx';
import { PhotoSlot } from '../core/Card.jsx';
import { Icon } from '../core/Icon.jsx';
import { VoteChip } from './VoteChip.jsx';

const STATUS_TONE = {
  Idea: 'neutral',
  'Want to go': 'primary',
  'Must-do': 'accent',
  Planned: 'secondary',
  Booked: 'success',
  Skipped: 'danger',
};

/** A single saved place/idea — the core unit of the Spots board. */
export function SpotCard({ name, city, category, status = 'Idea', photo, votes = {}, addedBy, iconBase = '../../', onClick }) {
  return (
    <div
      onClick={onClick}
      style={{
        display: 'flex',
        gap: 'var(--space-4)',
        padding: 'var(--space-4)',
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-sm)',
        cursor: onClick ? 'pointer' : 'default',
      }}
    >
      <div style={{ width: 76, flexShrink: 0 }}>
        {photo ? (
          <img src={photo} alt={name} style={{ width: 76, height: 76, borderRadius: 'var(--radius-md)', objectFit: 'cover' }} />
        ) : (
          <PhotoSlot icon={<Icon src={`${iconBase}assets/icons/map-pin.svg`} />} aspect="1/1" />
        )}
      </div>
      <div style={{ flex: 1, minWidth: 0, display: 'flex', flexDirection: 'column', gap: 6 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8 }}>
          <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
            {name}
          </div>
          <Badge tone={STATUS_TONE[status] || 'neutral'}>{status}</Badge>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>
          <Icon src={`${iconBase}assets/icons/map-pin.svg`} size={14} color="var(--color-text-tertiary)" />
          {city} · {category}
        </div>
        <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 2 }}>
          {Object.entries(votes).map(([key, count]) =>
            count > 0 ? <VoteChip key={key} vote={key} selected /> : null
          )}
        </div>
      </div>
    </div>
  );
}
