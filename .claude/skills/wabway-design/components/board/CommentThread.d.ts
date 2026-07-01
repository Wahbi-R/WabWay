import * as React from 'react';

export interface CommentThreadProps {
  comments: { author: string; text: string; time: string; vote?: 'must' | 'want' | 'maybe' | 'skip' }[];
}
