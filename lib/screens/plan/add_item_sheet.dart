import 'dart:async';

import 'package:flutter/material.dart';
import '../../core/place_search_service.dart';
import '../../data/plan_data.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

ItineraryItemType _typeFromCategory(SpotCategory cat) => switch (cat) {
  SpotCategory.food => ItineraryItemType.food,
  _                 => ItineraryItemType.spot,
};

// ─── Show add item sheet / dialog ─────────────────────────────────────────────

Future<ItineraryItem?> showAddItemSheet(
  BuildContext context, {
  required String dayId,
  List<Spot> spots = const [],
  List<TripDocument> docs = const [],
  ItineraryItem? initialItem,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<ItineraryItem>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(ctx).height * 0.90,
          child: _AddItemContent(
            dayId: dayId,
            spots: spots,
            docs: docs,
            initialItem: initialItem,
            onSubmit: (item) => Navigator.pop(ctx, item),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<ItineraryItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddItemSheet(
      dayId: dayId,
      spots: spots,
      docs: docs,
      initialItem: initialItem,
      onSubmit: (item) => Navigator.pop(ctx, item),
    ),
  );
}

class _AddItemSheet extends StatelessWidget {
  const _AddItemSheet({
    required this.dayId,
    required this.spots,
    required this.docs,
    required this.onSubmit,
    this.initialItem,
  });
  final String dayId;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final ValueChanged<ItineraryItem> onSubmit;
  final ItineraryItem? initialItem;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: _AddItemContent(
          dayId: dayId,
          spots: spots,
          docs: docs,
          initialItem: initialItem,
          scrollController: ctrl,
          onSubmit: onSubmit,
          showDragHandle: true,
        ),
      ),
    );
  }
}

// ─── Form content ─────────────────────────────────────────────────────────────

class _AddItemContent extends StatefulWidget {
  const _AddItemContent({
    required this.dayId,
    required this.spots,
    required this.docs,
    required this.onSubmit,
    this.scrollController,
    this.showDragHandle = false,
    this.initialItem,
  });

  final String dayId;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final ValueChanged<ItineraryItem> onSubmit;
  final ScrollController? scrollController;
  final bool showDragHandle;
  final ItineraryItem? initialItem;

  @override
  State<_AddItemContent> createState() => _AddItemContentState();
}

class _AddItemContentState extends State<_AddItemContent> {
  final _formKey       = GlobalKey<FormState>();
  final _titleCtrl     = TextEditingController();
  final _locationCtrl  = TextEditingController();
  final _cityCtrl      = TextEditingController();
  final _countryCtrl   = TextEditingController();
  final _mapsCtrl      = TextEditingController();
  final _confirmCtrl   = TextEditingController();
  final _notesCtrl     = TextEditingController();

  ItineraryItemType _type = ItineraryItemType.activity;
  TimeOfDay? _time;
  String? _linkedSpotId;
  final Set<String> _linkedDocIds = {};
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item != null) {
      _titleCtrl.text    = item.title;
      _locationCtrl.text = item.location ?? '';
      _cityCtrl.text     = item.city ?? '';
      _countryCtrl.text  = item.country ?? '';
      _mapsCtrl.text     = item.mapsUrl ?? '';
      _confirmCtrl.text  = item.confirmationUrl ?? '';
      _notesCtrl.text    = item.notes ?? '';
      _type              = item.type;
      _linkedSpotId      = item.linkedSpotId;
      _linkedDocIds.addAll(item.linkedDocIds);
      if (item.time != null) {
        final parts = item.time!.split(':');
        if (parts.length == 2) {
          _time = TimeOfDay(
            hour:   int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        }
      }
      if (item.mapsUrl != null || item.confirmationUrl != null) {
        _showAdvanced = true;
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    _mapsCtrl.dispose();
    _confirmCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _applySpot(Spot spot) {
    setState(() {
      _titleCtrl.text   = spot.name;
      _cityCtrl.text    = spot.city.isNotEmpty ? spot.city : spot.area;
      _locationCtrl.text = spot.address?.isNotEmpty == true ? spot.address! : '';
      if (spot.mapsUrl != null) {
        _mapsCtrl.text  = spot.mapsUrl!;
        _showAdvanced   = true;
      }
      _linkedSpotId     = spot.id;
      _type             = _typeFromCategory(spot.category);
    });
  }

  void _clearSpot() {
    setState(() => _linkedSpotId = null);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final timeStr = _time == null
        ? null
        : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    widget.onSubmit(ItineraryItem(
      id:              widget.initialItem?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      dayId:           widget.initialItem?.dayId ?? widget.dayId,
      title:           _titleCtrl.text.trim(),
      type:            _type,
      time:            timeStr,
      location:        _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      city:            _cityCtrl.text.trim().isEmpty ? null : _cityCtrl.text.trim(),
      country:         _countryCtrl.text.trim().isEmpty ? null : _countryCtrl.text.trim(),
      mapsUrl:         _mapsCtrl.text.trim().isEmpty ? null : _mapsCtrl.text.trim(),
      confirmationUrl: _confirmCtrl.text.trim().isEmpty ? null : _confirmCtrl.text.trim(),
      notes:           _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      linkedSpotId:    _linkedSpotId,
      linkedDocIds:    _linkedDocIds.toList(),
    ));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? TimeOfDay.now(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _time = picked);
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
              Text(widget.initialItem != null ? 'Edit item' : 'Add itinerary item',
                  style: kStyleTitle),
              const Spacer(),
              WabwayIconButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: kSpace5),

        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace6 + bottomPad),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Spot quick-pick ───────────────────────────────────────
                  if (widget.spots.isNotEmpty) ...[
                    _SpotPicker(
                      spots: widget.spots,
                      linkedSpotId: _linkedSpotId,
                      onSelected: _applySpot,
                      onClear: _clearSpot,
                    ),
                    const SizedBox(height: kSpace4),
                  ],

                  // ── Title ─────────────────────────────────────────────────
                  WabwayTextField(
                    label: 'Title',
                    hint: 'e.g. Senso-ji Temple',
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: kSpace4),

                  // ── Type ──────────────────────────────────────────────────
                  WabwaySelectField<ItineraryItemType>(
                    label: 'Type',
                    value: _type,
                    onChanged: (v) =>
                        setState(() => _type = v ?? ItineraryItemType.activity),
                    items: ItineraryItemType.values
                        .map((t) => WabwaySelectItem(value: t, label: t.label))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  // ── Time ──────────────────────────────────────────────────
                  _TimePicker(
                    selected: _time,
                    onTap: _pickTime,
                    onClear: () => setState(() => _time = null),
                  ),
                  const SizedBox(height: kSpace4),

                  // ── Location / Address (with autocomplete) ────────────────
                  _LocationField(
                    controller: _locationCtrl,
                    onPlaceSelected: (p) {
                      setState(() {
                        _locationCtrl.text = p.address.isNotEmpty
                            ? '${p.name}, ${p.address}'
                            : p.name;
                        if (p.city.isNotEmpty && _cityCtrl.text.isEmpty) {
                          _cityCtrl.text = p.city;
                        }
                        if (p.country.isNotEmpty && _countryCtrl.text.isEmpty) {
                          _countryCtrl.text = p.country;
                        }
                        if (_mapsCtrl.text.isEmpty) {
                          _mapsCtrl.text = p.mapsUrl;
                          _showAdvanced  = true;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: kSpace4),

                  // ── City ──────────────────────────────────────────────────
                  WabwayTextField(
                    label: 'City',
                    hint: 'e.g. Tokyo',
                    controller: _cityCtrl,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: kSpace4),

                  // ── Country ───────────────────────────────────────────────
                  WabwayTextField(
                    label: 'Country',
                    hint: 'e.g. Japan',
                    controller: _countryCtrl,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: kSpace4),

                  // ── Attach documents ──────────────────────────────────────
                  _DocsPicker(
                    docs: widget.docs,
                    selectedIds: _linkedDocIds,
                    onChanged: (id, checked) => setState(() {
                      if (checked) _linkedDocIds.add(id);
                      else         _linkedDocIds.remove(id);
                    }),
                  ),
                  const SizedBox(height: kSpace4),

                  // ── Notes ─────────────────────────────────────────────────
                  WabwayTextField(
                    label: 'Notes',
                    hint: 'Optional notes…',
                    controller: _notesCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: kSpace3),

                  // ── Advanced (links) ──────────────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _showAdvanced = !_showAdvanced),
                    child: Row(
                      children: [
                        Icon(
                          _showAdvanced
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                          color: kColorInkSoft,
                        ),
                        const SizedBox(width: kSpace1),
                        Text('Advanced (links)',
                            style: kStyleCaptionMedium.copyWith(color: kColorInkSoft)),
                      ],
                    ),
                  ),

                  if (_showAdvanced) ...[
                    const SizedBox(height: kSpace3),
                    WabwayTextField(
                      label: 'Google Maps URL',
                      hint: 'https://maps.google.com/…',
                      controller: _mapsCtrl,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: kSpace3),
                    WabwayTextField(
                      label: 'Confirmation link',
                      hint: 'Booking reference URL',
                      controller: _confirmCtrl,
                      textInputAction: TextInputAction.next,
                    ),
                  ],

                  const SizedBox(height: kSpace6),

                  WabwayButton(
                    label: widget.initialItem != null ? 'Save changes' : 'Add to itinerary',
                    icon: Icons.event_note_rounded,
                    fullWidth: true,
                    size: WabwayButtonSize.lg,
                    onPressed: _submit,
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

// ─── Spot quick-pick ──────────────────────────────────────────────────────────

class _SpotPicker extends StatefulWidget {
  const _SpotPicker({
    required this.spots,
    required this.linkedSpotId,
    required this.onSelected,
    required this.onClear,
  });
  final List<Spot> spots;
  final String? linkedSpotId;
  final ValueChanged<Spot> onSelected;
  final VoidCallback onClear;

  @override
  State<_SpotPicker> createState() => _SpotPickerState();
}

class _SpotPickerState extends State<_SpotPicker> {
  bool _expanded = false;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Spot? get _linked =>
      widget.linkedSpotId == null
          ? null
          : widget.spots.where((s) => s.id == widget.linkedSpotId).firstOrNull;

  List<Spot> get _filtered {
    if (_query.isEmpty) return widget.spots;
    final q = _query.toLowerCase();
    return widget.spots
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final linked = _linked;

    // Linked state — show the selected spot with a clear button
    if (linked != null && !_expanded) {
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpace3, vertical: kSpace2),
        decoration: BoxDecoration(
          color: kColorPrimarySoft,
          borderRadius: kRadiusMd,
          border: Border.all(color: kColorPrimary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.place_rounded, size: 16, color: kColorPrimary),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Filled from spot',
                      style: kStyleCaption.copyWith(color: kColorPrimary)),
                  Text(linked.name,
                      style: kStyleBodySemibold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _expanded = true);
                widget.onClear();
              },
              child: const Icon(Icons.swap_horiz_rounded,
                  size: 16, color: kColorPrimary),
            ),
            const SizedBox(width: kSpace2),
            GestureDetector(
              onTap: widget.onClear,
              child: const Icon(Icons.close_rounded,
                  size: 16, color: kColorPrimary),
            ),
          ],
        ),
      );
    }

    // Collapsed state
    if (!_expanded) {
      return GestureDetector(
        onTap: () => setState(() => _expanded = true),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: kSpace3, vertical: kSpace3),
          decoration: BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
            border: Border.all(color: kColorBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.place_outlined, size: 16, color: kColorInkSoft),
              const SizedBox(width: kSpace2),
              Text('Fill from a spot',
                  style: kStyleBody.copyWith(color: kColorInkSoft)),
              const Spacer(),
              const Icon(Icons.expand_more_rounded,
                  size: 16, color: kColorInkSoft),
            ],
          ),
        ),
      );
    }

    // Expanded search list
    return Container(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace3, kSpace2, kSpace2, kSpace2),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 16, color: kColorInkSoft),
                const SizedBox(width: kSpace2),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    autofocus: true,
                    onChanged: (v) => setState(() => _query = v),
                    style: kStyleBody,
                    decoration: InputDecoration(
                      hintText: 'Search spots…',
                      hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
                      isDense: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: kColorInkSoft,
                  onPressed: () => setState(() {
                    _expanded = false;
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(kSpace4),
                    child: Text('No spots match',
                        style: kStyleCaption.copyWith(color: kColorInkSoft)),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final s = _filtered[i];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: _typeFromCategory(s.category).softColor,
                            borderRadius: kRadiusSm,
                          ),
                          child: Icon(s.category.icon,
                              size: 14, color: _typeFromCategory(s.category).color),
                        ),
                        title: Text(s.name, style: kStyleBodyMedium),
                        subtitle: Text(s.city,
                            style: kStyleCaption.copyWith(color: kColorInkSoft)),
                        onTap: () {
                          setState(() {
                            _expanded = false;
                            _searchCtrl.clear();
                            _query = '';
                          });
                          widget.onSelected(s);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Location / Address field with autocomplete ───────────────────────────────

class _LocationField extends StatefulWidget {
  const _LocationField({
    required this.controller,
    required this.onPlaceSelected,
  });
  final TextEditingController controller;
  final ValueChanged<PlaceSuggestion> onPlaceSelected;

  @override
  State<_LocationField> createState() => _LocationFieldState();
}

class _LocationFieldState extends State<_LocationField> {
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  bool _loading = false;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) setState(() => _showSuggestions = false);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    if (v.trim().length < 3) {
      setState(() { _suggestions = []; _showSuggestions = false; });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _loading = true);
      final results = await PlaceSearchService.searchPhoton(v.trim(), limit: 5);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _showSuggestions = results.isNotEmpty;
        _loading = false;
      });
    });
  }

  void _select(PlaceSuggestion p) {
    setState(() { _showSuggestions = false; _suggestions = []; });
    _focus.unfocus();
    widget.onPlaceSelected(p);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WabwayTextField(
          label: 'Location / Address',
          hint: 'e.g. 2-3-1 Asakusa, Taito City',
          controller: widget.controller,
          focusNode: _focus,
          textInputAction: TextInputAction.next,
          onChanged: _onChanged,
          suffixIcon: _loading ? Icons.hourglass_top_rounded : null,
        ),
        if (_showSuggestions)
          Container(
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: kColorPaper,
              borderRadius: kRadiusMd,
              border: Border.all(color: kColorBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _suggestions.map((p) {
                final subtitle = [
                  if (p.address.isNotEmpty) p.address,
                  if (p.city.isNotEmpty) p.city,
                  if (p.country.isNotEmpty) p.country,
                ].join(', ');
                return InkWell(
                  onTap: () => _select(p),
                  borderRadius: kRadiusMd,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpace3, vertical: kSpace3),
                    child: Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 16, color: kColorInkSoft),
                        const SizedBox(width: kSpace2),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: kStyleBodyMedium),
                              if (subtitle.isNotEmpty)
                                Text(subtitle,
                                    style: kStyleCaption.copyWith(
                                        color: kColorInkSoft),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ─── Time picker row ──────────────────────────────────────────────────────────

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.selected,
    required this.onTap,
    required this.onClear,
  });

  final TimeOfDay? selected;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Time (optional)',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: kSpace3),
            decoration: BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border: Border.all(
                color: selected != null ? kColorPrimary : kColorBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 18,
                  color: selected != null ? kColorPrimary : kColorInkSoft,
                ),
                const SizedBox(width: kSpace2),
                Expanded(
                  child: Text(
                    selected != null
                        ? '${selected!.hour.toString().padLeft(2, '0')}:${selected!.minute.toString().padLeft(2, '0')}'
                        : 'No time set — flexible item',
                    style: kStyleBody.copyWith(
                      color: selected != null ? kColorInk : kColorInkSoft,
                    ),
                  ),
                ),
                if (selected != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: kColorInkSoft),
                  )
                else
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: kColorInkSoft),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Document multi-picker ────────────────────────────────────────────────────

class _DocsPicker extends StatefulWidget {
  const _DocsPicker({
    required this.docs,
    required this.selectedIds,
    required this.onChanged,
  });
  final List<TripDocument> docs;
  final Set<String> selectedIds;
  final void Function(String id, bool checked) onChanged;

  @override
  State<_DocsPicker> createState() => _DocsPickerState();
}

class _DocsPickerState extends State<_DocsPicker> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.selectedIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docs.isEmpty) return const SizedBox.shrink();
    final selectedCount = widget.selectedIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text('Attach documents',
                  style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              if (selectedCount > 0) ...[
                const SizedBox(width: kSpace2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kColorPrimary,
                    borderRadius: kRadiusPill,
                  ),
                  child: Text(
                    '$selectedCount',
                    style: kStyleCaption.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18,
                color: kColorInkSoft,
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _expanded
              ? Column(
                  children: [
                    const SizedBox(height: kSpace2),
                    ...widget.docs.map((d) {
                      final checked = widget.selectedIds.contains(d.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) => widget.onChanged(d.id, v ?? false),
                        title: Text(d.title, style: kStyleBody),
                        subtitle: Text(d.type.label, style: kStyleCaption),
                        secondary: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: d.type.softColor,
                            borderRadius: kRadiusMd,
                          ),
                          child: Icon(d.type.icon, size: 16, color: d.type.color),
                        ),
                        activeColor: kColorPrimary,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      );
                    }),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
