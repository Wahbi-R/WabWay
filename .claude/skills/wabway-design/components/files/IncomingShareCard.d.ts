import * as React from 'react';

export interface IncomingShareCardProps {
  /** What Wabway detected was shared in, e.g. "Instagram link", "PDF file", "Google Maps link". */
  detectedLabel: string;
  tripName: string;
  destinationOptions: { value: string; label: string }[];
  onSave?: () => void;
  iconBase?: string;
}
