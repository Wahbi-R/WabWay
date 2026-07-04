import 'package:flutter/material.dart';
import '../../data/travel_data.dart';
import '../../data/docs_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

Future<TravelItem?> showAddTravelSheet(
  BuildContext context, {
  List<TripDocument> docs = const [],
  TravelItem? initialItem,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<TravelItem>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding: const EdgeInsets.symmetric(
            horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(ctx).height * 0.90,
          child: _AddTravelContent(
            docs: docs,
            initialItem: initialItem,
            onSubmit: (item) => Navigator.pop(ctx, item),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<TravelItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddTravelSheet(
      docs: docs,
      initialItem: initialItem,
      onSubmit: (item) => Navigator.pop(ctx, item),
    ),
  );
}

class _AddTravelSheet extends StatelessWidget {
  const _AddTravelSheet({required this.onSubmit, required this.docs, this.initialItem});
  final ValueChanged<TravelItem> onSubmit;
  final List<TripDocument> docs;
  final TravelItem? initialItem;

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
        child: _AddTravelContent(
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

class _AddTravelContent extends StatefulWidget {
  const _AddTravelContent({
    required this.onSubmit,
    required this.docs,
    this.scrollController,
    this.showDragHandle = false,
    this.initialItem,
  });

  final ValueChanged<TravelItem> onSubmit;
  final List<TripDocument> docs;
  final ScrollController? scrollController;
  final bool showDragHandle;
  final TravelItem? initialItem;

  @override
  State<_AddTravelContent> createState() => _AddTravelContentState();
}

class _AddTravelContentState extends State<_AddTravelContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  TravelItemType _type = TravelItemType.flight;
  TravelBookingStatus _status = TravelBookingStatus.booked;
  DateTime? _date;
  DateTime? _endDate;
  TimeOfDay? _time;
  TimeOfDay? _endTime;
  final Set<String> _linkedDocIds = {};

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item != null) {
      _titleCtrl.text = item.title;
      _locationCtrl.text = item.location ?? '';
      _destinationCtrl.text = item.destination ?? '';
      _addressCtrl.text = item.address ?? '';
      _confirmCtrl.text = item.confirmationNumber ?? '';
      _notesCtrl.text = item.notes ?? '';
      _type   = item.type;
      _status = item.status;
      _date   = item.date;
      _endDate = item.endDate;
      _time = _parseTime(item.time);
      _endTime = _parseTime(item.endTime);
      _linkedDocIds.addAll(item.linkedDocIds);
    }
  }

  static TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length != 2) return null;
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _destinationCtrl.dispose();
    _addressCtrl.dispose();
    _confirmCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(TravelItem(
      id: widget.initialItem?.id ?? 't_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      type: _type,
      status: _status,
      date: _date,
      endDate: _endDate,
      time: _fmt(_time),
      endTime: _fmt(_endTime),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      destination: _destinationCtrl.text.trim().isEmpty ? null : _destinationCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      confirmationNumber: _confirmCtrl.text.trim().isEmpty ? null : _confirmCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      linkedDocIds: _linkedDocIds.toList(),
    ));
  }

  String? _fmt(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isEnd) async {
    final initial = isEnd ? (_endDate ?? _date ?? DateTime.now()) : (_date ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => isEnd ? _endDate = picked : _date = picked);
    }
  }

  Future<void> _pickTime(bool isEnd) async {
    final initial = isEnd ? (_endTime ?? TimeOfDay.now()) : (_time ?? TimeOfDay.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => isEnd ? _endTime = picked : _time = picked);
    }
  }

  bool get _isTransit =>
      _type == TravelItemType.flight || _type == TravelItemType.train;
  bool get _isMultiDay =>
      _type == TravelItemType.hotel || _type == TravelItemType.train;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle)
          Padding(
            padding: const EdgeInsets.only(top: kSpace3, bottom: kSpace1),
            child: Container(
              width: 40,
              height: 4,
              decoration: const BoxDecoration(
                  color: kColorBorder, borderRadius: kRadiusPill),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: Row(
            children: [
              Text(widget.initialItem != null ? 'Edit travel item' : 'Add travel item', style: kStyleTitle),
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
                  Row(
                    children: [
                      Expanded(
                        child: WabwaySelectField<TravelItemType>(
                          label: 'Type',
                          value: _type,
                          onChanged: (v) =>
                              setState(() => _type = v ?? TravelItemType.flight),
                          items: TravelItemType.values
                              .map((t) => WabwaySelectItem(value: t, label: t.label))
                              .toList(),
                        ),
                      ),
                      const SizedBox(width: kSpace3),
                      Expanded(
                        child: WabwaySelectField<TravelBookingStatus>(
                          label: 'Status',
                          value: _status,
                          onChanged: (v) =>
                              setState(() => _status = v ?? TravelBookingStatus.booked),
                          items: TravelBookingStatus.values
                              .map((s) => WabwaySelectItem(value: s, label: s.label))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Title',
                    hint: _type == TravelItemType.flight
                        ? 'e.g. JAL JL723 — Outbound flight'
                        : _type == TravelItemType.hotel
                            ? 'e.g. Hotel Shinjuku'
                            : _type == TravelItemType.train
                                ? 'e.g. Shinkansen — Tokyo → Kyoto'
                                : _type == TravelItemType.ticket
                                    ? 'e.g. teamLab Borderless — 4 tickets'
                                    : 'e.g. Dinner reservation',
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: kSpace4),

                  // Date row
                  Row(
                    children: [
                      Expanded(
                        child: _DatePicker(
                          label: _type == TravelItemType.hotel
                              ? 'Check-in date'
                              : 'Date',
                          date: _date,
                          onTap: () => _pickDate(false),
                          onClear: () => setState(() => _date = null),
                        ),
                      ),
                      if (_isMultiDay) ...[
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: _DatePicker(
                            label: _type == TravelItemType.hotel
                                ? 'Check-out date'
                                : 'End date',
                            date: _endDate,
                            onTap: () => _pickDate(true),
                            onClear: () => setState(() => _endDate = null),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  // Time row
                  Row(
                    children: [
                      Expanded(
                        child: _TimePicker(
                          label: _type == TravelItemType.hotel
                              ? 'Check-in time'
                              : _type == TravelItemType.reservation
                                  ? 'Time'
                                  : 'Departs',
                          time: _time,
                          onTap: () => _pickTime(false),
                          onClear: () => setState(() => _time = null),
                        ),
                      ),
                      if (_isTransit || _type == TravelItemType.hotel) ...[
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: _TimePicker(
                            label: _type == TravelItemType.hotel
                                ? 'Check-out time'
                                : 'Arrives',
                            time: _endTime,
                            onTap: () => _pickTime(true),
                            onClear: () => setState(() => _endTime = null),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: _isTransit ? 'From (origin)' : 'Location',
                    hint: _type == TravelItemType.flight
                        ? 'e.g. London Heathrow (LHR)'
                        : _type == TravelItemType.train
                            ? 'e.g. Tokyo Station'
                            : _type == TravelItemType.hotel
                                ? 'e.g. Shinjuku, Tokyo'
                                : 'e.g. Azabudai Hills, Tokyo',
                    controller: _locationCtrl,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: kSpace4),

                  if (_isTransit) ...[
                    WabwayTextField(
                      label: 'To (destination)',
                      hint: _type == TravelItemType.flight
                          ? 'e.g. Narita International Airport (NRT)'
                          : 'e.g. Kyoto Station',
                      controller: _destinationCtrl,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: kSpace4),
                  ] else ...[
                    WabwayTextField(
                      label: 'Address (optional)',
                      hint: 'Street address',
                      controller: _addressCtrl,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: kSpace4),
                  ],

                  WabwayTextField(
                    label: 'Confirmation number (optional)',
                    hint: 'Booking reference',
                    controller: _confirmCtrl,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Notes (optional)',
                    hint: 'Any useful details…',
                    controller: _notesCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: kSpace4),

                  _DocsPicker(
                    docs: widget.docs,
                    selectedIds: _linkedDocIds,
                    onChanged: (id, checked) => setState(() {
                      if (checked) {
                        _linkedDocIds.add(id);
                      } else {
                        _linkedDocIds.remove(id);
                      }
                    }),
                  ),
                  const SizedBox(height: kSpace6),

                  WabwayButton(
                    label: widget.initialItem != null ? 'Save changes' : 'Add travel item',
                    icon: Icons.flight_rounded,
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

// ─── Date picker field ────────────────────────────────────────────────────────

class _DatePicker extends StatelessWidget {
  const _DatePicker({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: kStyleCaptionMedium.copyWith(color: kColorInk)),
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
                color: date != null ? kColorPrimary : kColorBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 16,
                    color: date != null ? kColorPrimary : kColorInkSoft),
                const SizedBox(width: kSpace2),
                Expanded(
                  child: Text(
                    date != null
                        ? '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}'
                        : 'Select date',
                    style: kStyleBody.copyWith(
                      color: date != null ? kColorInk : kColorInkSoft,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (date != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: kColorInkSoft),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Time picker field ────────────────────────────────────────────────────────

class _TimePicker extends StatelessWidget {
  const _TimePicker({
    required this.label,
    required this.time,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final TimeOfDay? time;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: kStyleCaptionMedium.copyWith(color: kColorInk)),
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
                color: time != null ? kColorPrimary : kColorBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 16,
                    color: time != null ? kColorPrimary : kColorInkSoft),
                const SizedBox(width: kSpace2),
                Expanded(
                  child: Text(
                    time != null
                        ? '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}'
                        : '—',
                    style: kStyleBody.copyWith(
                      color: time != null ? kColorInk : kColorInkSoft,
                    ),
                  ),
                ),
                if (time != null)
                  GestureDetector(
                    onTap: onClear,
                    child: const Icon(Icons.close_rounded,
                        size: 16, color: kColorInkSoft),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Document multi-picker ────────────────────────────────────────────────────

class _DocsPicker extends StatelessWidget {
  const _DocsPicker({
    required this.docs,
    required this.selectedIds,
    required this.onChanged,
  });
  final List<TripDocument> docs;
  final Set<String> selectedIds;
  final void Function(String id, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    if (docs.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attach documents (optional)',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        ...docs.map((d) {
          final checked = selectedIds.contains(d.id);
          return CheckboxListTile(
            value: checked,
            onChanged: (v) => onChanged(d.id, v ?? false),
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
    );
  }
}
