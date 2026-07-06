# Spot Images

## Overview
Spots display a thumbnail photo in the list card and as a full-width header on the detail screen. Images are fetched from Wikipedia at creation time and stored as a URL string — no image bytes are saved locally or in Supabase storage.

## How It Works
1. When a spot is created (via Maps import, Takeout import, or manual add), `WikipediaImageService.fetchThumbnailUrl(name)` is called with the place name.
2. Wikipedia returns a thumbnail URL (typically a Wikimedia Commons image) for well-known places.
3. The URL is stored in `spots.image_url` in Supabase.
4. The UI loads it lazily on demand using `Image.network` with `cacheWidth` to limit memory usage.

## Image Service (`lib/core/images/wikipedia_image_service.dart`)
- **Primary**: Wikipedia REST API — `GET /api/rest_v1/page/summary/{name}` → `thumbnail.source`
- **Fallback**: MediaWiki action API — `?action=query&prop=pageimages&pithumbsize=600` (handles redirects and alternate titles)
- Resizes the thumbnail URL to 600px wide by rewriting the Wikimedia URL path segment
- No API key required — free, attributed to Wikipedia/Wikimedia Commons
- Timeout: 8s per request; gracefully returns null on failure

## Storage
- Stored as `image_url TEXT` in the `spots` table
- No image bytes stored; no Supabase Storage buckets used
- Works offline once loaded (Flutter's `Image.network` caches decoded frames in memory)

## UI

### List tile (`_PhotoSlot` in `spot_list_tile.dart`)
- 76×76px square with rounded corners
- If `imageUrl` is set: shows `Image.network` with `BoxFit.cover`, `cacheWidth: 152` (2× for density)
- Falls back to category icon on network error or while loading

### Detail header (`_PhotoHeader` in `spot_detail.dart`)
- 96px tall with icon when no image; expands to 200px when image is available
- `BoxFit.cover` fills the width
- Subtle bottom scrim (`0x55000000` gradient) keeps content below readable

## Supabase Migration Required
```sql
ALTER TABLE spots ADD COLUMN IF NOT EXISTS image_url TEXT;
```

## Limitations
- Wikipedia only has photos for well-known landmarks; restaurants and niche spots may have no image
- No user-uploaded photos yet (planned)
- Images shown are from Wikipedia/Wikimedia Commons under their respective licenses
