Single-color icon glyph from the Lucide set shipped in `assets/icons/`. Recolors via CSS mask, so it always inherits the surrounding text/icon color.

```jsx
<Icon src="../../assets/icons/map-pin.svg" size={18} color="var(--color-primary)" />
```

The `src` path is relative to wherever you render it — count the folders back to the project root, same way you'd link `styles.css`. See the Iconography section of `readme.md` for the full available set and usage rules (size defaults, left-of-label placement, never recolored per-icon outside semantic context).
