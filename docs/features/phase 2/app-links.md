# Android App Links

## Description

Android App Links allow the OS to open `https://wabway.wabble.ca/...` URLs directly in WabWay without showing a browser chooser. Used for Supabase magic-link auth callbacks.

## Key Files

- `android/app/src/main/AndroidManifest.xml` — intent filters for HTTPS and custom scheme
- `web/.well-known/assetlinks.json` — digital asset links file served from the web domain

## How It Works

Two intent filters are registered in `AndroidManifest.xml`:

1. **Custom scheme** (`com.example.wabway://login-callback`) — legacy deep link for auth callbacks, `android:autoVerify="true"`.
2. **App Links** (`https://wabway.wabble.ca/`) — intercepts any HTTPS URL on the domain, `android:autoVerify="true"`.

When a magic link email is opened on Android, the OS verifies the App Link by fetching `https://wabway.wabble.ca/.well-known/assetlinks.json`. If the app's signing certificate fingerprint matches the JSON, the URL opens directly in WabWay instead of the browser.

## Setup — Action Required

1. Get the SHA-256 fingerprint of your release keystore:
   ```
   keytool -list -v -keystore release.jks -alias <alias>
   ```
2. Replace `REPLACE_WITH_YOUR_SHA256_CERT_FINGERPRINT` in `web/.well-known/assetlinks.json`.
3. Deploy the web build (GitHub Actions CI/CD deploys `web/` to GitHub Pages at `wabway.wabble.ca`).
4. Android verifies the file automatically on install — no in-app code changes needed.
