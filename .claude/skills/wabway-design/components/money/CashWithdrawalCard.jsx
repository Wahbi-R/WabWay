import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { Avatar } from '../core/Avatar.jsx';

/** An ATM cash withdrawal — the amount taken out, fee, and who it was withdrawn by. */
export function CashWithdrawalCard({ withdrawnBy, amount, atmFee, currency = '¥', dateLabel, distributed = [], iconBase = '../../', onClick }) {
  return (
    <div
      onClick={onClick}
      style={{
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-sm)',
        padding: 'var(--space-4)',
        cursor: onClick ? 'pointer' : 'default',
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
        <span style={{ width: 44, height: 44, borderRadius: 'var(--radius-sm)', background: 'var(--color-secondary-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
          <Icon src={`${iconBase}assets/icons/banknote.svg`} size={20} color="color-mix(in oklch, var(--color-secondary) 55%, black)" />
        </span>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>ATM withdrawal</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
            <Avatar name={withdrawnBy} size="xs" />
            <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>{withdrawnBy} · {dateLabel}</span>
          </div>
        </div>
        <div style={{ textAlign: 'right' }}>
          <div style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 'var(--text-md)', color: 'var(--color-text-primary)' }}>{currency}{amount}</div>
          {atmFee && <div style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-xs)', color: 'var(--color-text-tertiary)' }}>fee {currency}{atmFee}</div>}
        </div>
      </div>
      {distributed.length > 0 && (
        <div style={{ borderTop: '1px solid var(--color-border)', paddingTop: 10, display: 'flex', flexDirection: 'column', gap: 6 }}>
          {distributed.map((d) => (
            <div key={d.name} style={{ display: 'flex', justifyContent: 'space-between', fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)' }}>
              <span style={{ color: 'var(--color-text-secondary)' }}>{d.name} received</span>
              <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--color-text-primary)' }}>{currency}{d.amount}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
