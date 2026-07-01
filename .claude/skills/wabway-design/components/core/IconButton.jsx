import React from 'react';

export function IconButton({ icon, label, size = 'md', variant = 'ghost', active = false, style, onClick, ...rest }) {
  const dims = { sm: 32, md: 44, lg: 52 }[size];
  const [hover, setHover] = React.useState(false);
  const solid = variant === 'solid';
  return (
    <button
      aria-label={label}
      title={label}
      onClick={onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => setHover(false)}
      style={{
        width: dims,
        height: dims,
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        borderRadius: 'var(--radius-pill)',
        border: solid ? '1px solid transparent' : '1px solid transparent',
        background: solid
          ? (hover ? 'var(--color-primary-hover)' : 'var(--color-primary)')
          : active
          ? 'var(--color-primary-soft)'
          : hover
          ? 'var(--color-surface-sunken)'
          : 'transparent',
        color: solid ? 'var(--color-text-on-primary)' : active ? 'var(--color-primary-dark)' : 'var(--color-text-secondary)',
        cursor: 'pointer',
        transition: 'background var(--duration-fast) var(--ease-standard)',
        ...style,
      }}
      {...rest}
    >
      <span style={{ width: dims * 0.45, height: dims * 0.45, display: 'inline-flex' }}>{icon}</span>
    </button>
  );
}
