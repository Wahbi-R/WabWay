import * as React from 'react';

export interface DocumentTileProps {
  title: string;
  type?: 'Hotel' | 'Flight' | 'Train' | 'Ticket' | 'Reservation' | 'Receipt' | 'Insurance' | 'Form' | 'Screenshot' | 'Other';
  dateLabel?: string;
  iconBase?: string;
  onClick?: () => void;
}
