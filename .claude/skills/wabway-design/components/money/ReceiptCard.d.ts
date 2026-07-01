import * as React from 'react';

export interface ReceiptCardProps {
  title: string;
  amount: string;
  currency?: string;
  paidBy: string;
  category: string;
  dateLabel?: string;
  splitCount: number;
  iconBase?: string;
  onClick?: () => void;
}
