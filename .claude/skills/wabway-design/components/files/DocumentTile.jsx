import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { Badge } from '../core/Badge.jsx';

const TYPE_ICON = {
  Hotel: 'bed-double', Flight: 'plane', Train: 'train-front', Ticket: 'ticket',
  Reservation: 'calendar-days', Receipt: 'receipt', Insurance: 'file-text',
  Form: 'file-text', Screenshot: 'image', Other: 'paperclip',
};

/** A stored file — hotel/flight PDFs, tickets, receipts, screenshots — shown as a grid tile. */
export function DocumentTile({ title, type = 'Other', dateLabel, iconBase = '../../', onClick }) {
  return (
    <div
      onClick={onClick}
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
        padding: 'var(--space-4)',
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-sm)',
        cursor: onClick ? 'pointer' : 'default',
        width: 168,
      }}
    >
      <span
        style={{
          width: 40,
          height: 40,
          borderRadius: 'var(--radius-sm)',
          background: 'var(--color-primary-soft)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Icon src={`${iconBase}assets/icons/${TYPE_ICON[type] || 'paperclip'}.svg`} size={18} color="var(--color-primary-dark)" />
      </span>
      <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)', lineHeight: 1.3 }}>{title}</div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <Badge tone="neutral">{type}</Badge>
        {dateLabel && <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-xs)', color: 'var(--color-text-tertiary)' }}>{dateLabel}</span>}
      </div>
    </div>
  );
}
