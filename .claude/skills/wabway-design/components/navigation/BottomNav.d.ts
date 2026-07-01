import * as React from 'react';

export interface BottomNavProps {
  active?: 'spots' | 'plan' | 'money' | 'docs' | 'more';
  onChange?: (key: string) => void;
  /** Path prefix to assets/icons/ relative to the page rendering this — same convention as Icon's src. */
  iconBase?: string;
}
