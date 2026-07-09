# Audio Transcription for Share Intake

Adds a second extraction path in the TikTok/Instagram share flow. Rather than relying on the post caption (which rarely contains explicit place names), the server downloads the video audio and transcribes what the creator actually says.

## Problem

`SocialPlaceExtractor.extract()` uses oEmbed to get the post caption, then looks for 📍 emoji and hashtags. This fails for most real-world travel content because creators say place names aloud ("we just got to this amazing ramen spot in Shinjuku called Ichiran…") but rarely write them in the caption.

## Solution

A local Python server on the LG G8 (Termux) handles the heavy lifting:

1. **yt-dlp** downloads the video's audio track as MP3 (~1–3 MB)
2. **faster-whisper** (`base` model, CPU, int8) transcribes locally (~30–60 s for a 60 s clip on Snapdragon 855)
3. **spaCy** `en_core_web_sm` runs NER and extracts `GPE`, `LOC`, `FAC` entity types
4. Server returns `{ transcript, places: [string] }`
5. Flutter geocodes each place name via the existing `NominatimService.search()`

Zero API cost — both models are cached locally after first download.

## Architecture

### Server (`wabway-server/`)

Lives inside the WabWay folder but gitignored and has its own git repo.

| File | Purpose |
|---|---|
| `main.py` | FastAPI app; models loaded once at startup via lifespan |
| `requirements.txt` | fastapi, uvicorn, faster-whisper, spacy, python-dotenv, pydantic |
| `start.sh` | Termux entry point; sets `termux-wake-lock` |
| `.env.example` | `PORT=8000` |
| `README.md` | Full Termux setup walkthrough |

**Endpoints:**
- `POST /transcribe` — `{ url }` → `{ transcript, places }`
- `GET /health` — `{ status, whisper, spacy }`

**Model sizes:** faster-whisper `base` ≈ 74 MB, `en_core_web_sm` ≈ 12 MB

### Flutter

**`lib/core/places/social_place_extractor.dart`**
- `const _kAudioServerUrl = String.fromEnvironment('AUDIO_SERVER_URL', defaultValue: '')`
- `static bool get audioServerAvailable` — controls banner visibility
- `static Future<SocialPlaceResult?> extractFromAudio(String url)` — POSTs to `/transcribe`, geocodes up to 8 place names, 3-minute timeout

**`lib/screens/share/incoming_share_screen.dart`**
- `bool _scanningAudio` state var
- `_transcribeAudio()` method mirrors `_findPlaces()`
- Audio banner shown only when `SocialPlaceExtractor.audioServerAvailable` is true — graceful degradation when server not configured

## Configuration

Add to WabWay's `.env` after starting the Cloudflare tunnel on the G8:

```
AUDIO_SERVER_URL=https://your-tunnel.trycloudflare.com
```

Then rebuild: `flutter build apk --debug --dart-define-from-file=.env`

## Termux Setup (G8)

See `wabway-server/README.md` for the full walkthrough. Short version:

1. Install Termux from F-Droid
2. `pkg install python ffmpeg cloudflared`
3. `pip install fastapi "uvicorn[standard]" faster-whisper spacy yt-dlp python-dotenv pydantic`
4. `python -m spacy download en_core_web_sm`
5. `bash start.sh` — models download on first use
6. `cloudflared tunnel --url http://localhost:8000` in a second session

## Trade-offs

| | Caption extraction | Audio transcription |
|---|---|---|
| Speed | ~2 s | ~60 s (transcription) |
| Accuracy | Low (captions are generic) | High (creators say place names) |
| Cost | Free | Free (local models) |
| Requires | Nothing extra | G8 server running |

The audio banner is additive — both paths are available in the share screen.
