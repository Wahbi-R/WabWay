import React from 'react';

/** Desktop top bar — section title, search, and the signed-in member's avatar. Pairs with Sidebar. */
export function TopBar({ title, children }) {
  return (
    <header
      style={{
        height: 'var(--topbar-height)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between',
        padding: '0 var(--space-6)',
        borderBottom: '1px solid var(--color-border)',
        background: 'var(--color-surface)',
        flexShrink: 0,
      }}
    >
      <h1 style={{ margin: 0, fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-xl)', color: 'var(--color-text-primary)' }}>{title}</h1>
      <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>{children}</div>
    </header>
  );
}
