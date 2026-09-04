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

// ─── Helpers ──────────────────────────────────────────────────────────────────

ItineraryItemType _typeFromCategory(SpotCategory cat) => switch (cat) {
  SpotCategory.food => ItineraryItemType.food,
  _                 => ItineraryItemType.spot,
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
            stays: stays,
            initialItem: initialItem,
            defaultCurrency: defaultCurrency,
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
      stays: stays,
      initialItem: initialItem,
      defaultCurrency: defaultCurrency,
      onSubmit: (item) => Navigator.pop(ctx, item),
    ),
  );
}

class _AddItemSheet extends StatelessWidget {
  const _AddItemSheet({
    required this.dayId,
    required this.spots,
    required this.docs,
    required this.stays,
    required this.onSubmit,
    required this.defaultCurrency,
    this.initialItem,
  });
  final String dayId;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final List<Accommodation> stays;
  final ValueChanged<ItineraryItem> onSubmit;
  final String defaultCurrency;
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
          stays: stays,
          initialItem: initialItem,
          defaultCurrency: defaultCurrency,
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
    required this.stays,
    required this.onSubmit,
    required this.defaultCurrency,
    this.scrollController,
    this.showDragHandle = false,
    this.initialItem,
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
      _linkedStayId      = item.linkedStayId;
      _linkedDocIds.addAll(item.linkedDocIds);
      if (item.plannedCost != null) {
        _costCtrl.text = item.plannedCost!.toStringAsFixed(
          item.plannedCost! == item.plannedCost!.truncateToDouble() ? 0 : 2,
        );
      }
      if (item.currency != null) _currency = item.currency!;
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
                  _TimePicker(
                    selected: _time,
                    onTap: _pickTime,
                    onClear: () => setState(() => _time = null),
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

const _kCurrencies = ['JPY', 'USD', 'EUR', 'CAD', 'GBP', 'AUD', 'KRW', 'THB', 'SGD', 'HKD', 'CNY'];

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
                    children: _kCurrencies
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
    final q = _query.toLowerCase();
    return widget.spots
        .where((s) => s.name.toLowerCase().contains(q) || s.city.toLowerCase().contains(q))
        .toList();
  }

  List<Accommodation> get _filteredStays {
    if (_query.isEmpty) return widget.stays;
    final q = _query.toLowerCase();
    return widget.stays
        .where((s) => s.name.toLowerCase().contains(q) || s.city.toLowerCase().contains(q))
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
