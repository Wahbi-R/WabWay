import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

// ─── Changelog entries ────────────────────────────────────────────────────────
// Add newest entry at the top. Max ~10 shown in the sheet.

const _kChangelog = <_Release>[
  _Release(
    version: '1.1.0',
    build: 24,
    label: 'Multi-currency receipts',
    changes: [
      'Receipts in foreign currencies now show the home-currency equivalent (e.g. ≈ C\$89.43)',
      'Exchange rate is locked at the time of purchase — balances stay accurate even if rates shift',
      'Optional transaction fee field to capture card surcharges',
      'Set your settlement currency (e.g. CAD) in Trip Settings → Settlement currency',
      'Old receipts backfilled with exchange rate 1 — update them manually if needed',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 23,
    label: 'Document thumbnails',
    changes: [
      'Image documents now show a real preview thumbnail in the docs grid and list',
      'Thumbnails are served from Supabase\'s CDN — fast after the first load, no extra uploads',
      'Non-image files (PDFs, etc.) are unchanged',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 22,
    label: 'Caption extraction & paste fallback',
    changes: [
      'Instagram and TikTok captions are now fetched server-side, fixing CORS errors on web builds',
      'Audio transcription automatically pulls the post caption too and combines place candidates from both',
      'Paste fallback: copy-paste a caption manually if auto-fetch isn\'t available — tap "Find places" to scan it',
      'Place extraction is smarter — fewer false positives from sentence-starting words',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 21,
    label: 'Unified import & share screen',
    changes: [
      'Import and share intake are now one screen — same flow whether you\'re sharing from another app or importing manually',
      'Import mode lets you pick a file, take a photo, or paste a URL before continuing',
      'Plan item destination fully wired — pick day and item type in one step',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 20,
    label: 'Audio transcription for social shares',
    changes: [
      'Share a TikTok or Instagram video to WabWay and it extracts place names from the audio narration',
      'Transcription runs on-device via whisper.cpp (requires the WabWay server on your phone)',
      'Found places are geocoded and dropped straight into the spot picker',
      'Banner is hidden automatically when the server isn\'t configured',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 19,
    label: 'Shared photo albums',
    changes: [
      'New Photos section — drop links to everyone\'s photo albums in one place',
      'Supports Google Photos, iCloud, Dropbox, and any album link',
      'Step-by-step guide for setting up a collaborative Google Photos album the whole group can upload to',
      'Auto-detects the album service from the URL',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 18,
    label: 'Google Maps import & spot photos',
    changes: [
      'Import entire pin lists from Google Maps via share sheet',
      'Auto-fetches Wikipedia photos for imported spots',
      'Google Takeout CSV support for custom named lists',
      'Live geocoding — list appears instantly, locations fill in as they resolve',
      'WebView scraper tries to read JS-rendered Maps list pages directly',
      'Spots that can\'t be located are flagged "No location found" instead of dropped',
      'Spot list card and detail header now show place photos when available',
      'Duplicates in CSV exports are automatically removed',
      'Notes from your Maps saves are preserved on the spot',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 17,
    label: 'Two-pass OCR & AI itinerary parsing',
    changes: [
      'Two-pass OCR for low-contrast or small-text documents',
      'Gemini AI fallback for multi-column and complex booking formats',
      'Handles 2-column Gmail booking email layout',
      'Parse mode shown in banner: "AI" vs "OCR"',
      'PDF text-layer extraction before falling back to image OCR',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 16,
    label: 'Share intake & individual place import',
    changes: [
      'Share any Google Maps place link directly to WabWay',
      'Resolves short maps.app.goo.gl links via redirect tracking',
      'Nominatim geocoding when Maps URL has no coordinates',
      'My Maps (custom maps) imported via KML export',
      'New app icon and adaptive icon for Android',
    ],
  ),
  _Release(
    version: '1.0.0',
    build: 12,
    label: 'Stability & build fixes',
    changes: [
      'Fixed R8 minification crash on release builds',
      'Fixed Play Core missing classes at runtime',
      'Disabled shrink resources to prevent asset stripping',
    ],
  ),
];

// ─── Model ────────────────────────────────────────────────────────────────────

class _Release {
  const _Release({
    required this.version,
    required this.build,
    required this.label,
    required this.changes,
  });

  final String       version;
  final int          build;
  final String       label;
  final List<String> changes;

  String get displayVersion => '$version ($build)';
}

// ─── Logic ───────────────────────────────────────────────────────────────────

abstract final class ChangelogService {
  static const _prefKey = 'last_seen_build';

  /// Returns true and updates the stored build if the app was upgraded.
  static Future<bool> checkIfUpgraded() async {
    final info  = await PackageInfo.fromPlatform();
    final build = int.tryParse(info.buildNumber) ?? 0;
    final prefs = await SharedPreferences.getInstance();
    final last  = prefs.getInt(_prefKey) ?? 0;
    if (build > last) {
      await prefs.setInt(_prefKey, build);
      return true;
    }
    return false;
  }

  /// Show the changelog sheet. Pass [forceShow] true for the settings entry.
  static Future<void> show(BuildContext context, {bool forceShow = false}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => const _ChangelogSheet(),
    );
  }

  /// Call from the shell's initState — shows once after an upgrade.
  static Future<void> maybeShowOnLaunch(BuildContext context) async {
    final upgraded = await checkIfUpgraded();
    if (upgraded && context.mounted) {
      // Small delay so the shell finishes building first
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (context.mounted) show(context);
    }
  }
}

// ─── Sheet UI ─────────────────────────────────────────────────────────────────

class _ChangelogSheet extends StatelessWidget {
  const _ChangelogSheet();

  @override
  Widget build(BuildContext context) {
    final releases = _kChangelog.take(10).toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: kColorCream,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Padding(
              padding: const EdgeInsets.only(top: kSpace3),
              child: Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: kColorBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace5, kSpace4, kSpace5, kSpace2),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: kColorPrimarySoft,
                      borderRadius: kRadiusSm,
                    ),
                    child: const Icon(Icons.new_releases_rounded,
                        size: 18, color: kColorPrimary),
                  ),
                  const SizedBox(width: kSpace3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("What's new", style: kStyleBodyBold),
                      Text('Recent updates to WabWay',
                          style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: kColorInkSoft,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Releases
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(
                    kSpace5, kSpace4, kSpace5, kSpace12),
                itemCount: releases.length,
                separatorBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: kSpace4),
                  child: Divider(height: 1),
                ),
                itemBuilder: (_, i) => _ReleaseBlock(release: releases[i],
                    isLatest: i == 0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseBlock extends StatelessWidget {
  const _ReleaseBlock({required this.release, required this.isLatest});
  final _Release release;
  final bool     isLatest;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(release.displayVersion,
                style: kStyleOverline.copyWith(color: kColorInkSoft)),
            if (isLatest) ...[
              const SizedBox(width: kSpace2),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpace2, vertical: 2),
                decoration: BoxDecoration(
                  color: kColorPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Latest',
                    style: kStyleOverline.copyWith(
                        color: kColorTextOnPrimary,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
        const SizedBox(height: kSpace1),
        Text(release.label, style: kStyleBodySemibold),
        const SizedBox(height: kSpace3),
        ...release.changes.map(
          (c) => Padding(
            padding: const EdgeInsets.only(bottom: kSpace2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Container(
                    width: 5, height: 5,
                    decoration: BoxDecoration(
                      color: kColorPrimary.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Text(c,
                      style: kStyleBodyMedium.copyWith(
                          color: kColorInk, height: 1.4)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
