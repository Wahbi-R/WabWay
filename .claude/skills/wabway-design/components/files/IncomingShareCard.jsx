import React from 'react';
import { Icon } from '../core/Icon.jsx';
import { Select } from '../forms/Select.jsx';
import { Input } from '../forms/Input.jsx';
import { Textarea } from '../forms/Textarea.jsx';
import { Button } from '../core/Button.jsx';

const TYPE_ICON = { 'PDF file': 'file-text', 'Instagram link': 'link-2', 'Google Maps link': 'map-pin', 'Image': 'image' };

/**
 * The incoming-share intake screen — what a person sees right after sharing a
 * link/file into Wabway from another app (Instagram, Google Maps, Gmail, Files…).
 */
export function IncomingShareCard({ detectedLabel, tripName, destinationOptions, onSave, iconBase = '../../' }) {
  return (
    <div
      style={{
        background: 'var(--color-surface)',
        border: '1px solid var(--color-border)',
        borderRadius: 'var(--radius-xl)',
        boxShadow: 'var(--shadow-lg)',
        padding: 'var(--space-6)',
        display: 'flex',
        flexDirection: 'column',
        gap: 'var(--space-4)',
        maxWidth: 380,
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ width: 38, height: 38, borderRadius: 'var(--radius-sm)', background: 'var(--color-secondary-soft)', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
          <Icon src={`${iconBase}assets/icons/${TYPE_ICON[detectedLabel] || 'link'}.svg`} size={18} color="color-mix(in oklch, var(--color-secondary) 55%, black)" />
        </span>
        <div>
          <div style={{ fontFamily: 'var(--font-sans)', fontWeight: 'var(--weight-bold)', fontSize: 'var(--text-lg)', color: 'var(--color-text-primary)' }}>Incoming share</div>
          <div style={{ fontFamily: 'var(--font-sans)', fontSize: 'var(--text-sm)', color: 'var(--color-text-secondary)' }}>Detected: {detectedLabel}</div>
        </div>
      </div>
      <Select label="Add to" options={destinationOptions} placeholder="Choose a destination" />
      <Input label="Trip" value={tripName} onChange={() => {}} disabled />
      <Input label="Title" placeholder="Instagram reel" />
      <Textarea label="Notes" placeholder="Looks like a ramen spot near Shinjuku." rows={2} />
      <Button variant="primary" fullWidth onClick={onSave}>Save</Button>
    </div>
  );
}
