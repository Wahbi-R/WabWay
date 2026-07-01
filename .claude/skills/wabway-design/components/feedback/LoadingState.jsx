import React from 'react';

/** Skeleton placeholder rows shown while content loads — never a spinner-only blank screen. */
export function LoadingState({ rows = 3 }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
      {Array.from({ length: rows }).map((_, i) => (
        <div
          key={i}
          style={{
            display: 'flex',
            gap: 'var(--space-3)',
            alignItems: 'center',
            padding: 'var(--space-4)',
            background: 'var(--color-surface)',
            borderRadius: 'var(--radius-lg)',
            border: '1px solid var(--color-border)',
          }}
        >
          <span style={{ width: 44, height: 44, borderRadius: 'var(--radius-sm)', background: 'var(--color-surface-sunken)', animation: 'wabway-pulse 1.4s ease-in-out infinite' }} />
          <span style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8 }}>
            <span style={{ width: '60%', height: 12, borderRadius: 6, background: 'var(--color-surface-sunken)', animation: 'wabway-pulse 1.4s ease-in-out infinite' }} />
            <span style={{ width: '35%', height: 10, borderRadius: 6, background: 'var(--color-surface-sunken)', animation: 'wabway-pulse 1.4s ease-in-out infinite' }} />
          </span>
        </div>
      ))}
      <style>{`@keyframes wabway-pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.45; } }`}</style>
    </div>
  );
}
