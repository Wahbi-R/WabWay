import * as React from 'react';

export interface SplitMemberRowProps {
  name: string;
  amount: string;
  currency?: string;
  selected?: boolean;
  onToggle?: (checked: boolean) => void;
  /** Shows an editable amount input — used for "Custom amount" split mode instead of "Equal". */
  editable?: boolean;
  onAmountChange?: (e: React.ChangeEvent<HTMLInputElement>) => void;
}
