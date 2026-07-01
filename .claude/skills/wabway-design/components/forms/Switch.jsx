import React from 'react';

export function Switch({ checked, onChange, label, disabled }) {
  return (
    <label style={{ display: 'inline-flex', alignItems: 'center', gap: 10, cursor: disabled ? 'not-allowed' : 'pointer', opacity: disabled ? 0.5 : 1 }}>
      {label && <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>{label}</span>}
      <span
        onClick={() => !disabled && onChange && onChange(!checked)}
        style={{
          width: 44,
          height: 26,
          borderRadius: 'var(--radius-pill)',
          background: checked ? 'var(--color-primary)' : 'var(--color-border-strong)',
          position: 'relative',
          transition: 'background var(--duration-fast) var(--ease-standard)',
          flexShrink: 0,
        }}
      >
        <span
          style={{
            position: 'absolute',
            top: 3,
            left: checked ? 21 : 3,
            width: 20,
            height: 20,
            borderRadius: '50%',
            background: '#FFFDF8',
            boxShadow: 'var(--shadow-sm)',
            transition: 'left var(--duration-fast) var(--ease-standard)',
          }}
        />
      </span>
    </label>
  );
}
