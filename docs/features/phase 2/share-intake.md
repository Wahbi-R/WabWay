# Share Intake (Android)

## Description

WabWay can receive shared content from other Android apps — URLs, images, PDFs, and multiple images — via Android `ACTION_SEND` and `ACTION_SEND_MULTIPLE` intents. Handles both cold-start (app was closed) and while-open scenarios.

## Key Files

- `lib/screens/incoming_share_screen.dart` — handles shared content, routes to destinations
- `android/app/src/main/AndroidManifest.xml` — intent-filter declarations
- `lib/main.dart` — `share_handler` initialisation for while-open shares

## How It Works

**Intent filters registered** (see `AndroidManifest.xml`):
- `ACTION_SEND` with `text/plain` — URLs and text
- `ACTION_SEND` with `image/*` — images
- `ACTION_SEND` with `application/pdf` — PDFs
- `ACTION_SEND_MULTIPLE` with `image/*` — multiple images

**Cold start**: The `share_handler` plugin reads the initial share payload in `main.dart` before the app renders. The incoming share screen is pushed immediately.

**While open**: `share_handler` fires a stream event; the app navigates to `IncomingShareScreen` from the active route.

**Destination routing**: The share screen shows destination options — Travel item, Receipt, Document, Spot, or Import. Selecting a destination pre-fills the relevant add-item sheet with the shared content (URL, image bytes, etc.). Google Maps URLs trigger title extraction and spot pre-fill.

## Setup

No additional setup for basic share intake. The intent filters are already in `AndroidManifest.xml`.
