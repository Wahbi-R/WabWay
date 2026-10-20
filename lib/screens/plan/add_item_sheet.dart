import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/plan_data.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart';
import '../../data/accommodation_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/place_search_field.dart';
import '../../widgets/widgets.dart';
import '../../core/text_utils.dart';
import '../../data/date_utils.dart' show parseTimeOfDay;
import '../../data/currencies.dart';
import '../../data/share_data.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

ItineraryItemType _typeFromCategory(SpotCategory cat) => switch (cat) {
  SpotCategory.food      => ItineraryItemType.food,
  SpotCategory.nightlife => ItineraryItemType.activity,
  _                      => ItineraryItemType.spot,
};

// ─── Show add item sheet / dialog ─────────────────────────────────────────────

Future<ItineraryItem?> showAddItemSheet(
  BuildContext context, {
  required String dayId,
  required String defaultCurrency,
  List<Spot> spots = const [],
  List<TripDocument> docs = const [],
  List<Accommodation> stays = const [],
  ItineraryItem? initialItem,
  ItineraryItem? prefillItem,
  ImportPrefill? prefill,
}) {
  return showWabwayFormSheet<ItineraryItem>(
    context,
    desktopHeightFactor: 0.90,
    initialChildSize: 0.92,
    minChildSize: 0.5,
    maxChildSize: 0.97,
    builder: (ctx, scroll, handle, close) => _AddItemContent(
      dayId: dayId,
      spots: spots,
      docs: docs,
      stays: stays,
      initialItem: initialItem,
      prefillItem: prefillItem,
      prefill: prefill,
      defaultCurrency: defaultCurrency,
      scrollController: scroll,
      showDragHandle: handle,
      onSubmit: close,
    ),
  );
}

class _AddItemContent extends StatefulWidget {
  const _AddItemContent({
    required this.dayId,
    required this.spots,
    required this.docs,
    required this.stays,
    required this.onSubmit,
    required this.defaultCurrency,
    this.scrollController,
    this.showDragHandle = false,
    this.initialItem,
    this.prefillItem,
    this.prefill,
  });

  final String dayId;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final List<Accommodation> stays;
  final ValueChanged<ItineraryItem> onSubmit;
  final String defaultCurrency;
  final ScrollController? scrollController;
  final bool showDragHandle;
  final ItineraryItem? initialItem;

  /// A complete new item to start from (Read booking's review screen):
  /// fills every field like [initialItem] but stays in "Add" mode.
  final ItineraryItem? prefillItem;

  /// New-item prefill (Import). Never switches the sheet into edit mode.
  final ImportPrefill? prefill;

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
  final _costCtrl      = TextEditingController();

  ItineraryItemType _type = ItineraryItemType.activity;
  TimeOfDay? _time;
  String? _linkedSpotId;
  String? _linkedStayId;
  final Set<String> _linkedDocIds = {};
  bool _showAdvanced = false;
  late String _currency;

  @override
  void initState() {
    super.initState();
    _currency = widget.defaultCurrency;
    final pre = widget.prefill;
    if (widget.initialItem == null && widget.prefillItem == null && pre != null) {
      _titleCtrl.text    = pre.title ?? '';
      _locationCtrl.text = pre.location ?? '';
      _mapsCtrl.text     = pre.mapsUrl ?? '';
      _confirmCtrl.text  = pre.url ?? '';
      _notesCtrl.text    = pre.notes ?? '';
      _linkedDocIds.addAll(pre.linkedDocIds);
      if (pre.mapsUrl != null || pre.url != null) _showAdvanced = true;
    }
    final item = widget.initialItem ?? widget.prefillItem;
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
      _linkedStayId      = item.linkedStayId;
      _linkedDocIds.addAll(item.linkedDocIds);
      if (item.plannedCost != null) {
        _costCtrl.text = item.plannedCost!.toStringAsFixed(
          item.plannedCost! == item.plannedCost!.truncateToDouble() ? 0 : 2,
        );
      }
      if (item.currency != null) _currency = item.currency!;
      _time = parseTimeOfDay(item.time);
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
    _costCtrl.dispose();
    super.dispose();
  }

  void _applySpot(Spot spot) {
    setState(() {
      _titleCtrl.text    = spot.name;
      _cityCtrl.text     = spot.city.isNotEmpty ? spot.city : spot.area;
      _locationCtrl.text = spot.address ?? '';
      _confirmCtrl.text = '';
      if (spot.mapsUrl != null) {
        _mapsCtrl.text = spot.mapsUrl!;
        _showAdvanced  = true;
      } else {
        _mapsCtrl.text = '';
        _showAdvanced  = false;
      }
      _linkedSpotId  = spot.id;
      _linkedStayId  = null;
      _type          = _typeFromCategory(spot.category);
    });
  }

  void _clearSpot() {
    setState(() => _linkedSpotId = null);
  }

  void _applyStay(Accommodation stay) {
    setState(() {
      _titleCtrl.text    = stay.name;
      _cityCtrl.text     = stay.city;
      _locationCtrl.text = stay.address ?? '';
      _linkedStayId      = stay.id;
      _linkedSpotId      = null;
      _type              = ItineraryItemType.stay;
      _mapsCtrl.text    = '';
      _confirmCtrl.text = '';
      _showAdvanced     = false;
    });
  }

  void _clearStay() {
    setState(() => _linkedStayId = null);
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
      mapsUrl:         _mapsCtrl.text.trim().isNotEmpty ? _mapsCtrl.text.trim() : null,
      confirmationUrl: _confirmCtrl.text.trim().isNotEmpty ? _confirmCtrl.text.trim() : null,
      notes:           _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      linkedSpotId:    _linkedSpotId,
      linkedStayId:    _linkedStayId,
      linkedDocIds:    _linkedDocIds.toList(),
      plannedCost:     double.tryParse(_costCtrl.text.trim()),
      currency:        _costCtrl.text.trim().isNotEmpty ? _currency : null,
    ));
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

                  // ── Fill from spot or stay ────────────────────────────────
                  if (widget.spots.isNotEmpty || widget.stays.isNotEmpty) ...[
                    _FillFromPicker(
                      spots: widget.spots,
                      stays: widget.stays,
                      linkedSpotId: _linkedSpotId,
                      linkedStayId: _linkedStayId,
                      onSpotSelected: _applySpot,
                      onStaySelected: _applyStay,
                      onSpotClear: _clearSpot,
                      onStayClear: _clearStay,
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
                  WabwayTimeField(
                    label: 'Time (optional)',
                    value: _time,
                    onChanged: (t) => setState(() => _time = t),
                  ),
                  const SizedBox(height: kSpace4),

                  // ── Location / Address (with place search) ────────────────
                  PlaceSearchField(
                    label: 'Location / Address',
                    hint: 'e.g. 2-3-1 Asakusa, Taito City',
                    controller: _locationCtrl,
                    onSelected: (p) {
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

                  // ── Attach documents (new items; editing → the item's page)
                  if (widget.initialItem == null)
                  DocMultiPicker(
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
                  const SizedBox(height: kSpace4),

                  // ── Estimated cost ────────────────────────────────────────
                  _CostField(
                    controller: _costCtrl,
                    currency: _currency,
                    onCurrencyChanged: (c) => setState(() => _currency = c),
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

// ─── Estimated cost field ─────────────────────────────────────────────────────


class _CostField extends StatelessWidget {
  const _CostField({
    required this.controller,
    required this.currency,
    required this.onCurrencyChanged,
  });
  final TextEditingController controller;
  final String currency;
  final ValueChanged<String> onCurrencyChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Estimated cost', style: kStyleCaptionMedium),
        const SizedBox(height: 6),
        Row(
          children: [
            // Currency selector
            GestureDetector(
              onTap: () async {
                final picked = await showDialog<String>(
                  context: context,
                  builder: (ctx) => SimpleDialog(
                    backgroundColor: kColorPaper,
                    shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
                    title: Text('Currency', style: kStyleBodySemibold),
                    children: currencyOptions(include: currency)
                        .map((o) => o.$1)
                        .map((c) => SimpleDialogOption(
                              onPressed: () => Navigator.pop(ctx, c),
                              child: Text(c,
                                  style: kStyleBody.copyWith(
                                    fontWeight: c == currency
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                    color: c == currency ? kColorPrimary : null,
                                  )),
                            ))
                        .toList(),
                  ),
                );
                if (picked != null) onCurrencyChanged(picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kColorSurfaceSunken,
                  borderRadius: kRadiusMd,
                  border: Border.all(color: kColorBorder),
                ),
                child: Text(currency,
                    style: kStyleBodyMedium.copyWith(color: kColorInkSoft)),
              ),
            ),
            const SizedBox(width: kSpace2),
            // Amount field
            Expanded(
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                style: kStyleBody,
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: TextStyle(color: kColorInkSoft.withAlpha(120)),
                  border: OutlineInputBorder(
                      borderRadius: kRadiusMd,
                      borderSide: BorderSide(color: kColorBorder)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: kRadiusMd,
                      borderSide: BorderSide(color: kColorPrimary, width: 1.5)),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Combined fill-from picker (spots + stays) ────────────────────────────────

enum _FillSource { spot, stay }

class _FillFromPicker extends StatefulWidget {
  const _FillFromPicker({
    required this.spots,
    required this.stays,
    required this.linkedSpotId,
    required this.linkedStayId,
    required this.onSpotSelected,
    required this.onStaySelected,
    required this.onSpotClear,
    required this.onStayClear,
  });
  final List<Spot> spots;
  final List<Accommodation> stays;
  final String? linkedSpotId;
  final String? linkedStayId;
  final ValueChanged<Spot> onSpotSelected;
  final ValueChanged<Accommodation> onStaySelected;
  final VoidCallback onSpotClear;
  final VoidCallback onStayClear;

  @override
  State<_FillFromPicker> createState() => _FillFromPickerState();
}

class _FillFromPickerState extends State<_FillFromPicker> {
  bool _expanded = false;
  _FillSource _source = _FillSource.spot;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Spot? get _linkedSpot =>
      widget.linkedSpotId == null
          ? null
          : widget.spots.where((s) => s.id == widget.linkedSpotId).firstOrNull;

  Accommodation? get _linkedStay =>
      widget.linkedStayId == null
          ? null
          : widget.stays.where((s) => s.id == widget.linkedStayId).firstOrNull;

  List<Spot> get _filteredSpots {
    if (_query.isEmpty) return widget.spots;
    final q = foldForSearch(_query);
    return widget.spots
        .where((s) => searchMatches(s.name, q) || searchMatches(s.city, q))
        .toList();
  }

  List<Accommodation> get _filteredStays {
    if (_query.isEmpty) return widget.stays;
    final q = foldForSearch(_query);
    return widget.stays
        .where((s) => searchMatches(s.name, q) || searchMatches(s.city, q))
        .toList();
  }

  Widget _linkedBanner({
    required IconData icon,
    required String label,
    required String name,
    required VoidCallback onSwap,
    required VoidCallback onClear,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
      decoration: BoxDecoration(
        color: kColorPrimarySoft,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorPrimary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: kColorPrimary),
          const SizedBox(width: kSpace2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: kStyleCaption.copyWith(color: kColorPrimary)),
                Text(name, style: kStyleBodySemibold, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          GestureDetector(
            onTap: () { setState(() => _expanded = true); onSwap(); },
            child: const Icon(Icons.swap_horiz_rounded, size: 16, color: kColorPrimary),
          ),
          const SizedBox(width: kSpace2),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded, size: 16, color: kColorPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final linkedSpot = _linkedSpot;
    final linkedStay = _linkedStay;

    if (linkedSpot != null && !_expanded) {
      return _linkedBanner(
        icon: Icons.place_rounded,
        label: 'Filled from spot',
        name: linkedSpot.name,
        onSwap: () { setState(() => _source = _FillSource.spot); widget.onSpotClear(); },
        onClear: widget.onSpotClear,
      );
    }
    if (linkedStay != null && !_expanded) {
      return _linkedBanner(
        icon: Icons.hotel_rounded,
        label: 'Filled from stay',
        name: linkedStay.name,
        onSwap: () { setState(() => _source = _FillSource.stay); widget.onStayClear(); },
        onClear: widget.onStayClear,
      );
    }

    if (!_expanded) {
      return GestureDetector(
        onTap: () => setState(() {
          _expanded = true;
          _source = widget.spots.isNotEmpty ? _FillSource.spot : _FillSource.stay;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
          decoration: BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
            border: Border.all(color: kColorBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.add_link_rounded, size: 16, color: kColorInkSoft),
              const SizedBox(width: kSpace2),
              Text('Fill from spot or stay',
                  style: kStyleBody.copyWith(color: kColorInkSoft)),
              const Spacer(),
              const Icon(Icons.expand_more_rounded, size: 16, color: kColorInkSoft),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tab row + search
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace3, kSpace2, kSpace2, kSpace2),
            child: Row(
              children: [
                if (widget.spots.isNotEmpty) ...[
                  GestureDetector(
                    onTap: () => setState(() { _source = _FillSource.spot; _query = ''; _searchCtrl.clear(); }),
                    child: Text('Spots',
                        style: kStyleCaptionMedium.copyWith(
                          color: _source == _FillSource.spot ? kColorPrimary : kColorInkSoft,
                          decoration: _source == _FillSource.spot ? TextDecoration.underline : null,
                        )),
                  ),
                  const SizedBox(width: kSpace3),
                ],
                if (widget.stays.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() { _source = _FillSource.stay; _query = ''; _searchCtrl.clear(); }),
                    child: Text('Stays',
                        style: kStyleCaptionMedium.copyWith(
                          color: _source == _FillSource.stay ? kColorPrimary : kColorInkSoft,
                          decoration: _source == _FillSource.stay ? TextDecoration.underline : null,
                        )),
                  ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 16),
                  color: kColorInkSoft,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() {
                    _expanded = false;
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace3, 0, kSpace3, kSpace2),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              style: kStyleBody,
              decoration: InputDecoration(
                hintText: _source == _FillSource.spot ? 'Search spots…' : 'Search stays…',
                hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: kColorInkSoft),
                border: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorPrimary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: kSpace2, vertical: 8),
              ),
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: _source == _FillSource.spot
                ? _buildSpotList()
                : _buildStayList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSpotList() {
    final filtered = _filteredSpots;
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Text('No spots match', style: kStyleCaption.copyWith(color: kColorInkSoft)),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = filtered[i];
        return ListTile(
          dense: true,
          leading: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: _typeFromCategory(s.category).softColor, borderRadius: kRadiusSm),
            child: Icon(s.category.icon, size: 14, color: _typeFromCategory(s.category).color),
          ),
          title: Text(s.name, style: kStyleBodyMedium),
          subtitle: Text(s.city, style: kStyleCaption.copyWith(color: kColorInkSoft)),
          onTap: () {
            setState(() { _expanded = false; _searchCtrl.clear(); _query = ''; });
            widget.onSpotSelected(s);
          },
        );
      },
    );
  }

  Widget _buildStayList() {
    final filtered = _filteredStays;
    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Text('No stays match', style: kStyleCaption.copyWith(color: kColorInkSoft)),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final s = filtered[i];
        return ListTile(
          dense: true,
          leading: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: ItineraryItemType.stay.softColor, borderRadius: kRadiusSm),
            child: Icon(s.source?.icon ?? Icons.hotel_rounded, size: 14, color: ItineraryItemType.stay.color),
          ),
          title: Text(s.name, style: kStyleBodyMedium),
          subtitle: Text(
            [s.city, if (s.status == AccommodationStatus.booked) 'Booked'].join(' · '),
            style: kStyleCaption.copyWith(color: kColorInkSoft),
          ),
          onTap: () {
            setState(() { _expanded = false; _searchCtrl.clear(); _query = ''; });
            widget.onStaySelected(s);
          },
        );
      },
    );
  }
}

