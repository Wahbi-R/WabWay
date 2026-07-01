import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { Badge } from '../core/Badge.jsx';

const SOURCE_ICON = {
  maps: 'map-pin',
  instagram: 'link-2',
  tiktok: 'link-2',
  youtube: 'link-2',
  blog: 'link-2',
  other: 'link',
};

/** A pasted-in link from Instagram/TikTok/Maps/YouTube/a blog — lighter-weight than a full SpotCard. */
export function LinkPreviewCard({ title, sourceLabel, sourceType = 'other', notes, addedBy, iconBase = '../../', onClick }) {
  return (
    <div
      onClick={onClick}
      style={{
        display: 'flex',
        gap: 'var(--space-3)',
        alignItems: 'flex-start',
        padding: 'var(--space-4)',
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-lg)',
        boxShadow: 'var(--shadow-sm)',
        cursor: onClick ? 'pointer' : 'default',
      }}
    >
      <span
        style={{
          width: 38,
          height: 38,
          borderRadius: 'var(--radius-sm)',
          background: 'var(--color-secondary-soft)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        <Icon src={`${iconBase}assets/icons/${SOURCE_ICON[sourceType] || 'link'}.svg`} size={18} color="color-mix(in oklch, var(--color-secondary) 55%, black)" />
      </span>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-semibold)', fontSize: 'var(--text-base)', color: 'var(--color-text-primary)' }}>
          {title}
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 2 }}>
          <Badge tone="neutral">{sourceLabel}</Badge>
        </div>
        {notes && (
          <div style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)', marginTop: 6 }}>{notes}</div>
        )}
      </div>
    </div>
  );
}
