import React from 'react';
import { Avatar } from '../core/Avatar.jsx';

/** "Who owes who" — the Settle Up rollup. Positive lines = you're owed, negative = you owe. */
export function BalanceSummaryCard({ youOwe = [], youAreOwed = [], currency = '¥' }) {
  const empty = youOwe.length === 0 && youAreOwed.length === 0;
  return (
    <div
      style={{
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-sm)',
        padding: 'var(--space-5)',
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--space-4)',
      }}
    >
      {empty ? (
        <div style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-secondary)', textAlign: 'center', padding: 'var(--space-4) 0' }}>
          You're all settled up
        </div>
      ) : (
        <>
          {youOwe.length > 0 && (
            <div>
              <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-sm)', color: 'var(--color-danger)', marginBottom: 8 }}>You owe</div>
              {youOwe.map((p) => (
                <Row key={p.name} {...p} currency={currency} tone="danger" />
              ))}
            </div>
          )}
          {youAreOwed.length > 0 && (
            <div>
              <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-sm)', color: 'var(--color-success)', marginBottom: 8 }}>You are owed</div>
              {youAreOwed.map((p) => (
                <Row key={p.name} {...p} currency={currency} tone="success" />
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}

function Row({ name, amount, currency, tone }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '6px 0' }}>
      <Avatar name={name} size="xs" />
      <span style={{ flex: 1, fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>{name}</span>
      <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, fontSize: 'var(--text-base)', color: `var(--color-${tone})` }}>{currency}{amount}</span>
    </div>
  );
}
