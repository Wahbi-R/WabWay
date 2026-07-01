import React from 'react';

/** Calm error state — names what happened and offers the one next step. Never "Oops!". */
export function ErrorState({ icon, title = "Couldn't load this", description = 'Check your connection and try again.', action }) {
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        textAlign: 'center',
        gap: 'var(--space-3)',
        padding: 'var(--space-12) var(--space-6)',
      }}
    >
      <span
        style={{
          width: 56,
          height: 56,
          borderRadius: '50%',
          background: 'var(--color-danger-soft)',
          color: 'var(--color-danger)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <span style={{ width: 26, height: 26 }}>{icon}</span>
      </span>
      <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-lg)', color: 'var(--color-text-primary)' }}>{title}</div>
      <div style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-secondary)', maxWidth: 320 }}>{description}</div>
      {action && <div style={{ marginTop: 'var(--space-2)' }}>{action}</div>}
    </div>
  );
}
