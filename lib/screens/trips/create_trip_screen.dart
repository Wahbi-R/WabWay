import 'package:flutter/material.dart';
import '../../core/supabase/trip_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/wabway_button.dart';
import '../../widgets/wabway_text_field.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key, required this.onCreated});

  /// Called with the new trip ID after the RPC succeeds.
  final Future<void> Function(String tripId) onCreated;

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _nameCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'JPY');

  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _currencyCtrl.addListener(_autoUppercaseCurrency);
  }

  void _autoUppercaseCurrency() {
    final text = _currencyCtrl.text;
    final upper = text.toUpperCase();
    if (text != upper) {
      _currencyCtrl.value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _destinationCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart
        ? (_startDate ?? DateTime.now())
        : (_endDate ?? _startDate ?? DateTime.now());
    final first = isStart ? DateTime(2000) : (_startDate ?? DateTime(2000));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Trip name is required.');
      return;
    }
    final currency = _currencyCtrl.text.trim().toUpperCase();
    if (currency.length != 3 || !RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      setState(() => _error = 'Currency must be 3 letters (e.g. JPY, USD).');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final tripId = await TripService.createTrip(
        name: name,
        destination: _destinationCtrl.text.trim().isEmpty
            ? null
            : _destinationCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        defaultCurrency: currency,
      );
      await widget.onCreated(tripId);
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kSpace6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Logo(),
                  const SizedBox(height: kSpace6),
                  DecoratedBox(
                    decoration: kCardDecoration(),
                    child: Padding(
                      padding: const EdgeInsets.all(kSpace6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Create your trip', style: kStyleTitle),
                          const SizedBox(height: 4),
                          Text(
                            'You can always edit these details later.',
                            style: kStyleCaption,
                          ),
                          const SizedBox(height: kSpace5),
                          WabwayTextField(
                            label: 'Trip name',
                            hint: 'e.g. Japan 2025',
                            controller: _nameCtrl,
                            autofocus: true,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: kSpace4),
                          WabwayTextField(
                            label: 'Destination (optional)',
                            hint: 'e.g. Tokyo, Japan',
                            controller: _destinationCtrl,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: kSpace4),
                          Row(
                            children: [
                              Expanded(
                                child: _DateTile(
                                  label: 'Start date',
                                  date: _startDate,
                                  onTap: () => _pickDate(isStart: true),
                                ),
                              ),
                              const SizedBox(width: kSpace3),
                              Expanded(
                                child: _DateTile(
                                  label: 'End date',
                                  date: _endDate,
                                  onTap: () => _pickDate(isStart: false),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: kSpace4),
                          WabwayTextField(
                            label: 'Default currency',
                            hint: 'JPY',
                            controller: _currencyCtrl,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: kSpace3),
                            Text(
                              _error!,
                              style: kStyleCaption.copyWith(color: kColorDanger),
                            ),
                          ],
                          const SizedBox(height: kSpace5),
                          WabwayButton(
                            label: 'Create trip',
                            onPressed: _loading ? null : _submit,
                            loading: _loading,
                            fullWidth: true,
                            size: WabwayButtonSize.lg,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logo wordmark ────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: kColorPrimary,
            borderRadius: kRadiusMd,
          ),
          child: Center(
            child: Text(
              'W',
              style: kStyleTitle.copyWith(
                color: kColorTextOnPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: kSpace3),
        Text('Wabway', style: kStyleHeadingMd),
      ],
    );
  }
}

// ─── Date tile ────────────────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get _formatted => date == null
      ? 'Optional'
      : '${_months[date!.month - 1]} ${date!.day}, ${date!.year}';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kColorPaper,
          border: Border.all(color: kColorBorder),
          borderRadius: kRadiusMd,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace3,
            vertical: kSpace3,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: kStyleCaption),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_rounded,
                    size: 13,
                    color: date == null ? kColorInkSoft : kColorPrimary,
                  ),
                  const SizedBox(width: kSpace2),
                  Flexible(
                    child: Text(
                      _formatted,
                      style: kStyleBody.copyWith(
                        color: date == null ? kColorInkSoft : kColorInk,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
