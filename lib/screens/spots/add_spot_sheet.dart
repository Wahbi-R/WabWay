import 'package:flutter/material.dart';
import '../../core/place_search_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../data/japan_places.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

Future<Spot?> showAddSpotSheet(
  BuildContext context, {
  required String tripId,
  required String userId,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<Spot>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(dialogCtx).height * 0.85,
          child: _AddSpotContent(
            tripId: tripId,
            userId: userId,
            onSubmit: (spot) => Navigator.pop(dialogCtx, spot),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<Spot>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddSpotSheet(
      tripId: tripId,
      userId: userId,
      onSubmit: (spot) => Navigator.pop(ctx, spot),
    ),
  );
}

// ─── Mobile bottom sheet container ────────────────────────────────────────────

class _AddSpotSheet extends StatelessWidget {
  const _AddSpotSheet({
    required this.tripId,
    required this.userId,
    required this.onSubmit,
  });
  final String tripId;
  final String userId;
  final ValueChanged<Spot> onSubmit;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, scrollCtrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: _AddSpotContent(
          tripId: tripId,
          userId: userId,
          scrollController: scrollCtrl,
          onSubmit: onSubmit,
          showDragHandle: true,
        ),
      ),
    );
  }
}

// ─── Shared form content ──────────────────────────────────────────────────────

class _AddSpotContent extends StatefulWidget {
  const _AddSpotContent({
    required this.tripId,
    required this.userId,
    required this.onSubmit,
    this.scrollController,
    this.showDragHandle = false,
  });

  final String tripId;
  final String userId;
  final ValueChanged<Spot> onSubmit;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddSpotContent> createState() => _AddSpotContentState();
}

class _AddSpotContentState extends State<_AddSpotContent> {
  final _formKey    = GlobalKey<FormState>();
  final _searchCtrl = TextEditingController();
  final _nameCtrl   = TextEditingController();
  final _cityCtrl   = TextEditingController();
  final _areaCtrl   = TextEditingController();
  final _mapsCtrl   = TextEditingController();
  final _sourceCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();

  SpotCategory? _category;
  SpotStatus    _status    = SpotStatus.idea;
  bool          _loading   = false;
  String?       _error;

  // Location from suggestion or Maps URL
  double? _latitude;
  double? _longitude;
  String? _address;
  String? _placeSource;

  List<PlaceSuggestion> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _mapsCtrl.addListener(_onMapsUrlChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _areaCtrl.dispose();
    _mapsCtrl.dispose();
    _sourceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final results = PlaceSearchService.search(query);
    setState(() {
      _suggestions      = results;
      _showSuggestions  = query.isNotEmpty;
    });
  }

  void _onMapsUrlChanged() {
    final url = _mapsCtrl.text;
    if (!PlaceSearchService.isMapsUrl(url)) return;
    final coords = PlaceSearchService.parseLatLng(url);
    if (coords != null) {
      setState(() {
        _latitude  = coords.lat;
        _longitude = coords.lng;
      });
    }
  }

  void _applySuggestion(PlaceSuggestion place) {
    _nameCtrl.text   = place.name;
    _cityCtrl.text   = place.city;
    _areaCtrl.text   = place.area;
    _mapsCtrl.text   = place.mapsUrl;
    _searchCtrl.clear();
    setState(() {
      _category       = place.category;
      _latitude       = place.latitude;
      _longitude      = place.longitude;
      _address        = place.address;
      _placeSource    = 'local_suggestion';
      _suggestions    = [];
      _showSuggestions = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final spot = await SpotService.createSpot(
        tripId:      widget.tripId,
        name:        _nameCtrl.text.trim(),
        city:        _cityCtrl.text.trim(),
        area:        _areaCtrl.text.trim(),
        category:    _category ?? SpotCategory.landmark,
        status:      _status,
        addedBy:     widget.userId,
        sourceUrl:   _sourceCtrl.text.trim().isEmpty ? null : _sourceCtrl.text.trim(),
        mapsUrl:     _mapsCtrl.text.trim().isEmpty   ? null : _mapsCtrl.text.trim(),
        notes:       _notesCtrl.text.trim().isEmpty   ? null : _notesCtrl.text.trim(),
        address:     _address,
        latitude:    _latitude,
        longitude:   _longitude,
        placeSource: _placeSource,
      );
      widget.onSubmit(spot);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle) const WabwayDragHandle(),

        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: Row(
            children: [
              Text('Add a spot', style: kStyleTitle),
              const Spacer(),
              WabwayIconButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // ── Place search bar ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search a place (Senso-ji, Shibuya…)',
              hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
              prefixIcon: const Icon(Icons.search_rounded, color: kColorInkSoft),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      color: kColorInkSoft,
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {
                          _suggestions     = [];
                          _showSuggestions = false;
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: kColorSurfaceSunken,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: kSpace3, vertical: 10),
              border: const OutlineInputBorder(
                borderRadius: kRadiusMd,
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),

        // ── Suggestion list ──────────────────────────────────────────────
        if (_showSuggestions) ...[
          const SizedBox(height: kSpace2),
          if (_suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace2),
              child: Text(
                'No matches — fill the form manually',
                style: kStyleCaption.copyWith(color: kColorInkSoft),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: kSpace4),
                itemCount: _suggestions.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final place = _suggestions[i];
                  return ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: kSpace2, vertical: 2),
                    leading: Icon(
                      _categoryIcon(place.category),
                      size: 18,
                      color: kColorInkSoft,
                    ),
                    title: Text(place.name, style: kStyleBody),
                    subtitle: Text(
                      '${place.area}, ${place.city}',
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                    ),
                    onTap: () => _applySuggestion(place),
                  );
                },
              ),
            ),
        ],

        const Divider(height: kSpace4),

        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(
              kSpace4,
              0,
              kSpace4,
              kSpace6 + bottomPad,
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

                  WabwaySelectField<SpotCategory>(
                    label: 'Category',
                    hint: 'Pick a category',
                    value: _category,
                    onChanged: (v) => setState(() => _category = v),
                    items: SpotCategory.values
                        .map((c) => WabwaySelectItem(value: c, label: c.label))
                        .toList(),
                    validator: (v) => v == null ? 'Pick a category' : null,
                  ),
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
                    hint: 'https://maps.google.com/…',
                    controller: _mapsCtrl,
                    prefixIcon: Icons.map_rounded,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
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

                  const SizedBox(height: kSpace6),

                  WabwayButton(
                    label: 'Add spot',
                    icon: Icons.add_rounded,
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

  IconData _categoryIcon(SpotCategory cat) => switch (cat) {
        SpotCategory.food       => Icons.restaurant_rounded,
        SpotCategory.landmark   => Icons.account_balance_rounded,
        SpotCategory.nature     => Icons.park_rounded,
        SpotCategory.experience => Icons.star_rounded,
        SpotCategory.shopping   => Icons.shopping_bag_rounded,
        SpotCategory.nightlife  => Icons.nightlife_rounded,
      };
}
