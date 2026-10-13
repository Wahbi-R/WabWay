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
import '../../data/date_utils.dart';
import '../../widgets/place_search_field.dart';
import '../../data/share_data.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

Future<TravelItem?> showAddTravelSheet(
  BuildContext context, {
  List<TripDocument> docs = const [],
  TravelItem? initialItem,
  ImportPrefill? prefill,
}) {
  return showWabwayFormSheet<TravelItem>(
    context,
    desktopHeightFactor: 0.90,
    initialChildSize: 0.92,
    minChildSize: 0.5,
    maxChildSize: 0.97,
    builder: (ctx, scroll, handle, close) => _AddTravelContent(
      docs: docs,
      initialItem: initialItem,
      prefill: prefill,
      scrollController: scroll,
      showDragHandle: handle,
      onSubmit: close,
    ),
  );
}

class _AddTravelContent extends StatefulWidget {
  const _AddTravelContent({
    required this.onSubmit,
    required this.docs,
    this.scrollController,
    this.showDragHandle = false,
    this.initialItem,
    this.prefill,
  });

  final ValueChanged<TravelItem> onSubmit;
  final List<TripDocument> docs;
  final ScrollController? scrollController;
  final bool showDragHandle;
  final TravelItem? initialItem;

  /// New-item prefill (Import). Never switches the sheet into edit mode.
  final ImportPrefill? prefill;

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
    } else if (widget.prefill != null) {
      final pre = widget.prefill!;
      _titleCtrl.text       = pre.title ?? '';
      _locationCtrl.text    = pre.location ?? '';
      _destinationCtrl.text = pre.destination ?? '';
      _confirmCtrl.text     = pre.confirmationNumber ?? '';
      _urlCtrl.text         = pre.url ?? '';
      _notesCtrl.text       = pre.notes ?? '';
      _date                 = pre.date;
      _endDate              = pre.endDate;
      _linkedDocIds.addAll(pre.linkedDocIds);
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

  String? _fmt(TimeOfDay? t) => t == null ? null : fmtTimeOfDay(t.hour, t.minute);

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
        showWabwaySnack(context, 'Could not read boarding pass — fill in manually.');
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

  /// Biases place search toward the right kind of place for the travel type.
  String? get _placeSuffix => switch (_type) {
        TravelItemType.flight => 'airport',
        TravelItemType.train  => 'station',
        TravelItemType.ferry  => 'port',
        _                     => null,
      };
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
                  WabwayChoiceChips<TravelItemType>(
                    label: 'Type',
                    choices: [
                      for (final t in TravelItemType.values) WabwayChoice(t, t.label, icon: t.icon),
                    ],
                    selected: _type,
                    onChanged: (t) => setState(() => _type = t),
                  ),
                  const SizedBox(height: kSpace4),
                  WabwayChoiceChips<TravelBookingStatus>(
                    label: 'Status',
                    choices: [
                      for (final st in TravelBookingStatus.values)
                        WabwayChoice(st, st.label, icon: st.icon, color: st.color),
                    ],
                    selected: _status,
                    onChanged: (st) => setState(() => _status = st),
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
                        child: WabwayPickerField(
                          label: _type == TravelItemType.car ? 'Pick-up date' : 'Date',
                          value: _date == null ? null : fmtDateLong(_date!),
                          onTap: () => _pickDate(false),
                          onClear: () => setState(() => _date = null),
                        ),
                      ),
                      if (_isMultiDay) ...[
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: WabwayPickerField(
                            label: _type == TravelItemType.car ? 'Return date' : 'End date',
                            value: _endDate == null ? null : fmtDateLong(_endDate!),
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
                        child: WabwayPickerField(
                          label: _type == TravelItemType.car ? 'Pick-up time' : 'Departs',
                          icon: Icons.schedule_rounded,
                          value: _time == null ? null : fmtTimeOfDay(_time!.hour, _time!.minute),
                          onTap: () => _pickTime(false),
                          onClear: () => setState(() => _time = null),
                        ),
                      ),
                      if (_isTransit) ...[
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: WabwayPickerField(
                            label: _type == TravelItemType.car ? 'Return time' : 'Arrives',
                            icon: Icons.schedule_rounded,
                            value: _endTime == null ? null : fmtTimeOfDay(_endTime!.hour, _endTime!.minute),
                            onTap: () => _pickTime(true),
                            onClear: () => setState(() => _endTime = null),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  PlaceSearchField(
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
                    querySuffix: _placeSuffix,
                    onSelected: (p) => setState(() {
                      if (!_isTransit && p.address.isNotEmpty && _addressCtrl.text.trim().isEmpty) {
                        _addressCtrl.text = p.address;
                      }
                    }),
                  ),
                  const SizedBox(height: kSpace4),

                  if (_isTransit) ...[
                    PlaceSearchField(
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
                      querySuffix: _placeSuffix,
                      onSelected: (_) {},
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
                    hint: 'e.g. ABC123',
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
                      WabwayPickerField(
                        label: 'Boarding time (optional)',
                        icon: Icons.schedule_rounded,
                        value: _boardingTime == null ? null : fmtTimeOfDay(_boardingTime!.hour, _boardingTime!.minute),
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

                  // Editing: documents are managed on the item's page.
                  if (widget.initialItem == null)
                  DocMultiPicker(
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
