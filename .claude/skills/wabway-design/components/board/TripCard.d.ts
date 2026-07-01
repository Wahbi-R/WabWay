import * as React from 'react';

export interface TripCardProps {
  name: string;
  destination: string;
  dateRange: string;
  cover?: string;
  members?: { name: string; src?: string }[];
  iconBase?: string;
  onClick?: () => void;
}
