import React from 'react';

export function Checkbox({ label, checked, onChange, disabled }) {
  return (
    <label style={{ display: 'inline-flex', alignItems: 'center', gap: 10, cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? 0.5 : 1 }}>
      <span
        onClick={() => !disabled && onChange && onChange(!checked)}
        style={{
          width: 22,
          height: 22,
          borderRadius: 7,
          border: `1.5px solid ${checked ? 'var(--color-primary)' : 'var(--color-border-strong)'}`,
          background: checked ? 'var(--color-primary)' : 'var(--color-surface)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
          transition: 'background var(--duration-fast) var(--ease-standard)',
        }}
      >
        {checked && (
          <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round">
            <path d="m20 6-11 11-5-5" />
          </svg>
        )}
      </span>
      {label && <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>{label}</span>}
    </label>
  );
}
