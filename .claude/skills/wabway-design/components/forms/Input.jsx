import React from 'react';

export function Input({ label, placeholder, value, onChange, type = 'text', icon, error, helpText, disabled }) {
  const [focused, setFocused] = React.useState(false);
  return (
    <label style={{ display: 'flex', flexDirection: 'column', gap: 6, fontFamily: 'var(--font-sans)' }}>
      {label && <span style={{ fontSize: 'var(--text-sm)', fontWeight: 'var(--weight-semibold)', color: 'var(--color-text-primary)' }}>{label}</span>}
      <span style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
        {icon && <span style={{ position: 'absolute', left: 14, width: 18, height: 18, color: 'var(--color-text-tertiary)' }}>{icon}</span>}
        <input
          type={type}
          value={value}
          placeholder={placeholder}
          disabled={disabled}
          onChange={onChange}
          onFocus={() => setFocused(true)}
          onBlur={() => setFocused(false)}
          style={{
            width: '100%',
            height: 'var(--tap-target-min)',
            padding: icon ? '0 14px 0 40px' : '0 14px',
            fontFamily: 'var(--font-sans)',
            fontSize: 'var(--text-base)',
            color: 'var(--color-text-primary)',
            background: disabled ? 'var(--color-surface-sunken)' : 'var(--color-surface)',
            border: `1.5px solid ${error ? 'var(--color-danger)' : focused ? 'var(--color-primary)' : 'var(--color-border)'}`,
            borderRadius: 'var(--radius-sm)',
            outline: 'none',
            boxShadow: focused ? '0 0 0 3px var(--color-focus-ring)' : 'none',
            transition: 'border-color var(--duration-fast) var(--ease-standard), box-shadow var(--duration-fast) var(--ease-standard)',
          }}
        />
      </span>
      {(error || helpText) && (
        <span style={{ fontSize: 'var(--text-xs)', color: error ? 'var(--color-danger)' : 'var(--color-text-tertiary)' }}>
          {error || helpText}
        </span>
      )}
    </label>
  );
}
