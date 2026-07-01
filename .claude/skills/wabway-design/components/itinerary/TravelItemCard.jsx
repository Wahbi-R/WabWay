import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { Badge } from '../core/Badge.jsx';

const TYPE_ICON = { Flight: 'plane', Hotel: 'bed-double', Train: 'train-front', Ticket: 'ticket', Reservation: 'calendar-days' };

/** A structured travel item (flight/hotel/train/ticket/reservation) — lives in the Travel section. */
export function TravelItemCard({ type, title, subtitle, confirmationNumber, iconBase = '../../', onClick }) {
  return (
    <div
      onClick={onClick}
      style={{
        display: 'flex',
        gap: 'var(--space-4)',
        alignItems: 'center',
        padding: 'var(--space-4)',
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-sm)',
        cursor: onClick ? 'pointer' : 'default',
      }}
    >
      <span
        style={{
          width: 44,
          height: 44,
          borderRadius: 'var(--radius-sm)',
          background: 'var(--color-accent-soft)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon src={`${iconBase}assets/icons/${TYPE_ICON[type] || 'ticket'}.svg`} size={20} color="color-mix(in oklch, var(--color-accent) 55%, black)" />
      </span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <Badge tone="accent">{type}</Badge>
        </div>
        <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)', marginTop: 4 }}>{title}</div>
        {subtitle && <div style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>{subtitle}</div>}
      </div>
      {confirmationNumber && (
        <div style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-xs)', color: 'var(--color-text-tertiary)', textAlign: 'right' }}>
          {confirmationNumber}
        </div>
      )}
    </div>
  );
}
