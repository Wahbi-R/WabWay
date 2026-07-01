import * as React from 'react';

export interface BadgeProps {
  tone?: 'neutral' | 'primary' | 'secondary' | 'accent' | 'success' | 'warning' | 'danger';
  icon?: React.ReactNode;
  children: React.ReactNode;
}
