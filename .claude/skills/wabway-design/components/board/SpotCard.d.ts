import * as React from 'react';

export interface SpotCardProps {
  name: string;
  city: string;
  category: string;
  status?: 'Idea' | 'Want to go' | 'Must-do' | 'Planned' | 'Booked' | 'Skipped';
  /** Photo URL — falls back to the warm PhotoSlot placeholder when omitted. */
  photo?: string;
  /** e.g. { must: 2, want: 1 } — renders one selected VoteChip per non-zero key. */
  votes?: Record<string, number>;
  addedBy?: string;
  iconBase?: string;
  onClick?: () => void;
}
