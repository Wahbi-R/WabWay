Centered modal with scrim — "Add receipt", "Settle up", confirmation prompts.

```jsx
<Dialog open={open} title="Settle up with Alex" onClose={close} footer={<><Button variant="ghost" onClick={close}>Cancel</Button><Button variant="primary">Mark as paid</Button></>}>
  …form…
</Dialog>
```
