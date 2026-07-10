# CSV File Support + File Type Registry

## What changed

### User-visible
- WabWay now appears in the Android share menu for `.csv`, `.xls`, and `.xlsx` files
- Picking a CSV in the in-app import picker goes straight to the Takeout import screen
- Sharing a CSV from a file manager shows an "Import spots from CSV" action banner

### Internal
- `lib/core/share/file_type_registry.dart` — single source of truth for all accepted file extensions and their `ShareContentType` mapping
- `FileTypeRegistry.shareExtensions` — list used by the import/share file picker
- `FileTypeRegistry.docExtensions` — list used by the add-document file picker
- `FileTypeRegistry.contentTypeFromExt(ext)` — replaces duplicated switch logic in `incoming_share_screen.dart` and `share_handler_native.dart`
- `AndroidManifest.xml` has a comment pointing to the registry so MIME types stay in sync

## Adding a new file type

1. Add the extension to the relevant list(s) in `FileTypeRegistry`
2. Add a case to `contentTypeFromExt` if it needs a distinct `ShareContentType`
3. Add the MIME type as an intent-filter in `AndroidManifest.xml` (comment there points here)
4. If it needs special handling in `_pickFile`, add a branch after the `csv` check
