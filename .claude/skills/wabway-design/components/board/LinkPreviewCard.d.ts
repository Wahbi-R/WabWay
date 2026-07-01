import * as React from 'react';

export interface LinkPreviewCardProps {
  title: string;
  /** Display label for the source, e.g. "Instagram", "Google Maps". */
  sourceLabel: string;
  sourceType?: 'maps' | 'instagram' | 'tiktok' | 'youtube' | 'blog' | 'other';
  notes?: string;
  addedBy?: string;
  iconBase?: string;
  onClick?: () => void;
}
