import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/ocr/boarding_pass_parser.dart';
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
  final _formKey          = GlobalKey<FormState>();
  final _titleCtrl        = TextEditingController();
  final _locationCtrl     = TextEditingController();
  final _destinationCtrl  = TextEditingController();
  final _addressCtrl      = TextEditingController();
  final _confirmCtrl      = TextEditingController();
  final _urlCtrl          = TextEditingController();
  final _notesCtrl        = TextEditingController();
  final _depTerminalCtrl  = TextEditingController();
  final _arrTerminalCtrl  = TextEditingController();
  final _gateCtrl         = TextEditingController();
  final _seatCtrl         = TextEditingController();

  TravelItemType _type = TravelItemType.flight;
  TravelBookingStatus _status = TravelBookingStatus.booked;
  DateTime? _date;
  DateTime? _endDate;
  TimeOfDay? _time;
  TimeOfDay? _endTime;
  TimeOfDay? _boardingTime;
  final Set<String> _linkedDocIds = {};

  bool _scanningPass = false;
  Uint8List? _boardingPassBytes;

  @override
  void initState() {
    super.initState();
    final item = widget.initialItem;
    if (item != null) {
      _titleCtrl.text       = item.title;
      _locationCtrl.text    = item.location ?? '';
      _destinationCtrl.text = item.destination ?? '';
      _addressCtrl.text     = item.address ?? '';
      _confirmCtrl.text     = item.confirmationNumber ?? '';
      _urlCtrl.text         = item.url ?? '';
      _notesCtrl.text       = item.notes ?? '';
      _depTerminalCtrl.text = item.departureTerminal ?? '';
      _arrTerminalCtrl.text = item.arrivalTerminal ?? '';
      _gateCtrl.text        = item.gate ?? '';
      _seatCtrl.text        = item.seat ?? '';
      _type         = item.type;
      _status       = item.status;
      _date         = item.date;
      _endDate      = item.endDate;
      _time         = _parseTime(item.time);
      _endTime      = _parseTime(item.endTime);
      _boardingTime = _parseTime(item.boardingTime);
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
    _urlCtrl.dispose();
    _notesCtrl.dispose();
    _depTerminalCtrl.dispose();
    _arrTerminalCtrl.dispose();
    _gateCtrl.dispose();
    _seatCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(TravelItem(
      id:                 widget.initialItem?.id ?? 't_${DateTime.now().millisecondsSinceEpoch}',
      title:              _titleCtrl.text.trim(),
      type:               _type,
      status:             _status,
      date:               _date,
      endDate:            _endDate,
      time:               _fmt(_time),
      endTime:            _fmt(_endTime),
      boardingTime:       _fmt(_boardingTime),
      location:           _nz(_locationCtrl.text),
      destination:        _nz(_destinationCtrl.text),
      address:            _nz(_addressCtrl.text),
      confirmationNumber: _nz(_confirmCtrl.text),
      url:                _nz(_urlCtrl.text),
      notes:              _nz(_notesCtrl.text),
      departureTerminal:  _nz(_depTerminalCtrl.text),
      arrivalTerminal:    _nz(_arrTerminalCtrl.text),
      gate:               _nz(_gateCtrl.text),
      seat:               _nz(_seatCtrl.text),
      linkedDocIds:       _linkedDocIds.toList(),
    ));
  }

  String? _nz(String s) => s.trim().isEmpty ? null : s.trim();

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

  Future<void> _scanBoardingPass() async {
    final source = await _pickImageSource();
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? file = await picker.pickImage(source: source, imageQuality: 90);
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    final ext   = file.path.split('.').last;

    setState(() {
      _boardingPassBytes = bytes;
      _scanningPass      = true;
    });

    try {
      final data = await BoardingPassParser.parse(bytes, ext);
      if (!mounted) return;
      if (data == null || !data.hasUsefulData) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read boarding pass — fill in manually.')),
        );
        return;
      }
      setState(() {
        if (data.flightNumber != null && _titleCtrl.text.isEmpty) {
          _titleCtrl.text = data.buildTitle().isNotEmpty
              ? data.buildTitle()
              : data.flightNumber!;
        }
        if (data.confirmationNumber != null && _confirmCtrl.text.isEmpty)
          _confirmCtrl.text = data.confirmationNumber!;
        if (data.buildLocationField().isNotEmpty && _locationCtrl.text.isEmpty)
          _locationCtrl.text = data.buildLocationField();
        if (data.buildDestinationField().isNotEmpty && _destinationCtrl.text.isEmpty)
          _destinationCtrl.text = data.buildDestinationField();
        if (data.departureTerminal != null && _depTerminalCtrl.text.isEmpty)
          _depTerminalCtrl.text = data.departureTerminal!;
        if (data.arrivalTerminal != null && _arrTerminalCtrl.text.isEmpty)
          _arrTerminalCtrl.text = data.arrivalTerminal!;
        if (data.gate != null && _gateCtrl.text.isEmpty)
          _gateCtrl.text = data.gate!;
        if (data.seat != null && _seatCtrl.text.isEmpty)
          _seatCtrl.text = data.seat!;
        if (data.date != null && _date == null) _date = data.date;
        if (data.departureTime != null && _time == null)
          _time = _parseTime(data.departureTime);
        if (data.arrivalTime != null && _endTime == null)
          _endTime = _parseTime(data.arrivalTime);
        if (data.boardingTime != null && _boardingTime == null)
          _boardingTime = _parseTime(data.boardingTime);
        if (data.cabinClass != null && _notesCtrl.text.isEmpty)
          _notesCtrl.text = data.cabinClass!;
        _type = TravelItemType.flight;
      });
    } finally {
      if (mounted) setState(() => _scanningPass = false);
    }
  }

  Future<ImageSource?> _pickImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isTransit => _type != TravelItemType.other;
  bool get _isMultiDay => _type == TravelItemType.car;

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
                  const SizedBox(height: kSpace3),

                  // Boarding pass scan button (flights only, requires Gemini)
                  if (_type == TravelItemType.flight && BoardingPassParser.isAvailable)
                    _BoardingPassButton(
                      scanning: _scanningPass,
                      hasPass:  _boardingPassBytes != null,
                      onTap:    _scanBoardingPass,
                    ),
                  if (_type == TravelItemType.flight && BoardingPassParser.isAvailable)
                    const SizedBox(height: kSpace3),

                  WabwayTextField(
                    label: 'Title',
                    hint: _type == TravelItemType.flight
                        ? 'e.g. JAL JL723 — Outbound flight'
                        : _type == TravelItemType.train
                            ? 'e.g. Shinkansen — Tokyo → Kyoto'
                            : _type == TravelItemType.bus
                                ? 'e.g. JR Bus — Kyoto → Hiroshima'
                                : _type == TravelItemType.ferry
                                    ? 'e.g. Ferry — Hiroshima → Miyajima'
                                    : _type == TravelItemType.car
                                        ? 'e.g. Toyota Rental — Hokkaido road trip'
                                        : 'e.g. teamLab Borderless tickets',
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
                          label: _type == TravelItemType.car ? 'Pick-up date' : 'Date',
                          date: _date,
                          onTap: () => _pickDate(false),
                          onClear: () => setState(() => _date = null),
                        ),
                      ),
                      if (_isMultiDay) ...[
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: _DatePicker(
                            label: _type == TravelItemType.car ? 'Return date' : 'End date',
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
                          label: _type == TravelItemType.car ? 'Pick-up time' : 'Departs',
                          time: _time,
                          onTap: () => _pickTime(false),
                          onClear: () => setState(() => _time = null),
                        ),
                      ),
                      if (_isTransit) ...[
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: _TimePicker(
                            label: _type == TravelItemType.car ? 'Return time' : 'Arrives',
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
                            : _type == TravelItemType.bus
                                ? 'e.g. Kyoto Station Bus Terminal'
                                : _type == TravelItemType.ferry
                                    ? 'e.g. Hiroshima Port'
                                    : _type == TravelItemType.car
                                        ? 'e.g. Sapporo Airport'
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
                          : _type == TravelItemType.ferry
                              ? 'e.g. Miyajima Island'
                              : _type == TravelItemType.car
                                  ? 'e.g. Hakodate'
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

                  // Terminal / gate / seat (transit only)
                  if (_isTransit) ...[
                    Row(
                      children: [
                        Expanded(
                          child: WabwayTextField(
                            label: 'Dep. terminal (optional)',
                            hint: 'e.g. Terminal 1',
                            controller: _depTerminalCtrl,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: WabwayTextField(
                            label: 'Arr. terminal (optional)',
                            hint: 'e.g. Terminal 3',
                            controller: _arrTerminalCtrl,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace4),
                    Row(
                      children: [
                        Expanded(
                          child: WabwayTextField(
                            label: 'Gate (optional)',
                            hint: 'e.g. A22',
                            controller: _gateCtrl,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: WabwayTextField(
                            label: 'Seat (optional)',
                            hint: 'e.g. 14C',
                            controller: _seatCtrl,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace4),
                    if (_type == TravelItemType.flight)
                      _TimePicker(
                        label: 'Boarding time (optional)',
                        time: _boardingTime,
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _boardingTime ?? TimeOfDay.now(),
                            builder: (ctx, child) => MediaQuery(
                              data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
                              child: child!,
                            ),
                          );
                          if (picked != null) setState(() => _boardingTime = picked);
                        },
                        onClear: () => setState(() => _boardingTime = null),
                      ),
                    if (_type == TravelItemType.flight) const SizedBox(height: kSpace4),
                  ],

                  WabwayTextField(
                    label: 'Booking URL (optional)',
                    hint: 'https://…',
                    controller: _urlCtrl,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.url,
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

// ─── Boarding pass button ─────────────────────────────────────────────────────

class _BoardingPassButton extends StatelessWidget {
  const _BoardingPassButton({
    required this.scanning,
    required this.hasPass,
    required this.onTap,
  });
  final bool scanning;
  final bool hasPass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: scanning ? null : onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: hasPass
              ? kColorPrimary.withValues(alpha: 0.08)
              : kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border: Border.all(
            color: hasPass ? kColorPrimary : kColorBorder,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: kSpace3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (scanning)
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                hasPass
                    ? Icons.airplane_ticket_rounded
                    : Icons.document_scanner_rounded,
                size: 16,
                color: hasPass ? kColorPrimary : kColorInkSoft,
              ),
            const SizedBox(width: kSpace2),
            Text(
              scanning
                  ? 'Reading boarding pass…'
                  : hasPass
                      ? 'Boarding pass scanned ✓  Tap to redo'
                      : 'Scan boarding pass to auto-fill',
              style: kStyleCaption.copyWith(
                color: hasPass ? kColorPrimary : kColorInkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
