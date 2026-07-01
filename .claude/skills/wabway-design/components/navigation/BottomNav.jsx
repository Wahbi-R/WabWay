import React from 'react';

const NAV_ITEMS = [
  { key: 'spots', label: 'Spots', icon: 'map-pin' },
  { key: 'plan', label: 'Plan', icon: 'calendar-days' },
  { key: 'money', label: 'Money', icon: 'wallet' },
  { key: 'docs', label: 'Docs', icon: 'file-text' },
  { key: 'more', label: 'More', icon: 'ellipsis' },
];

/** Fixed bottom tab bar — mobile only. 5 items per the product nav spec. */
export function BottomNav({ active = 'spots', onChange, iconBase = '' }) {
  return (
    <nav
      style={{
        display: 'flex',
        height: 'var(--bottom-nav-height)',
        background: 'var(--color-surface)',
        borderTop: '1px solid var(--color-border)',
        boxShadow: 'var(--shadow-md)',
      }}
    >
      {NAV_ITEMS.map((item) => {
        const isActive = item.key === active;
        return (
          <button
            key={item.key}
            onClick={() => onChange && onChange(item.key)}
            style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 4,
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              color: isActive ? 'var(--color-primary)' : 'var(--color-text-tertiary)',
            }}
          >
            <span
              style={{
                width: 24,
                height: 24,
                display: 'inline-block',
                backgroundColor: 'currentColor',
                WebkitMaskImage: `url(${iconBase}assets/icons/${item.icon}.svg)`,
                maskImage: `url(${iconBase}assets/icons/${item.icon}.svg)`,
                WebkitMaskSize: 'contain',
                maskSize: 'contain',
                WebkitMaskRepeat: 'no-repeat',
                maskRepeat: 'no-repeat',
                WebkitMaskPosition: 'center',
                maskPosition: 'center',
              }}
            />
            <span style={{ fontFamily: 'var(--font-sans)', fontSize: 11, fontWeight: isActive ? 'var(--weight-bold)' : 'var(--weight-medium)' }}>
              {item.label}
            </span>
          </button>
        );
      })}
    </nav>
  );
}
