Rounded-square checkbox — selecting members to split a receipt with.

```jsx
<Checkbox label="Alex Kim" checked={selected.has('alex')} onChange={() => toggle('alex')} />
```

The one hand-drawn-shape exception in this system: the checkmark itself is a tiny inline SVG path (not a Lucide import) since it must sit exactly inside the 22px box — everything else uses the Icon component.
