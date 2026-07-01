import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { PhotoSlot } from '../core/Card.jsx';
import { MemberAvatarRow } from './MemberAvatarRow.jsx';

/** A trip workspace summary — shown on the trip switcher / home list. */
export function TripCard({ name, destination, dateRange, cover, members = [], iconBase = '../../', onClick }) {
  return (
    <div
      onClick={onClick}
      style={{
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-sm)',
        overflow: 'hidden',
        cursor: onClick ? 'pointer' : 'default',
      }}
    >
      {cover ? (
        <img src={cover} alt={name} style={{ width: '100%', height: 130, objectFit: 'cover' }} />
      ) : (
        <PhotoSlot icon={<Icon src={`${iconBase}assets/icons/image.svg`} />} aspect="auto" style={{ height: 130, borderRadius: 0, border: 'none', borderBottom: '1px solid var(--color-border)' }} />
      )}
      <div style={{ padding: 'var(--space-4)', display: 'flex', flexDirection: 'column', gap: 8 }}>
        <div style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-lg)', color: 'var(--color-text-primary)' }}>{name}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>
          <Icon src={`${iconBase}assets/icons/map-pin.svg`} size={14} color="var(--color-text-tertiary)" />
          {destination} · {dateRange}
        </div>
        {members.length > 0 && (
          <div style={{ marginTop: 4 }}>
            <MemberAvatarRow members={members} max={5} size="sm" />
          </div>
        )}
      </div>
    </div>
  );
}
