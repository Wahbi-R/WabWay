import React from 'react';
import { Avatar } from '../core/Avatar.jsx';
import { Checkbox } from '../forms/Checkbox.jsx';

/** One member's row in a receipt split editor — toggle inclusion, see/edit their share. */
export function SplitMemberRow({ name, amount, currency = '¥', selected = true, onToggle, editable = false, onAmountChange }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)', padding: '10px 0' }}>
      <Checkbox checked={selected} onChange={onToggle} />
      <Avatar name={name} size="sm" />
      <span style={{ flex: 1, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: selected ? 'var(--color-text-primary)' : 'var(--color-text-tertiary)' }}>{name}</span>
      {editable ? (
        <input
          value={amount}
          onChange={onAmountChange}
          style={{
            width: 88,
            height: 34,
            textAlign: 'right',
            fontFamily: 'var(--font-mono)',
            fontSize: 'var(--text-sm)',
            border: '1.5px solid var(--color-border)',
            borderRadius: 'var(--radius-xs)',
            padding: '0 8px',
          }}
        />
      ) : (
        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-sm)', color: selected ? 'var(--color-text-primary)' : 'var(--color-text-tertiary)' }}>
          {currency}{amount}
        </span>
      )}
    </div>
  );
}
