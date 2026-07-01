import React from 'react';

const SIZE_PX = { xs: 22, sm: 28, md: 36, lg: 48, xl: 64 };
const PALETTE = ['#C96F4A', '#7D9A75', '#D6A84F', '#9F4F34', '#6F8FA8', '#B07AA0'];

function hashName(name = '') {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  return h;
}

export function Avatar({ name = '', src, size = 'md', ring = false }) {
  const px = SIZE_PX[size];
  const initials = name
    .split(' ')
    .filter(Boolean)
    .slice(0, 2)
    .map((p) => p[0].toUpperCase())
    .join('');
  const color = PALETTE[hashName(name) % PALETTE.length];

  return (
    <span
      style={{
        width: px,
        height: px,
        borderRadius: '50%',
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: src ? 'var(--color-surface-sunken)' : color,
        color: 'var(--color-text-on-primary)',
        fontFamily: 'var(--font-sans)',
        fontWeight: 'var(--weight-semibold)',
        fontSize: px * 0.4,
        flexShrink: 0,
        overflow: 'hidden',
        boxShadow: ring ? '0 0 0 2px var(--color-surface)' : 'none',
      }}
    >
      {src ? (
        <img src={src} alt={name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
      ) : (
        initials || '?'
      )}
    </span>
  );
}
