import * as React from 'react';

export interface MemberAvatarRowProps {
  members: { name: string; src?: string }[];
  /** How many avatars to show before collapsing the rest into a "+N" bubble. */
  max?: number;
  size?: 'xs' | 'sm' | 'md';
}
