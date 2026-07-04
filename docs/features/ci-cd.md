# CI/CD — GitHub Actions (W2)

## What it does

On every push to `main`, the workflow at `.github/workflows/build-and-deploy.yml`:

1. Creates `.env` from GitHub repository secrets
2. Builds a debug APK → creates/updates a GitHub Release tagged `v{version}+{build}` with the APK attached
3. Builds Flutter web → deploys to GitHub Pages at `wabway.wabble.ca`

## One-time setup (do before first push)

### 1. Add repository secrets
In GitHub → repo → Settings → Secrets and variables → Actions → New repository secret:
- `SUPABASE_URL` → value from your `.env`
- `SUPABASE_ANON_KEY` → value from your `.env`

### 2. Enable GitHub Pages
In GitHub → repo → Settings → Pages:
- Source: **GitHub Actions** (not a branch)

### 3. Set custom domain
In GitHub → repo → Settings → Pages → Custom domain: `wabway.wabble.ca`

In your DNS provider, add:
```
CNAME  wabway  Wahbi-R.github.io
```
GitHub provisions the SSL cert automatically within a few minutes.

## Bumping the version

Edit `pubspec.yaml` — increment `versionCode` (the number after `+`) with every push you want friends to be notified about:
```yaml
version: 1.0.1+2   # name+buildNumber
```
The release is tagged `v1.0.1+2` and the in-app update checker compares build numbers.

## APK note

Currently builds a **debug-signed** APK. Works identically to a release build for personal use. Production signing can be added later via a keystore secret.
