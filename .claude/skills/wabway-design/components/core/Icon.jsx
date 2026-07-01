import React from 'react';

/**
 * Renders one of the Lucide SVGs shipped in assets/icons as a single-color,
 * currentColor-able glyph (via CSS mask — the SVG file itself stays
 * untouched, so swapping the icon set later is a one-file change).
 */
export function Icon({ src, size = 20, color = 'currentColor', label, style }) {
  return (
    <span
      role={label ? 'img' : 'presentation'}
      aria-label={label}
      style={{
        display: 'inline-block',
        width: size,
        height: size,
        flexShrink: 0,
        backgroundColor: color,
        WebkitMaskImage: `url(${src})`,
        maskImage: `url(${src})`,
        WebkitMaskSize: 'contain',
        maskSize: 'contain',
        WebkitMaskRepeat: 'no-repeat',
        maskRepeat: 'no-repeat',
        WebkitMaskPosition: 'center',
        maskPosition: 'center',
        ...style,
      }}
    />
  );
}
