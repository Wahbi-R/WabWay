import 'package:flutter/material.dart';
import '../../core/supabase/trip_service.dart';
import '../../core/trip/app_trip.dart';
import '../../core/trip/trip_state.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

Future<void> showTripSettingsSheet(
  BuildContext context, {
  required AppTrip trip,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TripSettingsSheet(
      trip: trip,
      onSaved: () => TripState.refresh(context),
    ),
  );
}

// ─── Currencies ───────────────────────────────────────────────────────────────

const _kCurrencies = [
  ('JPY', '¥ Japanese Yen'),
  ('USD', '\$ US Dollar'),
  ('EUR', '€ Euro'),
  ('GBP', '£ British Pound'),
  ('AUD', 'A\$ Australian Dollar'),
  ('CAD', 'C\$ Canadian Dollar'),
  ('SGD', 'S\$ Singapore Dollar'),
  ('HKD', 'HK\$ Hong Kong Dollar'),
  ('KRW', '₩ Korean Won'),
  ('THB', '฿ Thai Baht'),
  ('TWD', 'NT\$ Taiwan Dollar'),
  ('MYR', 'RM Malaysian Ringgit'),
  ('IDR', 'Rp Indonesian Rupiah'),
  ('VND', '₫ Vietnamese Dong'),
  ('PHP', '₱ Philippine Peso'),
];

// ─── Sheet ────────────────────────────────────────────────────────────────────

class _TripSettingsSheet extends StatefulWidget {
  const _TripSettingsSheet({required this.trip, required this.onSaved});
  final AppTrip trip;
  final VoidCallback onSaved;

  @override
  State<_TripSettingsSheet> createState() => _TripSettingsSheetState();
}

class _TripSettingsSheetState extends State<_TripSettingsSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _destinationCtrl;
  DateTime? _startDate;
  DateTime? _endDate;
  late String _currency;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl        = TextEditingController(text: widget.trip.name);
    _destinationCtrl = TextEditingController(text: widget.trip.destination ?? '');
    _startDate       = widget.trip.startDate;
    _endDate         = widget.trip.endDate;
    _currency        = widget.trip.defaultCurrency;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial  = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final firstDate = isStart ? DateTime(2020) : (_startDate ?? DateTime(2020));
    final lastDate  = DateTime(2040);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kColorPrimary),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Trip name cannot be empty.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final dest = _destinationCtrl.text.trim();
      await TripService.updateTrip(
        widget.trip.id,
        name:            name,
        destination:     dest.isEmpty ? null : dest,
        clearDestination: dest.isEmpty,
        startDate:  _startDate,
        clearStartDate: _startDate == null && widget.trip.startDate != null,
        endDate:    _endDate,
        clearEndDate: _endDate == null && widget.trip.endDate != null,
        defaultCurrency: _currency,
      );
      if (!mounted) return;
      widget.onSaved();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = e.toString(); });
    }
  }

  String _fmtDate(DateTime d) {
    const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${mo[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: Column(
          children: [
            const WabwayDragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace5, kSpace3, kSpace5, 0),
              child: Row(
                children: [
                  Text('Trip settings', style: kStyleTitle),
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
                controller: ctrl,
                padding: EdgeInsets.fromLTRB(
                  kSpace5, 0, kSpace5, kSpace6 + bottomPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WabwayTextField(
                      label: 'Trip name',
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: kSpace4),

                    DestinationAutocomplete(
                      controller: _destinationCtrl,
                      label: 'Destination',
                      hint: 'e.g. Japan',
                    ),
                    const SizedBox(height: kSpace4),

                    // Date fields
                    Text('Dates', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                    const SizedBox(height: kSpace2),
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Start',
                            value: _startDate != null ? _fmtDate(_startDate!) : null,
                            placeholder: 'Not set',
                            onTap: () => _pickDate(isStart: true),
                            onClear: _startDate != null
                                ? () => setState(() => _startDate = null)
                                : null,
                          ),
                        ),
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: _DateField(
                            label: 'End',
                            value: _endDate != null ? _fmtDate(_endDate!) : null,
                            placeholder: 'Not set',
                            onTap: () => _pickDate(isStart: false),
                            onClear: _endDate != null
                                ? () => setState(() => _endDate = null)
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: kSpace4),

                    // Currency
                    Text('Default currency',
                        style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                    const SizedBox(height: kSpace2),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: kColorSurfaceSunken,
                        borderRadius: kRadiusMd,
                        border: Border.all(color: kColorBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currency,
                          isExpanded: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: kSpace3, vertical: 2),
                          borderRadius: kRadiusMd,
                          items: _kCurrencies.map((c) {
                            final (code, label) = c;
                            return DropdownMenuItem(
                              value: code,
                              child: Text(label, style: kStyleBodyMedium),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _currency = v);
                          },
                        ),
                      ),
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: kSpace3),
                      Text(_error!,
                          style: kStyleCaption.copyWith(color: kColorDanger)),
                    ],
                    const SizedBox(height: kSpace6),
                    WabwayButton(
                      label: 'Save changes',
                      icon: Icons.check_rounded,
                      fullWidth: true,
                      size: WabwayButtonSize.lg,
                      loading: _saving,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date field ───────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border: Border.all(color: kColorBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace3, vertical: kSpace3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    const SizedBox(height: 2),
                    Text(
                      value ?? placeholder,
                      style: value != null
                          ? kStyleBodyMedium
                          : kStyleBody.copyWith(color: kColorInkSoft),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: kColorInkSoft),
                )
              else
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: kColorInkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
