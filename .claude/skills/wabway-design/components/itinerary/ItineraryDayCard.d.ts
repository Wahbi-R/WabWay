import * as React from 'react';

export interface ItineraryDayCardProps {
  date: string;
  city: string;
  items: { time?: string; title: string; notes?: string }[];
  iconBase?: string;
}
