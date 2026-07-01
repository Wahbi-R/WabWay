import React from 'react';

export function Tabs({ tabs, value, onChange }) {
  return (
    <div style={{ display: 'flex', gap: 'var(--space-1)', borderBottom: '1px solid var(--color-border)' }}>
      {tabs.map((t) => {
        const active = t.value === value;
        return (
          <button
            key={t.value}
            onClick={() => onChange(t.value)}
            style={{
              position: 'relative',
              background: 'none',
              border: 'none',
              padding: '10px 4px',
              marginRight: 'var(--space-5)',
              fontFamily: 'var(--font-sans)',
              fontWeight: 'var(--weight-semibold)',
              fontSize: 'var(--text-base)',
              color: active ? 'var(--color-text-primary)' : 'var(--color-text-tertiary)',
              cursor: 'pointer',
              bottom: -1,
            }}
          >
            {t.label}
            {active && (
              <span
                style={{
                  position: 'absolute',
                  left: 0,
                  right: 0,
                  bottom: -1,
                  height: 2,
                  borderRadius: 2,
                  background: 'var(--color-primary)',
                }}
              />
            )}
          </button>
        );
      })}
    </div>
  );
}
