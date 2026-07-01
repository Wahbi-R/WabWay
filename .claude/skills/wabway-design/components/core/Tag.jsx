import React from 'react';

/** A removable filter/category chip — distinct from Badge (status) and VoteChip (voting). */
export function Tag({ children, selected = false, onRemove, onClick }) {
  return (
    <span
      onClick={onClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        height: 30,
        padding: '0 12px',
        borderRadius: 'var(--radius-pill)',
        background: selected ? 'var(--color-primary)' : 'var(--color-surface)',
        color: selected ? 'var(--color-text-on-primary)' : 'var(--color-text-primary)',
        border: `1px solid ${selected ? 'transparent' : 'var(--color-border)'}`,
        fontFamily: 'var(--font-sans)',
        fontWeight: 'var(--weight-medium)',
        fontSize: 'var(--text-sm)',
        cursor: onClick ? 'pointer' : 'default',
        userSelect: 'none',
      }}
    >
      {children}
      {onRemove && (
        <button
          onClick={(e) => { e.stopPropagation(); onRemove(); }}
          aria-label="Remove"
          style={{
            border: 'none',
            background: 'transparent',
            color: 'inherit',
            opacity: 0.65,
            cursor: 'pointer',
            padding: 0,
            font: 'inherit',
            lineHeight: 1,
          }}
        >
          ×
        </button>
      )}
    </span>
  );
}
