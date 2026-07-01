import * as React from 'react';

export interface ButtonProps {
  /** Visual style. primary/secondary are solid CTAs, ghost is for secondary actions, danger for destructive ones. */
  variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
  /** Height/padding/font scale. */
  size?: 'sm' | 'md' | 'lg';
  /** Stretches to fill its container — common for the single primary action on a mobile screen. */
  fullWidth?: boolean;
  disabled?: boolean;
  /** Shows a spinner in place of the icon and ignores clicks. */
  loading?: boolean;
  /** Optional leading icon (18px). */
  icon?: React.ReactNode;
  children: React.ReactNode;
  onClick?: () => void;
}
