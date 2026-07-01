import * as React from 'react';

export interface DialogProps {
  open: boolean;
  title?: string;
  onClose?: () => void;
  footer?: React.ReactNode;
  children: React.ReactNode;
}
