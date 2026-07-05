# Trip Cover Photo

## Description

Trip owners can upload a cover photo from the device gallery. The image is stored in the `trip-covers` Supabase Storage bucket and the public URL is saved to `trips.cover_image_url`. A preview with a remove button is shown in the trip settings sheet.

## Key Files

- `lib/screens/more_screen.dart` — `_CoverPhotoField` widget in the trip settings sheet
- `lib/core/supabase/trip_service.dart` — `uploadCoverImage()`, `updateTrip(coverImageUrl: ...)` / `clearCoverImage: true`
- `pubspec.yaml` — `image_picker` dependency

## How It Works

1. `_CoverPhotoField` shows the current cover image (if any) fetched from `trip.coverImageUrl`.
2. Tapping "Change photo" opens `ImagePicker().pickImage(source: ImageSource.gallery)`.
3. The picked image bytes and MIME type are passed to `TripService.uploadCoverImage(tripId, mimeType, bytes)`.
4. `uploadCoverImage()` uploads to `trip-covers/trips/<tripId>/cover.<ext>` with `upsert: true`, then returns the public URL.
5. On save, `TripService.updateTrip(tripId, coverImageUrl: url)` persists the URL to the `trips` row.
6. Removing the photo calls `updateTrip(tripId, clearCoverImage: true)` which sets `cover_image_url = null`.

## Setup

Create a **public** `trip-covers` bucket in Supabase Storage before using this feature. The bucket must allow public reads so cover images display without signed URLs.
