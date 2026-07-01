import React from 'react';

export function Select({ label, value, onChange, options, placeholder = 'Select' }) {
  const [focused, setFocused] = React.useState(false);
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 6, fontFamily: 'var(--font-sans)' }}>
      {label && <span style={{ fontSize: 'var(--text-sm)', fontWeight: 'var(--weight-semibold)', color: 'var(--color-text-primary)' }}>{label}</span>}
      <span style={{ position: 'relative', display: 'flex' }}>
        <select
          value={value}
          onChange={onChange}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          style={{
            width: '100%',
            height: 'var(--tap-target-min)',
            padding: '0 36px 0 14px',
            appearance: 'none',
            fontFamily: 'var(--font-sans)',
            fontSize: 'var(--text-base)',
            color: value ? 'var(--color-text-primary)' : 'var(--color-text-tertiary)',
            background: 'var(--color-surface)',
            border: `1.5px solid ${focused ? 'var(--color-primary)' : 'var(--color-border)'}`,
            borderRadius: 'var(--radius-sm)',
            outline: 'none',
            boxShadow: focused ? '0 0 0 3px var(--color-focus-ring)' : 'none',
          }}
        >
          <option value="" disabled hidden>{placeholder}</option>
          {options.map((o) => (
            <option key={o.value} value={o.value}>{o.label}</option>
          ))}
        </select>
        <span style={{ position: 'absolute', right: 12, top: '50%', transform: 'translateY(-50%)', pointerEvents: 'none', color: 'var(--color-text-tertiary)', fontSize: 11 }}>▾</span>
      </span>
    </label>
  );
}
