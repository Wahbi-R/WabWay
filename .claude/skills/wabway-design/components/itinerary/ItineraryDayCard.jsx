import React from 'react';
import { Icon } from '../core/Icon.jsx';

/** One day of the itinerary — a date/city header plus an ordered list of timed items. */
export function ItineraryDayCard({ date, city, items = [], iconBase = '../../' }) {
  return (
    <div
      style={{
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-sm)',
        overflow: 'hidden',
      }}
    >
      <div
        style={{
          display: 'flex',
          alignItems: 'baseline',
          gap: 10,
          padding: 'var(--space-4) var(--space-5)',
          background: 'var(--color-primary-soft)',
          borderBottom: '1px solid var(--color-border)',
        }}
      >
        <span style={{ fontFamily: 'var(--font-serif)', fontWeight: 600, fontSize: 'var(--text-lg)', color: 'var(--color-primary-dark)' }}>{date}</span>
        <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>{city}</span>
      </div>
      <div style={{ display: 'flex', flexDirection: 'column' }}>
        {items.map((it, i) => (
          <div key={i} style={{ display: 'flex', gap: 'var(--space-4)', padding: 'var(--space-4) var(--space-5)', borderBottom: i < items.length - 1 ? '1px solid var(--color-border)' : 'none' }}>
            <div style={{ width: 64, flexShrink: 0, fontFamily: 'var(--font-mono)', fontSize: 'var(--text-xs)', color: 'var(--color-text-tertiary)', paddingTop: 2 }}>{it.time}</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>{it.title}</div>
              {it.notes && <div style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)', marginTop: 2 }}>{it.notes}</div>}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
