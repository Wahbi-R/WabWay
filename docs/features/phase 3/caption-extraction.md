# Caption Extraction & Paste Fallback

## What it does

When a user shares an Instagram or TikTok URL to WabWay, the app tries to fetch the post caption automatically to find place names. Two mechanisms work together:

1. **Server-side proxy** — routes the request through the `wabway-server` on the user's phone (Cloudflare tunnel at `audio.wabble.ca`), bypassing browser CORS restrictions. Uses `yt-dlp --print description` as primary, HTML scrape as fallback.
2. **Paste fallback** — a text field below the auto-scan results lets users paste the caption manually when auto-fetch isn't available (server offline, video private, etc.). Tapping "Find places" runs the same place extraction logic on the pasted text.

## Audio + caption auto-merge

When `/transcribe` is called on the server (audio extraction flow), the endpoint now also fetches the post caption automatically and appends it to the transcript before place extraction. This means a single "Extract from audio" tap returns places from both the audio narration and the caption text.

## Server endpoint

`GET /caption?url=<encoded URL>` on `wabway-server/main.py`:
- Instagram: `yt-dlp --print description` primary, embed-page HTML scrape fallback
- TikTok: `yt-dlp --print description` primary, oEmbed title fallback
- Returns `{"caption": "...", "source": "instagram"|"tiktok"}`

## Place extraction improvements

`_extract_places()` on the server uses a two-pass approach:
1. **Pass 1**: location-context phrases — captures nouns following prepositions like `in/to/at/near/visiting/heading to/staying in` with high confidence
2. **Pass 2**: mid-sentence capitalised sequences only (skips the first token of each sentence to avoid false positives from sentence-starting capitals)

Expanded skip list covers common sentence-starter words (Welcome, Locals, Legendary, Surrounding, etc.) that Whisper capitalises but are not place names.

## Flutter integration

- `OembedService.setProxyUrl()` — registers the audio server URL; `fetch()` tries the proxy before falling back to direct HTML scraping
- `SocialPlaceExtractor.extractFromText(text)` — geocodes place candidates extracted from raw pasted text via Nominatim; always returns a non-null result
- `_PasteCaptionCard` in `IncomingShareScreen` — text field + "Find places" button; visible when a social URL is detected

## Files changed

- `wabway-server/main.py` — `/caption` endpoint, `_instagram_caption`, `_tiktok_caption`, improved `_extract_places`, auto-merge in `/transcribe`
- `lib/core/places/oembed_service.dart` — `setProxyUrl`, `_proxyCaption`
- `lib/core/places/social_place_extractor.dart` — `extractFromText`, `_proxyInit`
- `lib/screens/share/incoming_share_screen.dart` — `_PasteCaptionCard`, `_findPlacesInPastedText`
