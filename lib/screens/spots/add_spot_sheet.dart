import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/maps_import_service.dart';
import '../../core/place_search_service.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/spot_service.dart';
import '../../data/spot_data.dart';
import '../../core/notifications/push_notifier.dart';
import '../notification_settings_screen.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/place_search_field.dart';
import '../../widgets/widgets.dart';
import '../../data/share_data.dart';

Future<Spot?> showAddSpotSheet(
  BuildContext context, {
  required String tripId,
  required String userId,
  double? initialLatitude,
  double? initialLongitude,
  ImportPrefill? prefill,
}) => _showSpotSheet(context, tripId: tripId, userId: userId,
      initialLatitude: initialLatitude, initialLongitude: initialLongitude,
      prefill: prefill);

Future<Spot?> showEditSpotSheet(
  BuildContext context, {
  required String tripId,
  required String userId,
  required Spot spot,
}) => _showSpotSheet(context, tripId: tripId, userId: userId, initialSpot: spot);

Future<Spot?> _showSpotSheet(
  BuildContext context, {
  required String tripId,
  required String userId,
  Spot? initialSpot,
  double? initialLatitude,
  double? initialLongitude,
  ImportPrefill? prefill,
}) {
  return showWabwayFormSheet<Spot>(
    context,
    desktopHeightFactor: 0.85,
    initialChildSize: 0.88,
    minChildSize: 0.5,
    maxChildSize: 0.96,
    builder: (ctx, scroll, handle, close) => _AddSpotContent(
      tripId: tripId,
      userId: userId,
      initialSpot: initialSpot,
      initialLatitude: initialLatitude,
      initialLongitude: initialLongitude,
      prefill: prefill,
      scrollController: scroll,
      showDragHandle: handle,
      onSubmit: close,
    ),
  );
}

// ─── Mobile bottom sheet container ────────────────────────────────────────────

class _AddSpotContent extends ConsumerStatefulWidget {
  const _AddSpotContent({
    required this.tripId,
    required this.userId,
    required this.onSubmit,
    this.initialSpot,
    this.initialLatitude,
    this.initialLongitude,
    this.prefill,
    this.scrollController,
    this.showDragHandle = false,
  });

  final String tripId;
  final String userId;
  final ValueChanged<Spot> onSubmit;
  final Spot? initialSpot;
  final double? initialLatitude;
  final double? initialLongitude;
  final ImportPrefill? prefill;
  final ScrollController? scrollController;
  final bool showDragHandle;

  bool get isEditing => initialSpot != null;

  @override
  ConsumerState<_AddSpotContent> createState() => _AddSpotContentState();
}

class _AddSpotContentState extends ConsumerState<_AddSpotContent> {
  final _formKey      = GlobalKey<FormState>();
  final _nameCtrl     = TextEditingController();
  final _cityCtrl     = TextEditingController();
  final _areaCtrl     = TextEditingController();
  final _addressCtrl  = TextEditingController();
  final _countryCtrl  = TextEditingController();
  final _mapsCtrl     = TextEditingController();
  final _sourceCtrl   = TextEditingController();
  final _notesCtrl    = TextEditingController();

  SpotCategory? _category;
  SpotStatus    _status    = SpotStatus.idea;
  bool          _loading   = false;
  bool          _mapsLoading = false;
  bool          _classifying = false;
  bool          _notifyOnAdd = false;
  String?       _error;

  static const _kPrefSpotNotify = 'spot_add_notify';
  final _categoryKey = GlobalKey();

  // Location from suggestion or Maps URL
  double? _latitude;
  double? _longitude;
  String? _placeSource;
  String? _placeId;

  // Address search state


  @override
  void initState() {
    super.initState();
    final s = widget.initialSpot;
    if (s != null) {
      _nameCtrl.text    = s.name;
      _cityCtrl.text    = s.city;
      _areaCtrl.text    = s.area;
      _addressCtrl.text = s.address ?? '';
      _countryCtrl.text = s.country ?? '';
      _mapsCtrl.text    = s.mapsUrl ?? '';
      _sourceCtrl.text  = s.sourceUrl ?? '';
      _notesCtrl.text   = s.notes ?? '';
      _category         = s.category;
      _status           = s.status;
      _latitude         = s.latitude;
      _longitude        = s.longitude;

      _placeSource      = s.placeSource;
    } else if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _latitude  = widget.initialLatitude;
      _longitude = widget.initialLongitude;
    }
    _mapsCtrl.addListener(_onMapsUrlChanged);
    final pre = widget.prefill;
    if (s == null && pre != null) {
      _nameCtrl.text   = pre.title ?? '';
      _notesCtrl.text  = pre.notes ?? '';
      _sourceCtrl.text = pre.url ?? '';
      // Set after the listener so a Google Maps link resolves the place
      // (name, coords, city, area) exactly like pasting it by hand.
      if (pre.mapsUrl != null) _mapsCtrl.text = pre.mapsUrl!;
    }
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() => _notifyOnAdd = p.getBool(_kPrefSpotNotify) ?? false);
    });
  }

  @override
  void dispose() {
    _mapsDebounce?.cancel();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _areaCtrl.dispose();
    _addressCtrl.dispose();
    _countryCtrl.dispose();
    _mapsCtrl.dispose();
    _sourceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Timer? _mapsDebounce;

  void _onMapsUrlChanged() {
    final url = _mapsCtrl.text.trim();
    if (!PlaceSearchService.isMapsUrl(url)) return;

    _mapsDebounce?.cancel();
    _mapsDebounce = Timer(const Duration(milliseconds: 600), () => _resolveMapsUrl(url));
  }

  Future<void> _resolveMapsUrl(String url) async {
    if (!mounted) return;
    setState(() => _mapsLoading = true);
    final info = await MapsImportService.resolve(url);
    if (!mounted) return;
    setState(() => _mapsLoading = false);
    if (info == null) return;

    setState(() {
      _latitude    = info.latitude;
      _longitude   = info.longitude;
      _placeSource = 'google_maps';
      if (info.category != null && _category == null) {
        _category = _categoryFromSlug(info.category!);
      }
    });

    if (_nameCtrl.text.trim().isEmpty && info.name.isNotEmpty) {
      _nameCtrl.text = info.name;
    }
    if (info.address != null && _addressCtrl.text.trim().isEmpty) {
      _addressCtrl.text = info.address!;
    }
    if (info.city != null && _cityCtrl.text.trim().isEmpty) {
      _cityCtrl.text = info.city!;
    }
    if (info.area != null && info.area!.isNotEmpty && _areaCtrl.text.trim().isEmpty) {
      _areaCtrl.text = info.area!;
    }
    if (info.country != null && _countryCtrl.text.trim().isEmpty) {
      _countryCtrl.text = info.country!;
    }
  }

  SpotCategory _categoryFromSlug(String slug) => switch (slug) {
    'food'       => SpotCategory.food,
    'shopping'   => SpotCategory.shopping,
    'nature'     => SpotCategory.nature,
    'nightlife'  => SpotCategory.nightlife,
    'experience' => SpotCategory.experience,
    _            => SpotCategory.landmark,
  };


  void _applySuggestion(PlaceSuggestion place) {
    _nameCtrl.text    = place.name;
    if (place.city.isNotEmpty)    _cityCtrl.text    = place.city;
    if (place.area.isNotEmpty)    _areaCtrl.text    = place.area;
    if (place.address.isNotEmpty) _addressCtrl.text = place.address;
    if (place.country.isNotEmpty) _countryCtrl.text = place.country;
    _mapsCtrl.text    = place.mapsUrl;

    // If the search returned no specific category (defaulted to landmark),
    // try to infer one from the place name for better auto-selection.
    final inferred = place.category != SpotCategory.landmark
        ? place.category
        : _inferCategoryFromName(place.name);

    setState(() {
      _category        = inferred;
      _latitude        = place.latitude;
      _longitude       = place.longitude;
      _placeSource     = 'place_search';
      _placeId         = place.placeId;
    });

    // When the category is still uncertain (landmark default), ask Claude.
    if (inferred == SpotCategory.landmark) {
      _classifyWithAI(place.name, place.address);
    }
  }

  Future<void> _classifyWithAI(String name, String address) async {
    setState(() => _classifying = true);
    final category = await PlaceSearchService.classifyPlace(name, address);
    if (!mounted) return;
    setState(() {
      _classifying = false;
      if (category != null) _category = category;
    });
  }

  SpotCategory _inferCategoryFromName(String name) {
    final n = name.toLowerCase();
    if (n.contains('restaurant') || n.contains('cafe') || n.contains('coffee') ||
        n.contains('sushi') || n.contains('ramen') || n.contains('curry') ||
        n.contains('noodle') || n.contains('bistro') || n.contains('diner') ||
        n.contains('grill') || n.contains('bakery') || n.contains('kitchen') ||
        n.contains('izakaya') || n.contains('yakitori') || n.contains('bar') ||
        n.contains('food')) { return SpotCategory.food; }
    if (n.contains('shop') || n.contains('store') || n.contains('market') ||
        n.contains('mall') || n.contains('boutique') || n.contains('outlet')) {
      return SpotCategory.shopping;
    }
    if (n.contains('park') || n.contains('garden') || n.contains('beach') ||
        n.contains('forest') || n.contains('lake') || n.contains('mountain') ||
        n.contains('waterfall') || n.contains('nature') || n.contains('river')) {
      return SpotCategory.nature;
    }
    if (n.contains('museum') || n.contains('gallery') || n.contains('shrine') ||
        n.contains('temple') || n.contains('castle') || n.contains('theatre') ||
        n.contains('zoo') || n.contains('aquarium') || n.contains('tower') ||
        n.contains('monument') || n.contains('ruins') || n.contains('palace')) {
      return SpotCategory.experience;
    }
    if (n.contains('club') || n.contains('pub') || n.contains('lounge') ||
        n.contains('nightclub') || n.contains('karaoke') || n.contains('disco')) {
      return SpotCategory.nightlife;
    }
    return SpotCategory.landmark;
  }

  void _applyAddressResult(PlaceSuggestion place) {
    setState(() {
      // PlaceSearchField writes the place name into the field; prefer the address.
      _addressCtrl.text = place.address.isNotEmpty ? place.address : place.name;
      _latitude  ??= place.latitude;
      _longitude ??= place.longitude;
      if (_countryCtrl.text.trim().isEmpty && place.country.isNotEmpty) {
        _countryCtrl.text = place.country;
      }
      if (_cityCtrl.text.trim().isEmpty && place.city.isNotEmpty) {
        _cityCtrl.text = place.city;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      if (_category == null) {
        final ctx = _categoryKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeInOut,
            alignment: 0.3,
          );
        }
      }
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final Spot spot;
      if (widget.isEditing) {
        final addrInput = _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
        // Fetch a photo if we have a placeId and the spot currently has no image.
        String? imageUrl;
        if (_placeId != null && (widget.initialSpot!.imageUrl == null || widget.initialSpot!.imageUrl!.trim().isEmpty)) {
          imageUrl = await PlaceSearchService.fetchPhotoUrl(_placeId!);
        }
        spot = await SpotService.updateSpot(
          spotId:      widget.initialSpot!.id,
          name:        _nameCtrl.text.trim(),
          city:        _cityCtrl.text.trim(),
          area:        _areaCtrl.text.trim(),
          category:    _category ?? SpotCategory.landmark,
          status:      _status,
          sourceUrl:   _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
          mapsUrl:     _mapsCtrl.text.trim().isEmpty   ? null : _mapsCtrl.text.trim(),
          notes:       _notesCtrl.text.trim().isEmpty  ? null : _notesCtrl.text.trim(),
          address:     addrInput,
          country:     _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
          latitude:    _latitude,
          longitude:   _longitude,
          placeSource: _placeSource,
          imageUrl:    imageUrl,
        );
      } else {
        final addrInput = _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
        // Fetch Google Places photo in parallel with nothing — fire before the
        // DB write so we can pass it directly and avoid a second round-trip.
        final imageUrlFuture = _placeId != null
            ? PlaceSearchService.fetchPhotoUrl(_placeId!)
            : Future<String?>.value(null);
        final imageUrl = await imageUrlFuture;
        spot = await SpotService.createSpot(
          tripId:      widget.tripId,
          name:        _nameCtrl.text.trim(),
          city:        _cityCtrl.text.trim(),
          area:        _areaCtrl.text.trim(),
          category:    _category ?? SpotCategory.landmark,
          status:      _status,
          addedBy:     widget.userId,
          sourceUrl:   _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
          mapsUrl:     _mapsCtrl.text.trim().isEmpty   ? null : _mapsCtrl.text.trim(),
          notes:       _notesCtrl.text.trim().isEmpty  ? null : _notesCtrl.text.trim(),
          address:     addrInput,
          country:     _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
          latitude:    _latitude,
          longitude:   _longitude,
          placeSource: _placeSource,
          imageUrl:    imageUrl,
        );
      }
      if (!mounted) return;
      widget.onSubmit(spot);
      if (!widget.isEditing && _notifyOnAdd) {
        pushNotify(
          tripId: widget.tripId,
          title: 'New spot added',
          body: spot.name,
          excludeUserId: widget.userId,
          data: {'screen': 'spots', 'trip_id': widget.tripId},
          prefKey: kPrefNotifActivity,
        );
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPad = MediaQuery.viewInsetsOf(context).bottom;
    // viewPaddingOf gives the hardware nav-bar height regardless of SafeArea,
    // ensuring the Add button is never hidden behind the system nav bar.
    final navBarPad   = MediaQuery.viewPaddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle) const WabwayDragHandle(),

        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: Row(
            children: [
              Text(widget.isEditing ? 'Edit spot' : 'Add a spot', style: kStyleTitle),
              const Spacer(),
              WabwayIconButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // ── Place search ─────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: PlaceSearchField(
            label: 'Search a place',
            hint: 'Senso-ji, Hinoya Curry Tokyo…',
            onSelected: _applySuggestion,
            locationBias: () {
              final d = ref.watch(activeTripProvider)?.destination ?? '';
              return d.isNotEmpty ? d : null;
            }(),
          ),
        ),

        const Divider(height: kSpace4),

        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(
              kSpace4,
              0,
              kSpace4,
              kSpace6 + keyboardPad + navBarPad,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Map-ready badge
                  if (_latitude != null && _longitude != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded,
                            size: 14, color: kColorSuccess),
                        const SizedBox(width: 4),
                        Text(
                          'Map ready · ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                          style: kStyleCaption.copyWith(color: kColorSuccess),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace3),
                  ],

                  WabwayTextField(
                    label: 'Name',
                    hint: 'e.g. Senso-ji Temple',
                    controller: _nameCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: kSpace4),

                  Row(
                    children: [
                      Expanded(
                        child: WabwayTextField(
                          label: 'City',
                          hint: 'Tokyo',
                          controller: _cityCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: kSpace3),
                      Expanded(
                        child: WabwayTextField(
                          label: 'Area',
                          hint: 'Asakusa',
                          controller: _areaCtrl,
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  PlaceSearchField(
                    label: 'Address (optional)',
                    hint: 'Street address — search to fill in the rest',
                    controller: _addressCtrl,
                    limit: 5,
                    onSelected: _applyAddressResult,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Country',
                    hint: 'e.g. Japan',
                    controller: _countryCtrl,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<SpotCategory>(
                    key: _categoryKey,
                    label: 'Category',
                    hint: 'Pick a category',
                    value: _category,
                    onChanged: (v) => setState(() => _category = v),
                    items: SpotCategory.values
                        .map((c) => WabwaySelectItem(value: c, label: c.label))
                        .toList(),
                    validator: (v) => v == null ? 'Pick a category' : null,
                  ),
                  if (_classifying) ...[
                    const SizedBox(height: kSpace2),
                    Row(
                      children: [
                        const SizedBox(
                          width: 12, height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(width: kSpace2),
                        Text('AI is suggesting a category…',
                            style: kStyleCaption.copyWith(color: kColorInkSoft)),
                      ],
                    ),
                  ],
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<SpotStatus>(
                    label: 'Status',
                    value: _status,
                    onChanged: (v) => setState(() => _status = v ?? SpotStatus.idea),
                    items: SpotStatus.values
                        .map((s) => WabwaySelectItem(value: s, label: s.label))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Google Maps URL',
                    hint: 'Paste any Maps link — short or full',
                    controller: _mapsCtrl,
                    prefixIcon: Icons.map_rounded,
                    suffixIcon: _mapsLoading ? Icons.hourglass_top_rounded : null,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  if (_mapsLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: kSpace2),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 12, height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                          const SizedBox(width: kSpace2),
                          Text('Looking up place info…',
                              style: kStyleCaption.copyWith(color: kColorInkSoft)),
                        ],
                      ),
                    ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Source URL',
                    hint: 'Instagram, TikTok, article link…',
                    controller: _sourceCtrl,
                    prefixIcon: Icons.link_rounded,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Notes',
                    hint: 'Tips, context, opening hours…',
                    controller: _notesCtrl,
                    maxLines: 4,
                    textInputAction: TextInputAction.newline,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: kSpace3),
                    Text(
                      _error!,
                      style: kStyleCaption.copyWith(color: kColorDanger),
                    ),
                  ],

                  if (!widget.isEditing) ...[
                    const SizedBox(height: kSpace5),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Notify crew', style: kStyleBodyMedium),
                              Text(
                                _notifyOnAdd
                                    ? 'Crew will get a push notification'
                                    : 'No notification will be sent',
                                style: kStyleCaption.copyWith(color: kColorInkSoft),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: _notifyOnAdd,
                          activeColor: kColorPrimary,
                          onChanged: (v) {
                            setState(() => _notifyOnAdd = v);
                            SharedPreferences.getInstance()
                                .then((p) => p.setBool(_kPrefSpotNotify, v));
                          },
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: kSpace4),

                  WabwayButton(
                    label: widget.isEditing ? 'Save changes' : 'Add spot',
                    icon: widget.isEditing ? Icons.check_rounded : Icons.add_rounded,
                    fullWidth: true,
                    size: WabwayButtonSize.lg,
                    loading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

}
