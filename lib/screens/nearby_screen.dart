import 'dart:async';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/async_screen_mixin.dart';
import '../core/image_cache_manager.dart';
import '../core/location/current_position.dart';
import '../core/nearby_service.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/text_utils.dart';
import '../data/share_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/wabway_button.dart';
import '../widgets/wabway_choice_chips.dart';
import '../widgets/wabway_empty_state.dart';
import '../widgets/wabway_error_state.dart';
import '../widgets/wabway_form_sheet.dart';
import '../widgets/wabway_search_bar.dart';
import '../widgets/wabway_snack.dart';
import 'spots/add_spot_sheet.dart';

/// "What's around me?" — food nearby, ramen, coffee, ATMs… with Google
/// ratings, review counts, price, open now and distance. Save any result as a
/// trip spot or open it in Google Maps.
class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key, this.initialQuery});

  /// Start with this search instead of "Food".
  final String? initialQuery;

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

const _kRadii = <double>[500, 1000, 1500, 3000, 5000];

class _NearbyScreenState extends ConsumerState<NearbyScreen> with AsyncScreenMixin {
  final _searchCtrl = TextEditingController();

  Position? _position;
  bool _locating = true;
  bool _noLocation = false;

  /// Label of the selected shortcut chip; null while a typed search is active.
  String? _shortcut = 'Food';
  double _radius = 1500;
  bool _openNow = false;
  bool _fourPlus = false;
  NearbyRank _rank = NearbyRank.relevance;

  List<NearbyPlace> _results = [];

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery?.trim() ?? '';
    if (q.isNotEmpty) {
      _searchCtrl.text = q;
      _shortcut = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _noLocation = false;
    });
    final ok = await ensureLocationPermission(
      onError: (m) => mounted ? showWabwaySnack(context, m, error: true) : null,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _locating = false;
        _noLocation = true;
        loading = false;
      });
      return;
    }
    try {
      // Results are distance-sorted — don't search from where you were an hour ago.
      final pos = await currentPosition(maxAge: const Duration(minutes: 3));
      if (!mounted) return;
      setState(() {
        _position = pos;
        _locating = false;
      });
      _search();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _noLocation = true;
        loading = false;
      });
    }
  }

  NearbyShortcut? get _activeShortcut =>
      kNearbyShortcuts.where((s) => s.label == _shortcut).firstOrNull;

  Future<void> _search() async {
    final pos = _position;
    if (pos == null) return;
    final typed = _searchCtrl.text.trim();
    final sc = typed.isEmpty ? _activeShortcut : null;
    if (typed.isEmpty && sc == null) {
      // Cleared the box with no chip selected — back to Food.
      setState(() => _shortcut = 'Food');
      return _search();
    }
    final gen = beginLoad();
    try {
      final results = await NearbyService.search(
        lat: pos.latitude,
        lng: pos.longitude,
        query: typed.isNotEmpty ? typed : sc?.query,
        kind: typed.isEmpty ? sc?.kind : null,
        radius: _radius,
        openNow: _openNow,
        minRating: _fourPlus ? 4.0 : null,
        rank: _rank,
      );
      commitLoad(gen, () => _results = results);
    } on NearbyException catch (e) {
      failLoad(gen, message: e.message);
    } catch (_) {
      failLoad(gen);
    }
  }

  void _pickShortcut(String label) {
    _searchCtrl.clear();
    setState(() => _shortcut = label);
    _search();
  }

  void _submitSearch(String text) {
    if (text.trim().isEmpty) return;
    setState(() => _shortcut = null);
    _search();
  }

  String get _filterSummary => [
        'Within ${fmtDistance(_radius.round())}',
        if (_openNow) 'Open now',
        if (_fourPlus) '4★ and up',
        _rank == NearbyRank.distance ? 'Closest first' : 'Best match',
      ].join(' · ');

  Future<void> _openFilters() async {
    final changed = await showWabwayAutoSheet<bool>(
      context,
      builder: (ctx, handle) => _FiltersSheet(
        radius: _radius,
        openNow: _openNow,
        fourPlus: _fourPlus,
        rank: _rank,
        onApply: (r, o, f, k) {
          setState(() {
            _radius = r;
            _openNow = o;
            _fourPlus = f;
            _rank = k;
          });
          Navigator.pop(ctx, true);
        },
      ),
    );
    if (changed == true) _search();
  }

  Future<void> _openPlace(NearbyPlace p) async {
    await showWabwayAutoSheet<void>(
      context,
      builder: (ctx, handle) => _PlaceSheet(place: p, onSave: () => _saveAsSpot(ctx, p)),
    );
  }

  Future<void> _saveAsSpot(BuildContext sheetContext, NearbyPlace p) async {
    final tripId = ref.read(activeTripIdProvider);
    final userId = ref.read(profileProvider)?.id;
    if (tripId.isEmpty || userId == null) {
      showWabwaySnack(context, 'Open a trip first to save spots.', error: true);
      return;
    }
    Navigator.pop(sheetContext);
    final spot = await showAddSpotSheet(
      context,
      tripId: tripId,
      userId: userId,
      prefill: ImportPrefill(place: p.toSuggestion(), notes: _spotNotes(p)),
    );
    if (spot != null && mounted) showWabwaySnack(context, '${p.name} saved to Spots.');
  }

  String? _spotNotes(NearbyPlace p) {
    final bits = [
      if (p.rating != null)
        '★ ${p.rating!.toStringAsFixed(1)}${p.ratingCount != null ? ' (${fmtCount(p.ratingCount!)} reviews)' : ''} on Google',
      if (p.priceLabel != null) p.priceLabel!,
    ];
    return bits.isEmpty ? null : bits.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Nearby', style: kStyleTitle),
        backgroundColor: kColorPaper,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: 'Update my location',
            icon: const Icon(Icons.my_location_rounded),
            color: kColorInkSoft,
            onPressed: _locating ? null : _locate,
          ),
        ],
      ),
      body: Column(
        children: [
          WabwaySearchBar(
            controller: _searchCtrl,
            hint: 'Ramen, halal, vegan, Uniqlo, ATM…',
            onChanged: (v) {
              setState(() {});
              if (v.isEmpty) _search();
            },
            onSubmitted: _submitSearch,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, 0, 0),
            child: WabwayChoiceChips<String>(
              scroll: true,
              choices: [for (final s in kNearbyShortcuts) WabwayChoice(s.label, s.label)],
              selected: _shortcut,
              onChanged: _pickShortcut,
            ),
          ),
          InkWell(
            onTap: _openFilters,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, kSpace2),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, size: 16, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(_filterSummary,
                        style: kStyleCaption.copyWith(color: kColorInkSoft),
                        overflow: TextOverflow.ellipsis),
                  ),
                  if (!loading && !error && _results.isNotEmpty)
                    Text(pluralize(_results.length, 'place'),
                        style: kStyleCaption.copyWith(color: kColorInkSoft)),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: kColorBorder),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_noLocation) {
      return WabwayEmptyState(
        icon: Icons.location_off_rounded,
        title: "Can't find where you are",
        description: 'Nearby needs your location to look around you. Turn on location and try again.',
        action: WabwayButton(label: 'Try again', icon: Icons.my_location_rounded, onPressed: _locate),
      );
    }
    if (_locating || loading) {
      return const Center(child: CircularProgressIndicator(color: kColorPrimary));
    }
    if (error) {
      return WabwayErrorState(
        title: "Couldn't search nearby",
        description: errorMessage.isNotEmpty ? errorMessage : 'Check your connection and try again.',
        action: WabwayButton(label: 'Retry', onPressed: _search),
      );
    }
    if (_results.isEmpty) {
      return WabwayEmptyState(
        icon: Icons.search_off_rounded,
        title: 'Nothing found nearby',
        description: 'Try a wider distance, or turn off "Open now" / "4★ and up".',
        action: WabwayButton(label: 'Change filters', variant: WabwayButtonVariant.secondary, onPressed: _openFilters),
      );
    }
    return RefreshIndicator(
      color: kColorPrimary,
      onRefresh: _search,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace8),
        itemCount: _results.length,
        separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
        itemBuilder: (_, i) => _PlaceCard(place: _results[i], onTap: () => _openPlace(_results[i])),
      ),
    );
  }
}

// ─── Result card ──────────────────────────────────────────────────────────────

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.onTap});
  final NearbyPlace place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = place;
    final meta = [
      if (p.priceLabel != null) p.priceLabel!,
      if (p.typeLabel != null) p.typeLabel!,
    ].join(' · ');
    return Material(
      color: kColorPaper,
      borderRadius: kRadiusLg,
      child: InkWell(
        borderRadius: kRadiusLg,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            borderRadius: kRadiusLg,
            border: Border.all(color: kColorBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlacePhoto(place: p, size: 76),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: kStyleBodySemibold, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    _RatingLine(place: p),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(meta,
                          style: kStyleCaption.copyWith(color: kColorInkSoft),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _OpenLabel(place: p),
                        if (p.distanceM != null) ...[
                          if (p.openNow != null)
                            Text('  ·  ', style: kStyleCaption.copyWith(color: kColorInkSoft)),
                          const Icon(Icons.directions_walk_rounded, size: 13, color: kColorInkSoft),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(fmtDistance(p.distanceM!),
                                style: kStyleCaption.copyWith(color: kColorInkSoft),
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingLine extends StatelessWidget {
  const _RatingLine({required this.place});
  final NearbyPlace place;

  @override
  Widget build(BuildContext context) {
    final r = place.rating;
    if (r == null) {
      return Text('No ratings yet', style: kStyleCaption.copyWith(color: kColorInkSoft));
    }
    return Row(
      children: [
        Text(r.toStringAsFixed(1), style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(width: 3),
        for (var i = 1; i <= 5; i++)
          Icon(
            r >= i - 0.25
                ? Icons.star_rounded
                : r >= i - 0.75
                    ? Icons.star_half_rounded
                    : Icons.star_outline_rounded,
            size: 14,
            color: kColorWarning,
          ),
        if (place.ratingCount != null) ...[
          const SizedBox(width: 4),
          Text('(${fmtCount(place.ratingCount!)})', style: kStyleCaption.copyWith(color: kColorInkSoft)),
        ],
      ],
    );
  }
}

class _OpenLabel extends StatelessWidget {
  const _OpenLabel({required this.place});
  final NearbyPlace place;

  @override
  Widget build(BuildContext context) {
    final open = place.openNow;
    if (open == null) return const SizedBox.shrink();
    final (text, color) = !open
        ? ('Closed', kColorDanger)
        : place.closesSoon == true
            ? ('Closes soon', kColorWarning)
            : ('Open', kColorSuccess);
    return Text(text, style: kStyleCaptionMedium.copyWith(color: color));
  }
}

class _PlacePhoto extends StatelessWidget {
  const _PlacePhoto({required this.place, required this.size, this.width});
  final NearbyPlace place;
  final double size;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final w = width ?? size;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final url = NearbyService.photoUrl(place, width: (w * dpr).round().clamp(100, 1200));
    final fallback = Container(
      width: w,
      height: size,
      color: kColorSurfaceSunken,
      child: Icon(place.category.icon, color: kColorInkSoft, size: 28),
    );
    return ClipRRect(
      borderRadius: kRadiusMd,
      child: url == null
          ? fallback
          : CachedNetworkImage(
              imageUrl: url,
              httpHeaders: NearbyService.photoHeaders,
              cacheManager: WabwayImageCache.instance,
              // The signed URL is the same per place+width; key on it so a
              // new sign-in token doesn't re-download.
              cacheKey: 'nearby:${place.photoName}@${w.round()}',
              width: w,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorBuilder: (_, __, ___) => fallback,
            ),
    );
  }
}

// ─── Place detail sheet ───────────────────────────────────────────────────────

class _PlaceSheet extends StatefulWidget {
  const _PlaceSheet({required this.place, required this.onSave});
  final NearbyPlace place;
  final VoidCallback onSave;

  @override
  State<_PlaceSheet> createState() => _PlaceSheetState();
}

class _PlaceSheetState extends State<_PlaceSheet> {
  bool _allHours = false;

  Future<void> _launch(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.place;
    final today = p.hoursOn(DateTime.now());
    final meta = [
      if (p.priceLabel != null) p.priceLabel!,
      if (p.typeLabel != null) p.typeLabel!,
      if (p.distanceM != null) '${fmtDistance(p.distanceM!)} · ${fmtWalk(p.distanceM!)}',
    ].join(' · ');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(kSpace5, kSpace2, kSpace5, kSpace5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (p.photoName != null) ...[
              LayoutBuilder(
                builder: (_, c) => _PlacePhoto(place: p, size: 170, width: c.maxWidth),
              ),
              const SizedBox(height: kSpace3),
            ],
            Text(p.name, style: kStyleHeadingSm),
            const SizedBox(height: 4),
            _RatingLine(place: p),
            if (meta.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(meta, style: kStyleCaption.copyWith(color: kColorInkSoft)),
            ],
            if (p.summary != null) ...[
              const SizedBox(height: kSpace3),
              Text(p.summary!, style: kStyleBody),
            ],
            const SizedBox(height: kSpace3),
            if (p.address.isNotEmpty)
              _InfoRow(icon: Icons.place_outlined, text: p.address),
            if (p.openNow != null || today != null)
              InkWell(
                onTap: p.weekdayHours.length == 7 ? () => setState(() => _allHours = !_allHours) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.schedule_rounded, size: 18, color: kColorInkSoft),
                      const SizedBox(width: kSpace3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              _OpenLabel(place: p),
                              if (today != null)
                                Flexible(
                                  child: Text('${p.openNow != null ? '  ·  ' : ''}Today $today',
                                      style: kStyleCaption.copyWith(color: kColorInk)),
                                ),
                              if (p.weekdayHours.length == 7)
                                Icon(_allHours ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                                    size: 18, color: kColorInkSoft),
                            ]),
                            if (_allHours)
                              for (final line in p.weekdayHours)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(line, style: kStyleCaption.copyWith(color: kColorInkSoft)),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (p.phone != null)
              _InfoRow(icon: Icons.call_outlined, text: p.phone!, onTap: () => _launch('tel:${p.phone!.replaceAll(' ', '')}')),
            if (p.website != null)
              _InfoRow(icon: Icons.language_rounded, text: Uri.tryParse(p.website!)?.host ?? p.website!, onTap: () => _launch(p.website!)),
            const SizedBox(height: kSpace4),
            WabwayButton(
              label: 'Directions',
              icon: Icons.directions_rounded,
              fullWidth: true,
              onPressed: () => _launch(p.mapsLink),
            ),
            const SizedBox(height: kSpace2),
            WabwayButton(
              label: 'Save as spot',
              icon: Icons.bookmark_add_outlined,
              variant: WabwayButtonVariant.secondary,
              fullWidth: true,
              onPressed: widget.onSave,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: kColorInkSoft),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Text(text,
                  style: kStyleCaption.copyWith(color: onTap != null ? kColorPrimary : kColorInk)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Filters sheet ────────────────────────────────────────────────────────────

class _FiltersSheet extends StatefulWidget {
  const _FiltersSheet({
    required this.radius,
    required this.openNow,
    required this.fourPlus,
    required this.rank,
    required this.onApply,
  });
  final double radius;
  final bool openNow;
  final bool fourPlus;
  final NearbyRank rank;
  final void Function(double radius, bool openNow, bool fourPlus, NearbyRank rank) onApply;

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late double _radius = widget.radius;
  late bool _openNow = widget.openNow;
  late bool _fourPlus = widget.fourPlus;
  late NearbyRank _rank = widget.rank;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kSpace5, kSpace2, kSpace5, kSpace5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Filters', style: kStyleHeadingSm),
            const SizedBox(height: kSpace4),
            WabwayChoiceChips<double>(
              label: 'Within',
              choices: [for (final r in _kRadii) WabwayChoice(r, fmtDistance(r.round()))],
              selected: _radius,
              onChanged: (v) => setState(() => _radius = v),
            ),
            const SizedBox(height: kSpace4),
            WabwayChoiceChips<NearbyRank>(
              label: 'Sort',
              choices: const [
                WabwayChoice(NearbyRank.relevance, 'Best match'),
                WabwayChoice(NearbyRank.distance, 'Closest first'),
              ],
              selected: _rank,
              onChanged: (v) => setState(() => _rank = v),
            ),
            const SizedBox(height: kSpace2),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: kColorPrimary,
              title: Text('Open now', style: kStyleBodyMedium),
              value: _openNow,
              onChanged: (v) => setState(() => _openNow = v),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: kColorPrimary,
              title: Text('4★ and up', style: kStyleBodyMedium),
              value: _fourPlus,
              onChanged: (v) => setState(() => _fourPlus = v),
            ),
            const SizedBox(height: kSpace3),
            WabwayButton(
              label: 'Show results',
              fullWidth: true,
              onPressed: () => widget.onApply(_radius, _openNow, _fourPlus, _rank),
            ),
          ],
        ),
      ),
    );
  }
}
