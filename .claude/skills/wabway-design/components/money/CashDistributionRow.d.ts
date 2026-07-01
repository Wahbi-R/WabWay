import * as React from 'react';

export interface CashDistributionRowProps {
  name: string;
  amount: string;
  currency?: string;
  editable?: boolean;
  onAmountChange?: (e: React.ChangeEvent<HTMLInputElement>) => void;
}
