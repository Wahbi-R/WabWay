Round icon-only button for toolbars, nav bars, and card actions.

```jsx
<IconButton icon={<Icon name="more-horizontal" />} label="More options" />
<IconButton icon={<Icon name="plus" />} label="Add" variant="solid" />
```

`ghost` (default) is transparent with a soft hover tint — used in nav and toolbars. `solid` is a filled primary circle — used sparingly for one floating-style add action. `active` tints the background to show a current/selected icon (e.g. the active bottom-nav tab, handled by BottomNav itself — use `active` directly only for ad-hoc icon toggles).
