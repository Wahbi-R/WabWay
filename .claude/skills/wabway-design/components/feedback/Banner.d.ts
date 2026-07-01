import * as React from 'react';

export interface BannerProps {
  icon?: React.ReactNode;
  tone?: 'info' | 'success' | 'warning' | 'danger';
  action?: React.ReactNode;
  children: React.ReactNode;
}
