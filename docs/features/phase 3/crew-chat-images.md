# Crew Chat Image Upload (Build 283)

## Overview

Trip members can share photos directly in the crew chat — from the device camera or photo library — alongside existing text messages, location pings, and SOS cards.

## How it works

1. Tap the **image icon** in the chat input bar (native platforms only; hidden on web).
2. A bottom sheet appears with two options: **Camera** or **Photo library**.
3. The selected photo is resized to a maximum of 1280×1280 px at quality 80 (preserving the original file format) before upload.
4. The file is uploaded to the `trip-chat` Supabase Storage bucket under `{tripId}/{userId}_{timestamp}.{ext}`.
5. A `trip_messages` row is inserted with `message_type = 'image'` and the public URL in `image_url`.
6. The image appears as a **220×220 thumbnail** bubble in the chat stream for all crew members via the existing realtime subscription.

## Storage

- **Bucket**: `trip-chat` (public)
- **Path format**: `{tripId}/{userId}_{timestamp}.{ext}` (timestamp in microseconds)
- **RLS**: only authenticated trip members may upload; only the uploader may delete
- **MIME type**: mapped from file extension (`jpg`/`jpeg` → `image/jpeg`, `png`, `gif`, `webp`, `heic`)

## Limitations

- Image picker is **unavailable on web** — the button is hidden when `kIsWeb` is true.
- Images are rendered as fixed **220×220 thumbnails**; there is no full-screen viewer yet.
- Upload and DB insert are two sequential calls — if the insert fails, the client attempts to delete the uploaded file (best-effort cleanup), but this secondary delete can itself fail, potentially leaving an orphaned object in the bucket.
- The `trip-chat` bucket is public, meaning anyone with the direct URL can view an image, though the URL itself is only accessible to trip members via the `trip_messages` table RLS.

## Data model

```
trip_messages
  image_url  text  (nullable — populated for message_type = 'image')
```

`MessageType` enum: `text | locationPing | findMe | meetupPoint | image`
