import * as React from 'react';

export interface IconButtonProps {
  icon: React.ReactNode;
  /** Accessible label, also shown as a title tooltip. */
  label: string;
  size?: 'sm' | 'md' | 'lg';
  /** ghost = transparent/hover-tint (default, used in toolbars/nav), solid = filled primary circle (used for a floating-style add action). */
  variant?: 'ghost' | 'solid';
  /** Tints the background to indicate a selected/current state (e.g. active nav icon). */
  active?: boolean;
  onClick?: () => void;
}
