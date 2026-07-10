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
    build: 53,
    label: 'Search stays in global search',
    changes: [
      'Global search now includes your saved accommodations — search by hotel name, city, address, or notes and tap to open the stay detail',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 52,
    label: 'Day completion badge',
    changes: [
      'Plan day headers now show a "2/5" done/total badge when items are checked off — turns green when the whole day is complete',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 51,
    label: 'Check off plan items',
    changes: [
      'Tap the coloured dot on any plan item to mark it done — the title gets a strikethrough and the dot turns into a green checkmark; tap again to uncheck',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 50,
    label: 'WabwaySearchBar widget',
    changes: [
      'Extracted a shared WabwaySearchBar widget that replaces the repeated TextField implementation in Links, Travel, Plan, and Stays screens — same look, less code to maintain',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 49,
    label: 'Travel type filter counts',
    changes: [
      'Travel type filter chips now show counts ("Flight (2)", "Train (3)") and only appear when 2+ types are present in the list — consistent with spots and links',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 48,
    label: 'Spot category counts',
    changes: [
      'Category filter chips on the Spots screen now show counts ("Food (5)", "Activity (3)") — consistent with the Links and Money filter strips',
      'Categories with no spots in the current list are hidden, keeping the strip compact',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 47,
    label: 'Stays search',
    changes: [
      'Search accommodations by name, city, address, or notes — the search bar appears above the status filter on the Stays screen',
      'Search and status filter work together so you can find, for example, all booked stays in Tokyo',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 46,
    label: 'Plan search',
    changes: [
      'Search plan items by title, location, city, or notes — a search bar appears at the top of the Plan screen whenever days are loaded',
      'Matching items are shown in a flat results list with their day context (Day 3 · Tokyo); tapping opens the full item detail as usual',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 45,
    label: 'Receipt date grouping',
    changes: [
      'Receipts are now grouped under date headers (Mon, Jul 7) when sorted by newest or oldest — makes it easy to scan daily spending at a glance',
      'Date headers are skipped when sorted by amount, so the amount-sorted view stays clean',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 44,
    label: 'Code comments pass',
    changes: [
      'Added human-style comments to money_screen, global_search_screen, links_screen, travel_screen, and map_screen explaining non-obvious logic such as the parallel fetch strategy, closure capture pattern, and silent-reload debounce',
      'Fixed missing semicolon on an import in incoming_share_screen that was causing a parse error',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 43,
    label: 'Travel search',
    changes: [
      'Search travel items by title, location, destination, confirmation number, or notes — the search bar appears at the top of the Travel screen',
      'Search and type filter (Flight, Hotel, Train, etc.) work together so you can find, for example, all trains to Osaka',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 42,
    label: 'Receipt sorting',
    changes: [
      'Sort receipts by newest first, oldest first, highest amount, or lowest amount — tap the sort icon next to the filter chips to switch modes',
      'The sort icon turns blue when a non-default sort is active so you always know the list is sorted',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 41,
    label: 'Links search',
    changes: [
      'Search saved links by title, domain, or notes — the search bar now appears at the top of the Links screen whenever links are loaded',
      'Search and category filter work together so you can narrow down to, say, only food links that mention a specific restaurant',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 40,
    label: 'Spending by category',
    changes: [
      'A spending breakdown card now appears at the top of the Receipts tab when your trip has expenses in more than one category — shows each category\'s total and a mini progress bar so you can see where the money went at a glance',
      'The breakdown uses the home-currency equivalent for all amounts, so mixed-currency trips still show a consistent total',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 39,
    label: 'Links filter + map polish',
    changes: [
      'Filter saved links by category — Food & drink, Stay, Activity, Article, Social, and more — with a single tap; shows counts and auto-hides when all links share the same category',
      'Map screen realtime updates no longer flash a loading spinner — changes stream in silently while you browse spots',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 38,
    label: 'Cash withdrawal notes',
    changes: [
      'Cash withdrawal notes now show in the list — useful for recording which ATM you used or any transaction details worth remembering',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 37,
    label: 'Tappable activity feed',
    changes: [
      'Activity events on the home screen are now tappable — tap any spot, document, travel item, receipt, or plan item event to jump straight to the detail screen',
      'A chevron arrow appears on tappable events so you know which ones navigate somewhere',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 36,
    label: 'Receipt filters + travel order',
    changes: [
      'Filter receipts by category — Food, Transport, Stay, Activity, Shopping, or Other — with a single tap; the chip shows how many receipts are in each category',
      'Filter is hidden when all receipts fall into the same category, so it only appears when it helps',
      'Travel items are now sorted by departure date so the list reads like the trip timeline — draft bookings with no date appear at the end',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 35,
    label: 'Spot notes in list',
    changes: [
      'Spot notes now show in the list view — up to 2 lines, so you can see your own reminders at a glance without opening the spot',
      'Notes appear between the city/category line and the vote summary, hidden when empty so the card stays compact',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 34,
    label: 'Multi-currency balance',
    changes: [
      'Home screen balance card now shows debts and credits in every currency separately — no more missing JPY debts when your trip also has CAD expenses',
      'Total spent on the home screen now uses home-currency equivalents so the number is consistent when you mix currencies',
      'Accommodations screen now updates in real-time when a trip-mate adds or edits a stay',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 33,
    label: 'Tappable search results',
    changes: [
      'Search results are now tappable — tap any result to open the full detail screen',
      'Spots, documents, travel items, receipts, and itinerary items all navigate directly',
      'A chevron icon on each card makes it clear every result is tappable',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 32,
    label: 'Spot export + tappable trip hero',
    changes: [
      'Export your visible spots as a CSV — tap the export icon in the Spots screen to share a spreadsheet with name, city, category, status, address, and notes for every spot currently shown',
      'Filters and sort order are respected: the CSV contains exactly what you see on screen',
      'Trip owners can now tap the home screen hero card to open Trip Settings directly — a small edit icon appears as a hint',
      'Non-owners see the card as before: no tap, no icon',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 31,
    label: 'Spot sorting + trip countdown',
    changes: [
      'Sort your spots by "Newest first", "A – Z", or "Most voted" — tap the sort icon in the Spots screen',
      'Must-do votes rank highest when sorting by Most voted, with total vote count as tiebreaker',
      'Trip hero on the Home screen now shows how many days until departure, which day of the trip you\'re on, or how long ago the trip ended',
      'Countdown is hidden automatically when the trip has no start or end date set',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 30,
    label: 'Google Places search',
    changes: [
      'Place search now uses Google Places (via the WabWay server) for much better results — restaurants, shops, and local businesses are found instantly',
      'Search fires when you press Enter or tap the search icon, not on every keystroke — no accidental API charges',
      'Falls back to Photon (OpenStreetMap) automatically when the server is unavailable',
      'Both the Add Spot and Add Plan Item location fields share the same search widget and engine',
      'Google Takeout CSV geocoding also uses Google Places as the first lookup before falling back to Nominatim',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 29,
    label: 'CSV import & share support',
    changes: [
      'Share a CSV from Google Takeout directly to WabWay — goes straight to the import screen',
      'WabWay now appears in the share menu for CSV, XLS, and XLSX files',
      'Picking a CSV in the in-app import picker no longer asks you to pick the file a second time',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 28,
    label: 'Spot country + better Maps import',
    changes: [
      'Spots now have a Country field — auto-filled when using place search or pasting a Maps link',
      'Paste any Google Maps link (short or full) — name, city, and country are looked up automatically',
      'Short links (maps.app.goo.gl) now resolve correctly instead of only extracting coordinates',
      'Sharing a Google Maps link pre-fills the spot form with place name, city, and country',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 27,
    label: 'Plan item improvements',
    changes: [
      'Pick a spot to auto-fill the plan item title, address, city, country, and Google Maps link',
      'Location / Address field now autocompletes as you type — powered by Photon',
      'New Country field on plan items, auto-filled from address search',
      'Spot picker sits above the title so you can pre-fill before editing',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 26,
    label: 'Bug fixes',
    changes: [
      'Exchange rate no longer shows 0.00 — now uses the /latest Frankfurter endpoint which is always available',
      'What\'s new shows as a centred dialog on desktop instead of a cropped bottom sheet',
      '"What\'s new" button added to the desktop sidebar so it\'s reachable without going through More',
    ],
  ),
  _Release(
    version: '1.1.0',
    build: 25,
    label: 'Auto-fetch spot thumbnails',
    changes: [
      'Spots added before thumbnails were introduced now get Wikipedia images automatically',
      'Images stream in as they load — no need to re-add spots',
      'Already-found images are saved to the database so they load instantly next time',
    ],
  ),
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

  /// Show the changelog. Uses a centered dialog on wide screens, bottom sheet on mobile.
  static Future<void> show(BuildContext context, {bool forceShow = false}) {
    final isWide = MediaQuery.sizeOf(context).width >= 600;
    if (isWide) {
      return showDialog<void>(
        context: context,
        builder: (_) => const _ChangelogDialog(),
      );
    }
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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

// ─── Shared content ───────────────────────────────────────────────────────────

Widget _changelogHeader(BuildContext context) {
  return Padding(
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
  );
}

Widget _changelogList(ScrollController? scroll) {
  final releases = _kChangelog.take(10).toList();
  return ListView.separated(
    controller: scroll,
    padding: const EdgeInsets.fromLTRB(kSpace5, kSpace4, kSpace5, kSpace6),
    itemCount: releases.length,
    separatorBuilder: (_, __) => const Padding(
      padding: EdgeInsets.symmetric(vertical: kSpace4),
      child: Divider(height: 1),
    ),
    itemBuilder: (_, i) => _ReleaseBlock(release: releases[i], isLatest: i == 0),
  );
}

// ─── Mobile bottom sheet ──────────────────────────────────────────────────────

class _ChangelogSheet extends StatelessWidget {
  const _ChangelogSheet();

  @override
  Widget build(BuildContext context) {
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
            _changelogHeader(context),
            const Divider(height: 1),
            Expanded(child: _changelogList(scroll)),
          ],
        ),
      ),
    );
  }
}

// ─── Desktop dialog ───────────────────────────────────────────────────────────

class _ChangelogDialog extends StatelessWidget {
  const _ChangelogDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: kColorCream,
      shape: RoundedRectangleBorder(borderRadius: kRadiusLg),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _changelogHeader(context),
            const Divider(height: 1),
            Flexible(child: _changelogList(null)),
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
