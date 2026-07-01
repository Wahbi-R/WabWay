import React from 'react';

export function Radio({ label, checked, onChange, disabled }) {
  return (
    <label style={{ display: 'inline-flex', alignItems: 'center', gap: 10, cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? 0.5 : 1 }}>
      <span
        onClick={() => !disabled && onChange && onChange()}
        style={{
          width: 22,
          height: 22,
          borderRadius: '50%',
          border: `1.5px solid ${checked ? 'var(--color-primary)' : 'var(--color-border-strong)'}`,
          background: 'var(--color-surface)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        {checked && <span style={{ width: 11, height: 11, borderRadius: '50%', background: 'var(--color-primary)' }} />}
      </span>
      {label && <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>{label}</span>}
    </label>
  );
}
