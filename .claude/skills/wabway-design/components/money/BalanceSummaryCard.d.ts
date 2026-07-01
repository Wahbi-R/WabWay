import * as React from 'react';

export interface BalanceSummaryCardProps {
  youOwe?: { name: string; amount: string }[];
  youAreOwed?: { name: string; amount: string }[];
  currency?: string;
}
