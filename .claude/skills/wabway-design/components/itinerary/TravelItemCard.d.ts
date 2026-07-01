import * as React from 'react';

export interface TravelItemCardProps {
  type: 'Flight' | 'Hotel' | 'Train' | 'Ticket' | 'Reservation';
  title: string;
  subtitle?: string;
  confirmationNumber?: string;
  iconBase?: string;
  onClick?: () => void;
}
