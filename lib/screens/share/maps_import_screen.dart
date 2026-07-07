import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/images/wikipedia_image_service.dart';
import '../../core/places/google_maps_parser.dart';
import '../../core/places/takeout_parser.dart';
import '../../core/supabase/spot_service.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'maps_web_scrape_screen.dart';

class MapsImportScreen extends StatefulWidget {
  const MapsImportScreen({
    super.key,
    required this.result,
    required this.tripId,
    required this.userId,
    this.onDone,
  });

  final MapsParseResult result;
  final String          tripId;
  final String          userId;
  final VoidCallback?   onDone;

  @override
  State<MapsImportScreen> createState() => _MapsImportScreenState();
}

class _MapsImportScreenState extends State<MapsImportScreen> {
  late List<bool>          _selected;
  late List<SpotCategory>  _categories;
  late List<MapsPlace>     _places;
  bool _saving          = false;
  bool _loadingTakeout  = false;
  bool _scrapedWebView  = false;
  bool _geocoding       = false;
  int  _geocodingDone   = 0;
  int  _geocodingTotal  = 0;

  @override
  void initState() {
    super.initState();
    _places     = List.of(widget.result.places);
    _selected   = List.filled(_places.length, true);
    _categories = _places.map((p) => p.category).toList();
  }

  void _setPlaces(List<MapsPlace> places) {
    setState(() {
      _places     = places;
      _selected   = List.filled(places.length, true);
      _categories = places.map((p) => p.category).toList();
    });
  }

  String get _listName =>
      widget.result.listName ?? (widget.result.isList ? 'Google Maps List' : 'Google Maps');

  Future<void> _tryScrapeWebView() async {
    final url = widget.result.finalUrl;
    if (url == null) return;
    final places = await Navigator.push<List<MapsPlace>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapsWebScrapeScreen(
          url:      url,
          onResult: (p) => Navigator.pop(context, p),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _scrapedWebView = true);
    if (places != null && places.isNotEmpty) {
      _setPlaces(places);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            "Couldn't scan automatically — try the Google Takeout export instead"),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ));
    }
  }

  Future<void> _loadFromTakeout() async {
    setState(() => _loadingTakeout = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file  = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) return;

      final isCsv = (file.extension ?? '').toLowerCase() == 'csv';

      if (isCsv) {
        // Fast sync parse — show list immediately, geocode in background
        final fast = TakeoutParser.parseCsvFast(bytes);
        if (!mounted) return;
        if (fast.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't read any places — make sure you picked "
                "a CSV from Takeout/Saved/"),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ));
          return;
        }
        _setPlaces(fast);
        setState(() => _loadingTakeout = false);
        // Background geocoding — updates cards live as results come in
        _startBackgroundGeocoding();
        return;
      } else {
        final places = TakeoutParser.parseJson(bytes);
        if (!mounted) return;
        if (places == null || places.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Couldn't find any places — make sure you picked "
                "Saved Places.json from Takeout/Maps (your places)/"),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ));
          return;
        }
        _setPlaces(places);
      }
    } finally {
      if (mounted) setState(() => _loadingTakeout = false);
    }
  }

  Future<void> _startBackgroundGeocoding() async {
    final total = _places.where((p) => !p.hasCoords).length;
    if (total == 0) return;
    setState(() {
      _geocoding     = true;
      _geocodingDone = 0;
      _geocodingTotal = total;
    });

    for (int i = 0; i < _places.length; i++) {
      if (_places[i].hasCoords) continue;
      final updated = await TakeoutParser.geocodePlace(_places[i]);
      if (!mounted) return;
      setState(() {
        _places[i]   = updated;
        _geocodingDone++;
        // keep category in sync if geocoding returned a better one
        if (_categories[i] == SpotCategory.landmark &&
            updated.category != SpotCategory.landmark) {
          _categories[i] = updated.category;
        }
      });
    }

    if (mounted) setState(() => _geocoding = false);
  }


  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      int count = 0;
      for (int i = 0; i < _places.length; i++) {
        if (!_selected[i]) continue;
        final p = _places[i];
        // Fetch Wikipedia thumbnail in parallel with the DB write
        final imageUrlFuture =
            WikipediaImageService.fetchThumbnailUrl(p.name);
        final imageUrl = await imageUrlFuture;
        await SpotService.createSpot(
          tripId:      widget.tripId,
          name:        p.name,
          city:        p.city.isNotEmpty ? p.city : 'Unknown',
          area:        '',
          category:    _categories[i],
          status:      SpotStatus.wantToGo,
          addedBy:     widget.userId,
          mapsUrl:     p.mapsUrl ?? widget.result.finalUrl,
          notes:       p.notes,
          address:     p.address,
          latitude:    p.hasCoords ? p.lat : null,
          longitude:   p.hasCoords ? p.lon : null,
          placeSource: _listName,
          imageUrl:    imageUrl,
        );
        count++;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Added $count spot${count == 1 ? '' : 's'}',
          style: kStyleBodyMedium.copyWith(color: kColorTextOnPrimary),
        ),
        backgroundColor: kColorPrimary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
        margin: const EdgeInsets.all(kSpace4),
      ));
      widget.onDone?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.where((s) => s).length;
    final places        = _places;

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text(
          widget.result.isList ? 'Import from list' : 'Google Maps place',
          style: kStyleTitle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(kSpace3),
              decoration: const BoxDecoration(
                color: Color(0xFFE8EEF6),
                borderRadius: kRadiusMd,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A7AB5).withAlpha(26),
                      borderRadius: kRadiusSm,
                    ),
                    child: const Icon(
                      Icons.map_rounded,
                      size: 18,
                      color: Color(0xFF4A7AB5),
                    ),
                  ),
                  const SizedBox(width: kSpace3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_listName,
                            style: kStyleBodySemibold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (places.isNotEmpty)
                          Text(
                            '${places.length} place${places.length == 1 ? '' : 's'} found',
                            style:
                                kStyleCaption.copyWith(color: kColorInkSoft),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (places.isEmpty) ...[
            // ── Empty state: WebView scan first, Takeout as fallback ──────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kSpace5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Try WebView scan (only if we haven't yet) ──────────
                    if (!_scrapedWebView && widget.result.finalUrl != null) ...[
                      Text(
                        'Scan the list automatically',
                        style: kStyleBodySemibold,
                      ),
                      const SizedBox(height: kSpace2),
                      Text(
                        'We\'ll open your Google Maps list in a quick browser '
                        'view and try to read the places directly.',
                        style: kStyleCaption.copyWith(color: kColorInkSoft),
                      ),
                      const SizedBox(height: kSpace4),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _tryScrapeWebView,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF4A7AB5),
                            minimumSize: const Size.fromHeight(48),
                            shape: const RoundedRectangleBorder(
                                borderRadius: kRadiusMd),
                          ),
                          icon: const Icon(Icons.travel_explore_rounded,
                              color: Colors.white),
                          label: Text(
                            'Scan list',
                            style: kStyleBodyMedium.copyWith(
                                color: kColorTextOnPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: kSpace5),
                      Row(children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: kSpace3),
                          child: Text('or export manually',
                              style: kStyleCaption.copyWith(
                                  color: kColorInkSoft)),
                        ),
                        const Expanded(child: Divider()),
                      ]),
                      const SizedBox(height: kSpace5),
                    ],

                    // ── Takeout fallback ───────────────────────────────────
                    Text(
                      _scrapedWebView
                          ? "Scan didn't find any places — export instead"
                          : "Export from Google Takeout",
                      style: kStyleBodySemibold,
                    ),
                    const SizedBox(height: kSpace4),
                    // Custom lists path
                    _SectionLabel(
                      icon: Icons.list_alt_rounded,
                      label: 'Custom lists (e.g. "Pin list temp")',
                    ),
                    const SizedBox(height: kSpace2),
                    ..._kCustomListSteps.asMap().entries.map((e) => _StepTile(
                          number: e.key + 1,
                          text:   e.value,
                        )),
                    const SizedBox(height: kSpace4),
                    // Starred/saved places path
                    _SectionLabel(
                      icon: Icons.star_rounded,
                      label: 'Starred / saved places',
                    ),
                    const SizedBox(height: kSpace2),
                    ..._kSavedSteps.asMap().entries.map((e) => _StepTile(
                          number: e.key + 1,
                          text:   e.value,
                        )),
                    const SizedBox(height: kSpace5),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loadingTakeout ? null : _loadFromTakeout,
                        style: FilledButton.styleFrom(
                          backgroundColor: kColorPrimary,
                          minimumSize: const Size.fromHeight(48),
                          shape: const RoundedRectangleBorder(
                              borderRadius: kRadiusMd),
                        ),
                        icon: _loadingTakeout
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.upload_file_rounded,
                                color: Colors.white),
                        label: Text(
                          _loadingTakeout
                              ? 'Geocoding places…'
                              : 'Pick .csv or Saved Places.json',
                          style: kStyleBodyMedium.copyWith(
                              color: kColorTextOnPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: kSpace3),
            // Geocoding progress banner
            if (_geocoding || _geocodingTotal > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: kSpace3, vertical: kSpace2),
                  decoration: BoxDecoration(
                    color: _geocoding
                        ? const Color(0xFFE8EEF6)
                        : const Color(0xFFF0F4EE),
                    borderRadius: kRadiusMd,
                  ),
                  child: Row(
                    children: [
                      if (_geocoding) ...[
                        const SizedBox(
                          width: 13, height: 13,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF4A7AB5)),
                        ),
                        const SizedBox(width: kSpace2),
                        Text(
                          'Finding locations… $_geocodingDone of $_geocodingTotal',
                          style: kStyleCaption.copyWith(
                              color: const Color(0xFF4A7AB5)),
                        ),
                      ] else ...[
                        Icon(
                          _places.where((p) => !p.hasCoords).isEmpty
                              ? Icons.check_circle_rounded
                              : Icons.info_outline_rounded,
                          size: 14,
                          color: _places.where((p) => !p.hasCoords).isEmpty
                              ? const Color(0xFF5A9A6F)
                              : kColorInkSoft,
                        ),
                        const SizedBox(width: kSpace2),
                        Expanded(
                          child: Text(
                            _places.where((p) => !p.hasCoords).isEmpty
                                ? 'All $_geocodingTotal places located'
                                : '${_places.where((p) => !p.hasCoords).length} places '
                                  "couldn't be located — saved without a map pin",
                            style: kStyleCaption.copyWith(
                              color: _places.where((p) => !p.hasCoords).isEmpty
                                  ? const Color(0xFF5A9A6F)
                                  : kColorInkSoft,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpace4),
              child: Text(
                'Deselect any places you don\'t want to add.',
                style: kStyleCaption.copyWith(color: kColorInkSoft),
              ),
            ),
            const SizedBox(height: kSpace3),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpace4, vertical: kSpace2),
                itemCount: places.length,
                separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
                itemBuilder: (_, i) => _MapsPlaceCard(
                  place:      places[i],
                  selected:   _selected[i],
                  category:   _categories[i],
                  onToggle:   (v) => setState(() => _selected[i] = v),
                  onCategory: (c) => setState(() => _categories[i] = c),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(kSpace4),
                child: FilledButton(
                  onPressed: selectedCount == 0 || _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: kColorPrimary,
                    minimumSize: const Size.fromHeight(48),
                    shape: const RoundedRectangleBorder(
                        borderRadius: kRadiusMd),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Add $selectedCount spot${selectedCount == 1 ? '' : 's'}',
                          style: kStyleBodyMedium.copyWith(
                              color: kColorTextOnPrimary),
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Takeout steps ────────────────────────────────────────────────────────────

const _kCustomListSteps = [
  'Open takeout.google.com on your phone or computer',
  'Tap "Deselect all", then check "Saved" only',
  'Tap "Next step" → "Export once" → "Create export"',
  'Wait for the email from Google (usually a few minutes)',
  'Download the zip, open it, and find:\nTakeout / Saved / {Your List Name}.csv',
  'Come back here and tap the button below to pick that .csv file',
];

const _kSavedSteps = [
  'Open takeout.google.com on your phone or computer',
  'Tap "Deselect all", then check "Maps (your places)" only',
  'Tap "Next step" → "Export once" → "Create export"',
  'Download the zip and find:\nTakeout / Maps (your places) / Saved Places.json',
  'Come back here and tap the button below to pick that file',
];

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});
  final IconData icon;
  final String   label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: kColorPrimary),
        const SizedBox(width: kSpace2),
        Text(label,
            style: kStyleCaption.copyWith(
                color: kColorPrimary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.text});
  final int    number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFF4A7AB5),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: kStyleCaption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Text(text, style: kStyleCaption),
          ),
        ],
      ),
    );
  }
}

// ─── Place card ───────────────────────────────────────────────────────────────

class _MapsPlaceCard extends StatelessWidget {
  const _MapsPlaceCard({
    required this.place,
    required this.selected,
    required this.category,
    required this.onToggle,
    required this.onCategory,
  });

  final MapsPlace                  place;
  final bool                       selected;
  final SpotCategory               category;
  final ValueChanged<bool>         onToggle;
  final ValueChanged<SpotCategory> onCategory;

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: kColorPrimarySoft,
                    borderRadius: kRadiusSm,
                  ),
                  child: Icon(category.icon, size: 18, color: kColorPrimary),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(place.name,
                          style: kStyleBodySemibold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (place.address != null && place.address!.isNotEmpty)
                        Text(
                          place.address!,
                          style: kStyleCaption.copyWith(color: kColorInkSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else if (place.hasCoords)
                        Text(
                          '${place.lat.toStringAsFixed(4)}, '
                          '${place.lon.toStringAsFixed(4)}',
                          style: kStyleCaption.copyWith(color: kColorInkSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      else
                        Row(children: [
                          Icon(Icons.location_off_rounded,
                              size: 11, color: kColorInkSoft),
                          const SizedBox(width: 3),
                          Text('No location found',
                              style: kStyleCaption.copyWith(
                                  color: kColorInkSoft)),
                        ]),
                      if (place.notes != null && place.notes!.isNotEmpty)
                        Text(
                          place.notes!,
                          style: kStyleCaption.copyWith(
                              color: kColorPrimary,
                              fontStyle: FontStyle.italic),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: (v) => onToggle(v ?? false),
                  activeColor: kColorPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ],
            ),
            const SizedBox(height: kSpace3),
            // Category picker
            Wrap(
              spacing: kSpace2,
              runSpacing: kSpace2,
              children: SpotCategory.values.map((c) {
                final active = c == category;
                return GestureDetector(
                  onTap: () => onCategory(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpace2, vertical: 4),
                    decoration: BoxDecoration(
                      color: active ? kColorPrimary : kColorSurfaceSunken,
                      borderRadius: kRadiusSm,
                      border: Border.all(
                        color: active ? kColorPrimary : kColorBorder,
                      ),
                    ),
                    child: Text(
                      c.label,
                      style: kStyleCaption.copyWith(
                        color: active ? kColorTextOnPrimary : kColorInk,
                        fontWeight:
                            active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
