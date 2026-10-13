# Shared UI primitives (reuse pass)

## Why
An external UX audit (Muse, Oct 2026) found ~20 places where the same UI element was
built differently per screen. Code exploration confirmed the cause: private copies
(`_confirmDelete`, `_DateField`, `_snack`, `_initials`, per-sheet
`showModalBottomSheet(DraggableScrollableSheet…)` boilerplate) instead of shared widgets.

## What changed (build 405)
Each primitive was **promoted from an existing implementation**, not written fresh:

| Primitive | Promoted from | Replaced |
|---|---|---|
| `showWabwayConfirm` / `showWabwayDeleteConfirm` | trip-deletion dialog (`more_screen`) | 6 private confirm fns, ~15 inline `AlertDialog`s |
| `showWabwayTextPrompt` | doc rename dialog | 2× doc rename, packing add/rename, pin post |
| `showWabwaySnack` | `item_detail._snack` | 4 private `_snack`s |
| `WabwayDateField` / `WabwayTimeField` / `WabwayPickerField` | Trip settings `_DateField` | 5 date fields, 2 time pickers |
| `showWabwayFormSheet` / `showWabwayAutoSheet` | Add Spot's desktop/mobile switch | 10 add/settings sheets |
| `WabwayChoiceChips` | Links category chip row | Links category, Stays status |
| `DocMultiPicker` | Plan item docs picker | Travel docs picker |
| `initialsFor`, `avatarColorFor`, `pluralize`, `foldForSearch` | `WabwayAvatar._initials` | 7 initials impls, 3 palettes |
| `isOrganiserProvider`, `canManageItem` | `spots_screen._canDelete` | 5 inline owner checks |
| `confirmDeleteTrip` / `confirmLeaveTrip` / `confirmRemoveMember` | `more_screen` | duplicate copies in `placeholder_screen` |

## Rules (also in CLAUDE.md → "Canonical components")
- Delete copy: **"Delete {entity}?" / "This will permanently remove "{name}". This cannot be undone."**
- Forms: dialog on desktop, bottom sheet with drag handle on mobile — decided by the helper, never per screen.
- Avatars always get the real display name; "You" is a label, not a name.
- `WabwayButton.dangerOutline` for delete in panels/forms; filled `danger` only inside confirm dialogs.

## Build 408 — consistency sweep (Muse spec §1–20)
| Spec § | Result |
|---|---|
| 1, 13 Primary add | `WabwayAddFab` on mobile, `WabwayHeaderAddButton` on desktop (same label). Plan's icon cluster → overflow menu. |
| 2, 15 Empty states | Every first-run empty state and "Select a…" pane has the screen's add CTA. |
| 7, 9 Destructive | `dangerOutline` everywhere in panels; one delete per receipt/withdrawal. |
| 10 Tabs | `TabBar` (with controller) or `WabwaySegmentTabs` (state-driven) — no pills/segmented. |
| 10 Filters | `WabwayFilterStrip` with counts (Docs, Travel). |
| 11 Search | `WabwaySearchBar` always visible (Spots). |
| 12 CTA colour | Orange primary for Find Me / Create trip; red only for destructive. |
| 14 Labels | "(optional)" suffix convention. |
| 5 Pickers | `WabwayChoiceChips` for travel type/status, receipt category. |
| 17 Votes | List card highlights your vote with the same chip as the detail screen. |
| 18 Trip rows | `TripListTile`. |
| 20 Toasts | `showWabwaySnack` (76 call sites converted). |

Muse ≠ code notes: trip switcher buttons were already `WabwayButton` (variant only);
Links search already showed whenever content exists; mobile keeps FABs and drag
handles (adaptive decision).
