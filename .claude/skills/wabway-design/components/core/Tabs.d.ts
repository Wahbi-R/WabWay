import * as React from 'react';

export interface TabsProps {
  tabs: { value: string; label: string }[];
  value: string;
  onChange: (value: string) => void;
}
