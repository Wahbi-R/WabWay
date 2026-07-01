Primary call-to-action button used for the one main action on a screen — "Add a spot", "Save", "Settle up" — and for secondary/ghost/danger actions via `variant`.

```jsx
<Button variant="primary" size="lg" fullWidth>Add a spot</Button>
<Button variant="ghost" icon={<Icon name="filter" />}>Filter</Button>
<Button variant="danger" size="sm">Remove member</Button>
```

Variants: `primary` (terracotta solid), `secondary` (sage solid), `ghost` (outlined, transparent fill, terracotta text), `danger` (brick red solid). Sizes: `sm` (36px, dense rows/toolbars), `md` (44px, default), `lg` (52px, the one primary action per mobile screen). Supports `icon`, `loading`, `disabled`, and `fullWidth`. This is the component referenced as `PrimaryActionButton` in the original product spec — use `variant="primary" size="lg" fullWidth`.
