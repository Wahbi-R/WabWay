import React from 'react';

export function Tooltip({ label, children, side = 'top' }) {
  const [show, setShow] = React.useState(false);
  const pos =
    side === 'top'
      ? { bottom: '100%', left: '50%', transform: 'translateX(-50%)', marginBottom: 6 }
      : side === 'bottom'
      ? { top: '100%', left: '50%', transform: 'translateX(-50%)', marginTop: 6 }
      : side === 'left'
      ? { right: '100%', top: '50%', transform: 'translateY(-50%)', marginRight: 6 }
      : { left: '100%', top: '50%', transform: 'translateY(-50%)', marginLeft: 6 };

  return (
    <span
      style={{ position: 'relative', display: 'inline-flex' }}
      onMouseEnter={() => setShow(true)}
      onMouseLeave={() => setShow(false)}
    >
      {children}
      {show && (
        <span
          role="tooltip"
          style={{
            position: 'absolute',
            ...pos,
            background: 'var(--color-text-primary)',
            color: 'var(--color-surface)',
            fontFamily: 'var(--font-sans)',
            fontSize: 'var(--text-xs)',
            fontWeight: 'var(--weight-medium)',
            padding: '5px 10px',
            borderRadius: 'var(--radius-xs)',
            whiteSpace: 'nowrap',
            boxShadow: 'var(--shadow-sm)',
            zIndex: 20,
            pointerEvents: 'none',
          }}
        >
          {label}
        </span>
      )}
    </span>
  );
}
