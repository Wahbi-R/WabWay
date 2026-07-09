# Unified Import & Share Screen

## Summary

Merged `_ImportSheet` (manual import bottom sheet) and `IncomingShareScreen` (Android share intent handler) into a single unified `IncomingShareScreen` that handles both flows from one place.

## Files Changed

- `lib/data/share_data.dart` — renamed `ShareDestination.itineraryNote` → `planItem`; updated label/description/icon/colors
- `lib/screens/share/share_form.dart` — `share` field made nullable; added `planDayId`/`planItemType` to `ShareSaveData`; all `widget.share.X` → `widget.share?.X`; switch cases updated to use `planItem`
- `lib/screens/share/incoming_share_screen.dart` — major rewrite; added import mode, source step, plan item form, `showImportScreen()` top-level function
- `lib/screens/home_screen.dart` — swapped import and call site to `showImportScreen()`
- `lib/screens/more_screen.dart` — same
- `lib/screens/import/import_sheet.dart` — deleted

## Modes

### Share mode (`share` param non-null)
Triggered by Android share intent. Behavior identical to before: shows `ContentPreviewCard`, destination selector, smart banners, and `ShareForm`.

### Import mode (`share` param null)
Triggered via `showImportScreen(context)` from Import buttons. Shows a source-picking step first:
- **Pick a file** — `FilePicker` with `withData: true`; bytes held in `_fileBytes`; content type inferred from extension
- **Add a photo** — `ImagePicker`; camera or gallery
- **URL / link** — text field + Continue button; `detectContentType()` determines type

After picking, an `IncomingShare` is synthesised and the flow proceeds identically to share mode.

## Plan Item Destination

`ShareDestination.planItem` (formerly `itineraryNote`) is now fully implemented in both modes:
- Selecting it triggers `_loadDays()` → `PlanService.loadAll(tripId)`
- Shows day picker (DropdownButton), type chips (`ItineraryItemType` values), title + notes fields
- `_savePlanItem()` uploads any file as a doc and calls `PlanService.createItem()` with `linkedDocIds`
- `ShareForm` is bypassed for this destination; the plan item form has its own Discard/Save buttons

## Navigation

- AppBar title: "Import" (import mode) or "Add to trip" (share mode)
- AppBar leading: back button (import mode, after source picked) resets `_activeShare`; close button otherwise
- `showImportScreen(context)` pushes a full-screen `MaterialPageRoute` (replaces the old bottom sheet approach)

## File bytes handling

In import mode, file bytes are held in `_fileBytes`/`_fileExt`/`_fileName` state. Scanning methods (`_parseWithAi`, `_parseWithOcr`) and save methods use `_fileBytes` directly when `filePath` is null, falling back to `readFileAsBytes(filePath)` for share-mode files. No temp file writes required.
