import * as React from 'react';

export interface TagProps {
  selected?: boolean;
  onRemove?: () => void;
  onClick?: () => void;
  children: React.ReactNode;
}
