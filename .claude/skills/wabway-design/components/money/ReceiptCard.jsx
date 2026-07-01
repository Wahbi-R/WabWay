import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { Avatar } from '../core/Avatar.jsx';

/** A shared expense — paid by one person, split between selected members. */
export function ReceiptCard({ title, amount, currency = '¥', paidBy, category, dateLabel, splitCount, iconBase = '../../', onClick }) {
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
      <span style={{ width: 44, height: 44, borderRadius: 'var(--radius-sm)', background: 'var(--color-primary-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        <Icon src={`${iconBase}assets/icons/receipt.svg`} size={20} color="var(--color-primary-dark)" />
      </span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>{title}</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 2 }}>
          <Avatar name={paidBy} size="xs" />
          <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>
            {paidBy} paid · {category} · split {splitCount} ways
          </span>
        </div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 'var(--text-md)', color: 'var(--color-text-primary)' }}>{currency}{amount}</div>
        {dateLabel && <div style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-xs)', color: 'var(--color-text-tertiary)' }}>{dateLabel}</div>}
      </div>
    </div>
  );
}
