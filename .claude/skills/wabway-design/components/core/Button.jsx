import React from 'react';

/**
 * @typedef {Object} ButtonProps
 * @property {'primary'|'secondary'|'ghost'|'danger'} [variant]
 * @property {'sm'|'md'|'lg'} [size]
 * @property {boolean} [fullWidth]
 * @property {boolean} [disabled]
 * @property {boolean} [loading]
 * @property {React.ReactNode} [icon]
 * @property {React.ReactNode} children
 */

const SIZES = {
  sm: { height: 36, padX: 14, font: 'var(--text-sm)', gap: 6, radius: 'var(--radius-sm)' },
  md: { height: 'var(--tap-target-min)', padX: 20, font: 'var(--text-base)', gap: 8, radius: 'var(--radius-md)' },
  lg: { height: 'var(--tap-target-comfortable)', padX: 26, font: 'var(--text-md)', gap: 10, radius: 'var(--radius-md)' },
};

const VARIANTS = {
  primary: {
    background: 'var(--color-primary)',
    backgroundHover: 'var(--color-primary-hover)',
    backgroundActive: 'var(--color-primary-active)',
    color: 'var(--color-text-on-primary)',
    border: '1px solid transparent',
  },
  secondary: {
    background: 'var(--color-secondary)',
    backgroundHover: 'var(--color-secondary-hover)',
    backgroundActive: 'var(--color-secondary-active)',
    color: 'var(--color-text-on-primary)',
    border: '1px solid transparent',
  },
  ghost: {
    background: 'transparent',
    backgroundHover: 'var(--color-primary-soft)',
    backgroundActive: 'var(--color-primary-soft-border)',
    color: 'var(--color-primary-dark)',
    border: '1px solid var(--color-border)',
  },
  danger: {
    background: 'var(--color-danger)',
    backgroundHover: 'var(--color-danger-hover)',
    backgroundActive: 'var(--color-danger-hover)',
    color: 'var(--color-text-on-primary)',
    border: '1px solid transparent',
  },
};

/** Primary call-to-action button. Also fills the "PrimaryActionButton" role from the product spec when used with variant="primary" size="lg" fullWidth. */
export function Button({
  variant = 'primary',
  size = 'md',
  fullWidth = false,
  disabled = false,
  loading = false,
  icon = null,
  children,
  style,
  onClick,
  ...rest
}) {
  const s = SIZES[size];
  const v = VARIANTS[variant];
  const [hover, setHover] = React.useState(false);
  const [active, setActive] = React.useState(false);

  const bg = disabled
    ? 'var(--color-border)'
    : active
    ? v.backgroundActive
    : hover
    ? v.backgroundHover
    : v.background;

  return (
    <button
      onClick={disabled || loading ? undefined : onClick}
      onMouseEnter={() => setHover(true)}
      onMouseLeave={() => { setHover(false); setActive(false); }}
      onMouseDown={() => setActive(true)}
      onMouseUp={() => setActive(false)}
      disabled={disabled}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        justifyContent: 'center',
        gap: s.gap,
        height: s.height,
        padding: `0 ${s.padX}px`,
        width: fullWidth ? '100%' : undefined,
        fontFamily: 'var(--font-sans)',
        fontWeight: 'var(--weight-semibold)',
        fontSize: s.font,
        borderRadius: s.radius,
        background: bg,
        color: disabled ? 'var(--color-text-tertiary)' : v.color,
        border: v.border,
        cursor: disabled || loading ? 'not-allowed' : 'pointer',
        opacity: loading ? 0.75 : 1,
        boxShadow: variant !== 'ghost' && !disabled ? 'var(--shadow-xs)' : 'none',
        transition: `background var(--duration-fast) var(--ease-standard), box-shadow var(--duration-fast) var(--ease-standard)`,
        whiteSpace: 'nowrap',
        ...style,
      }}
      {...rest}
    >
      {loading ? (
        <span
          style={{
            width: 14,
            height: 14,
            borderRadius: '50%',
            border: '2px solid currentColor',
            borderTopColor: 'transparent',
            display: 'inline-block',
            animation: 'wabway-spin 0.7s linear infinite',
          }}
        />
      ) : icon ? (
        <span style={{ display: 'inline-flex', width: 18, height: 18 }}>{icon}</span>
      ) : null}
      {children}
      <style>{`@keyframes wabway-spin { to { transform: rotate(360deg); } }`}</style>
    </button>
  );
}
