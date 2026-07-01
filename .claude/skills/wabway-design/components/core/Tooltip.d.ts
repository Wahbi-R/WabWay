import * as React from 'react';

export interface TooltipProps {
  label: string;
  side?: 'top' | 'bottom' | 'left' | 'right';
  children: React.ReactNode;
}
