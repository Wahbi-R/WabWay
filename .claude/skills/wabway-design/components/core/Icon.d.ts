import * as React from 'react';

export interface IconProps {
  /** Path to the icon SVG, relative to the file rendering it — e.g. "../../assets/icons/map-pin.svg". */
  src: string;
  size?: number;
  /** Any CSS color or token, e.g. "var(--color-text-secondary)". Defaults to inherited text color. */
  color?: string;
  /** Accessible label — omit for purely decorative icons next to visible text. */
  label?: string;
}
