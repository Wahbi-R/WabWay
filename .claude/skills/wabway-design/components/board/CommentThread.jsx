import React from 'react';
import { Avatar } from '../core/Avatar.jsx';
import { VoteChip } from './VoteChip.jsx';

/** Comment thread for a spot — each comment optionally tagged with that person's vote. */
export function CommentThread({ comments }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
      {comments.map((c, i) => (
        <div key={i} style={{ display: 'flex', gap: 'var(--space-3)' }}>
          <Avatar name={c.author} size="sm" />
          <div style={{ flex: 1 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-sm)', color: 'var(--color-text-primary)' }}>{c.author}</span>
              {c.vote && <VoteChip vote={c.vote} selected />}
              <span style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-xs)', color: 'var(--color-text-tertiary)' }}>{c.time}</span>
            </div>
            <p style={{ margin: '4px 0 0', fontFamily: 'var(--font-sans)', fontSize: 'var(--text-base)', color: 'var(--color-text-secondary)', lineHeight: 'var(--leading-normal)' }}>
              {c.text}
            </p>
          </div>
        </div>
      ))}
    </div>
  );
}
