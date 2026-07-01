import React from 'react';

/** Generic surface container — the base every domain card (SpotCard, ReceiptCard, …) builds on. */
export function Card({ children, padding = 'var(--space-5)', hoverable = false, selected = false, style, onClick }) {
  const [hover, setHover] = React.useState(false);
  return (
    <div
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        background: 'var(--color-surface)',
        borderRadius: 'var(--radius-lg)',
        border: `1px solid ${selected ? 'var(--color-primary)' : 'var(--color-border)'}`,
        boxShadow: hoverable && hover ? 'var(--shadow-md)' : 'var(--shadow-sm)',
        padding,
        cursor: onClick ? 'pointer' : 'default',
        transition: 'box-shadow var(--duration-base) var(--ease-standard), border-color var(--duration-base) var(--ease-standard)',
        ...style,
      }}
    >
      {children}
    </div>
  );
}

/** Warm tinted placeholder used wherever a photo hasn't been added yet (trip cover, spot photo). */
export function PhotoSlot({ icon, label, aspect = '16/9', style }) {
  return (
    <div
      style={{
        aspectRatio: aspect,
        width: '100%',
        borderRadius: 'var(--radius-md)',
        background: 'linear-gradient(155deg, var(--color-primary-soft), var(--color-accent-soft))',
        border: '1px solid var(--color-border)',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 6,
        color: 'var(--color-text-tertiary)',
        ...style,
      }}
    >
      <span style={{ width: 28, height: 28, opacity: 0.7 }}>{icon}</span>
      {label && <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-xs)' }}>{label}</span>}
    </div>
  );
}
