import React from 'react';

/** Overlapping stack of member avatars with a "+N" overflow bubble. */
export function MemberAvatarRow({ members, max = 4, size = 'sm' }) {
  const shown = members.slice(0, max);
  const overflow = members.length - shown.length;
  const px = { xs: 22, sm: 28, md: 36 }[size] || 28;
  return (
    <div style={{ display: 'flex', alignItems: 'center' }}>
      {shown.map((m, i) => (
        <span key={m.name} style={{ marginLeft: i === 0 ? 0 : -8, zIndex: shown.length - i }}>
          <AvatarDot name={m.name} src={m.src} size={px} />
        </span>
      ))}
      {overflow > 0 && (
        <span
          style={{
            marginLeft: -8,
            width: px,
            height: px,
            borderRadius: '50%',
            background: 'var(--color-surface-sunken)',
            color: 'var(--color-text-secondary)',
            border: '2px solid var(--color-surface)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontFamily: 'var(--font-sans)',
            fontWeight: 'var(--weight-semibold)',
            fontSize: px * 0.36,
          }}
        >
          +{overflow}
        </span>
      )}
    </div>
  );
}

const PALETTE = ['#C96F4A', '#7D9A75', '#D6A84F', '#9F4F34', '#6F8FA8', '#B07AA0'];
function hash(name = '') {
  let h = 0;
  for (let i = 0; i < name.length; i++) h = (h * 31 + name.charCodeAt(i)) >>> 0;
  return h;
}
function AvatarDot({ name, src, size }) {
  const initials = name.split(' ').filter(Boolean).slice(0, 2).map((p) => p[0].toUpperCase()).join('');
  const color = PALETTE[hash(name) % PALETTE.length];
  return (
    <span
      style={{
        width: size,
        height: size,
        borderRadius: '50%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: src ? 'var(--color-surface-sunken)' : color,
        color: '#fff',
        border: '2px solid var(--color-surface)',
        fontFamily: 'var(--font-sans)',
        fontWeight: 'var(--weight-semibold)',
        fontSize: size * 0.36,
        overflow: 'hidden',
      }}
    >
      {src ? <img src={src} alt={name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} /> : initials}
    </span>
  );
}
