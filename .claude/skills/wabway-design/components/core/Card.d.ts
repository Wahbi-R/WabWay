import * as React from 'react';

export interface CardProps {
  padding?: string;
  /** Lifts the shadow on hover — use for clickable/navigable cards. */
  hoverable?: boolean;
  /** Outlines the card in primary color — used for a selected row in a list/detail layout. */
  selected?: boolean;
  onClick?: () => void;
  children: React.ReactNode;
}

export interface PhotoSlotProps {
  icon: React.ReactNode;
  label?: string;
  aspect?: string;
}
