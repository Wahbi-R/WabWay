import React from 'react';

const TONES = {
  info: { bg: 'var(--color-primary-soft)', border: 'var(--color-primary-soft-border)', fg: 'var(--color-primary-dark)' },
  success: { bg: 'var(--color-success-soft)', border: 'var(--color-success-border)', fg: 'var(--color-success)' },
  warning: { bg: 'var(--color-warning-soft)', border: 'var(--color-warning-border)', fg: 'var(--color-warning)' },
  danger: { bg: 'var(--color-danger-soft)', border: 'var(--color-danger-border)', fg: 'var(--color-danger)' },
};

/** Inline persistent banner — "You're offline", "3 friends still need to settle up". */
export function Banner({ icon, tone = 'info', children, action }) {
  const t = TONES[tone];
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: 'var(--space-3)',
        padding: 'var(--space-3) var(--space-4)',
        background: t.bg,
        border: `1px solid ${t.border}`,
        borderRadius: 'var(--radius-md)',
        color: t.fg,
        fontFamily: 'var(--font-sans)',
        fontSize: 'var(--text-sm)',
        fontWeight: 'var(--weight-medium)',
      }}
    >
      {icon && <span style={{ width: 18, height: 18, flexShrink: 0 }}>{icon}</span>}
      <span style={{ flex: 1 }}>{children}</span>
      {action}
    </div>
  );
}
