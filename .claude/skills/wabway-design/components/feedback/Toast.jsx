import React from 'react';

const TONE_COLOR = {
  default: 'var(--color-text-primary)',
  success: 'var(--color-success)',
  danger: 'var(--color-danger)',
};

/** Transient bottom-of-screen confirmation — "Saved", "Receipt added", "Link copied". */
export function Toast({ message, tone = 'default', icon, onClose }) {
  return (
    <div
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 10,
        background: 'var(--color-text-primary)',
        color: 'var(--color-surface)',
        padding: '12px 16px',
        borderRadius: 'var(--radius-md)',
        boxShadow: 'var(--shadow-lg)',
        fontFamily: 'var(--font-sans)',
        fontSize: 'var(--text-sm)',
        fontWeight: 'var(--weight-medium)',
        maxWidth: 360,
      }}
    >
      {icon && <span style={{ width: 18, height: 18, color: TONE_COLOR[tone] === 'var(--color-text-primary)' ? 'var(--color-accent)' : TONE_COLOR[tone] }}>{icon}</span>}
      <span style={{ flex: 1 }}>{message}</span>
      {onClose && (
        <button onClick={onClose} style={{ background: 'none', border: 'none', color: 'inherit', opacity: 0.6, cursor: 'pointer', fontSize: 16, lineHeight: 1, padding: 0 }}>×</button>
      )}
    </div>
  );
}
