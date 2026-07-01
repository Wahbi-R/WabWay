import React from 'react';
import { Avatar } from '../core/Avatar.jsx';

/** One row of cash physically handed from the withdrawer to a member — standalone editable version of the rows inside CashWithdrawalCard. */
export function CashDistributionRow({ name, amount, currency = '¥', editable = false, onAmountChange }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)', padding: '8px 0' }}>
      <Avatar name={name} size="sm" />
      <span style={{ flex: 1, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>{name} received</span>
      {editable ? (
        <input
          value={amount}
          onChange={onAmountChange}
          style={{
            width: 100,
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
        <span style={{ fontFamily: 'var(--font-mono)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)' }}>{currency}{amount}</span>
      )}
    </div>
  );
}
