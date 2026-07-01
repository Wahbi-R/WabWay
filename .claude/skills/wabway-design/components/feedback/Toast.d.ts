import * as React from 'react';

export interface ToastProps {
  message: string;
  tone?: 'default' | 'success' | 'danger';
  icon?: React.ReactNode;
  onClose?: () => void;
}
