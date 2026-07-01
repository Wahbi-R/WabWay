import * as React from 'react';

export interface SidebarProps {
  active?: 'home' | 'spots' | 'links' | 'map' | 'plan' | 'travel' | 'money' | 'documents' | 'members' | 'settings';
  onChange?: (key: string) => void;
  tripName?: string;
  iconBase?: string;
}
