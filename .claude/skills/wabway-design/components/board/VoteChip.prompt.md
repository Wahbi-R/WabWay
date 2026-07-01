A spot's vote — Must-do / Want / Maybe / Skip, color-coded dot per option. Use `VoteChipGroup` for the full interactive row on a spot detail view; use a single `VoteChip` (non-interactive, no onClick) to show one person's vote in a list.

```jsx
<VoteChipGroup value={myVote} onChange={setMyVote} />
<VoteChip vote="must" selected />
```
