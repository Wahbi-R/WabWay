import * as React from 'react';

export interface VoteChipProps {
  vote: 'must' | 'want' | 'maybe' | 'skip';
  selected?: boolean;
  onClick?: () => void;
}

export interface VoteChipGroupProps {
  value?: 'must' | 'want' | 'maybe' | 'skip';
  onChange?: (vote: string) => void;
}
