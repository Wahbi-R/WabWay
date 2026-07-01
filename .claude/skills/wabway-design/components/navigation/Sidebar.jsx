import React from 'react';

const NAV_ITEMS = [
  { key: 'home', label: 'Home', icon: 'house' },
  { key: 'spots', label: 'Spots', icon: 'map-pin' },
  { key: 'links', label: 'Links', icon: 'link' },
  { key: 'map', label: 'Map', icon: 'map' },
  { key: 'plan', label: 'Plan', icon: 'calendar-days' },
  { key: 'travel', label: 'Travel', icon: 'plane' },
  { key: 'money', label: 'Money', icon: 'wallet' },
  { key: 'documents', label: 'Documents', icon: 'file-text' },
  { key: 'members', label: 'Members', icon: 'users' },
  { key: 'settings', label: 'Settings', icon: 'settings' },
];

/** Fixed left sidebar — desktop only. 10 items per the product nav spec, plus a trip switcher header. */
export function Sidebar({ active = 'home', onChange, tripName = 'Japan, November', iconBase = '' }) {
  const icon = (name) => ({
    width: 19,
    height: 19,
    display: 'inline-block',
    backgroundColor: 'currentColor',
    WebkitMaskImage: `url(${iconBase}assets/icons/${name}.svg)`,
    maskImage: `url(${iconBase}assets/icons/${name}.svg)`,
    WebkitMaskSize: 'contain',
    maskSize: 'contain',
    WebkitMaskRepeat: 'no-repeat',
    maskRepeat: 'no-repeat',
    WebkitMaskPosition: 'center',
    maskPosition: 'center',
    flexShrink: 0,
  });
  return (
    <aside
      style={{
        width: 'var(--sidebar-width)',
        background: 'var(--color-bg-raised)',
        borderRight: '1px solid var(--color-border)',
        display: 'flex',
        flexDirection: 'column',
        height: '100%',
        flexShrink: 0,
      }}
    >
      <div style={{ padding: 'var(--space-5)', display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ width: 30, height: 30, borderRadius: 9, background: 'var(--color-primary)', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#fff', fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 16 }}>W</span>
        <div style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.2 }}>
          <span style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)' }}>{tripName}</span>
          <span style={{ fontFamily: 'var(--font-sans)', fontSize: 11, color: 'var(--color-text-tertiary)' }}>Wabway trip</span>
        </div>
      </div>
      <nav style={{ display: 'flex', flexDirection: 'column', gap: 2, padding: '0 var(--space-3)' }}>
        {NAV_ITEMS.map((item) => {
          const isActive = item.key === active;
          return (
            <button
              key={item.key}
              onClick={() => onChange && onChange(item.key)}
              style={{
                display: 'flex',
                alignItems: 'center',
                gap: 12,
                height: 42,
                padding: '0 12px',
                borderRadius: 'var(--radius-sm)',
                border: 'none',
                cursor: 'pointer',
                background: isActive ? 'var(--color-primary-soft)' : 'transparent',
                color: isActive ? 'var(--color-primary-dark)' : 'var(--color-text-secondary)',
                fontFamily: 'var(--font-sans)',
                fontWeight: isActive ? 'var(--weight-semibold)' : 'var(--weight-medium)',
                fontSize: 'var(--text-base)',
                textAlign: 'left',
              }}
            >
              <span style={icon(item.icon)} />
              {item.label}
            </button>
          );
        })}
      </nav>
    </aside>
  );
}
