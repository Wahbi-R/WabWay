import React from 'react';

const TONES = {
  neutral: { bg: 'var(--color-surface-sunken)', fg: 'var(--color-text-secondary)', border: 'var(--color-border)' },
  primary: { bg: 'var(--color-primary-soft)', fg: 'var(--color-primary-dark)', border: 'var(--color-primary-soft-border)' },
  secondary: { bg: 'var(--color-secondary-soft)', fg: 'color-mix(in oklch, var(--color-secondary) 60%, black)', border: 'var(--color-secondary-soft-border)' },
  accent: { bg: 'var(--color-accent-soft)', fg: 'color-mix(in oklch, var(--color-accent) 55%, black)', border: 'var(--color-accent-soft-border)' },
  success: { bg: 'var(--color-success-soft)', fg: 'var(--color-success)', border: 'var(--color-success-border)' },
  warning: { bg: 'var(--color-warning-soft)', fg: 'var(--color-warning)', border: 'var(--color-warning-border)' },
  danger: { bg: 'var(--color-danger-soft)', fg: 'var(--color-danger)', border: 'var(--color-danger-border)' },
};

export function Badge({ children, tone = 'neutral', icon = null }) {
  const t = TONES[tone];
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 5,
        height: 24,
        padding: '0 10px',
        borderRadius: 'var(--radius-pill)',
        background: t.bg,
        color: t.fg,
        border: `1px solid ${t.border}`,
        fontFamily: 'var(--font-sans)',
        fontWeight: 'var(--weight-semibold)',
        fontSize: 'var(--text-xs)',
        lineHeight: 1,
        whiteSpace: 'nowrap',
      }}
    >
      {icon && <span style={{ width: 12, height: 12, display: 'inline-flex' }}>{icon}</span>}
      {children}
    </span>
  );
}
