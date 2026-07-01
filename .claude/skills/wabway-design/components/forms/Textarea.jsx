import React from 'react';

export function Textarea({ label, placeholder, value, onChange, rows = 3, helpText }) {
  const [focused, setFocused] = React.useState(false);
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 6, fontFamily: 'var(--font-sans)' }}>
      {label && <span style={{ fontSize: 'var(--text-sm)', fontWeight: 'var(--weight-semibold)', color: 'var(--color-text-primary)' }}>{label}</span>}
      <textarea
        value={value}
        placeholder={placeholder}
        rows={rows}
        onChange={onChange}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        style={{
          width: '100%',
          padding: '12px 14px',
          fontFamily: 'var(--font-sans)',
          fontSize: 'var(--text-base)',
          color: 'var(--color-text-primary)',
          background: 'var(--color-surface)',
          border: `1.5px solid ${focused ? 'var(--color-primary)' : 'var(--color-border)'}`,
          borderRadius: 'var(--radius-sm)',
          outline: 'none',
          resize: 'vertical',
          boxShadow: focused ? '0 0 0 3px var(--color-focus-ring)' : 'none',
          transition: 'border-color var(--duration-fast) var(--ease-standard)',
        }}
      />
      {helpText && <span style={{ fontSize: 'var(--text-xs)', color: 'var(--color-text-tertiary)' }}>{helpText}</span>}
    </label>
  );
}
