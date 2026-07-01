import * as React from 'react';

export interface CashWithdrawalCardProps {
  withdrawnBy: string;
  amount: string;
  atmFee?: string;
  currency?: string;
  dateLabel?: string;
  distributed?: { name: string; amount: string }[];
  iconBase?: string;
  onClick?: () => void;
}
