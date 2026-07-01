import * as React from 'react';

export interface TopBarProps {
  title: string;
  /** Right-aligned slot — search, primary action, avatar. */
  children?: React.ReactNode;
}
