# Document Image Thumbnails

## What it does

Image documents (jpg, jpeg, png, webp) now show a real content preview in the docs grid and list instead of a plain colour block with a file-type icon. The thumbnail loads fast because it is served from Supabase's CDN — the image is resized on first access and cached globally after that.

## How it works

### Supabase Storage image transforms

`DocService.getThumbnailUrl(storagePath, ext)` calls `createSignedUrl` with `TransformOptions(width: 400, height: 280, resize: ResizeMode.cover)`. Supabase resizes the original file on first request and caches the result on the CDN — subsequent loads are near-instant regardless of the original file size.

A static `_thumbCache` map ensures the Dart side only creates one signed URL future per storage path per session. The URL is valid for 1 hour.

Non-image file types (pdf, etc.) return `null` immediately — no Supabase call made.

### UI integration

**DocGridCard** (mobile 2-col grid): the 80px header area is now a `FutureBuilder`. While the URL resolves it shows the existing solid-colour icon. When the URL is ready it renders `Image.network` inside a `ClipRRect` with a 200ms fade-in. On error it falls back to the icon. The ext badge is overlaid in the top-right corner.

**DocListRow** (desktop left panel): the 44×44 leading square uses the same pattern — `FutureBuilder` → image or icon fallback — inside a `ClipRRect`.

## Files changed

- `lib/core/supabase/doc_service.dart` — `getThumbnailUrl` static method + `_thumbCache`
- `lib/screens/docs/doc_card.dart` — `DocGridCard` header, `DocListRow` leading box, `_IconArea` and `_SmallIconBox` helper widgets

## Not in scope

PDF page previews require a pixel-render library (e.g. `pdfx`). PDFs continue to show the file-type icon. This can be revisited later.
