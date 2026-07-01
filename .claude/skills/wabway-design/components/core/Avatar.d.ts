import * as React from 'react';

export interface AvatarProps {
  name: string;
  src?: string;
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  /** Adds a thin surface-colored ring — used when avatars overlap in a stack. */
  ring?: boolean;
}
