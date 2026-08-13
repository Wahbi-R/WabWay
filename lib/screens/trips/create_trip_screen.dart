import 'package:flutter/material.dart';
import '../../core/supabase/trip_service.dart';
import '../../data/currencies.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/wabway_button.dart';
import '../../widgets/wabway_text_field.dart';
import '../../widgets/destination_autocomplete.dart';

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key, required this.onCreated});

  final Future<void> Function(String tripId) onCreated;

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _nameCtrl = TextEditingController();
  final _destinationCtrl = TextEditingController();

  String _spendingCurrency = 'JPY';
  String _homeCurrency = 'CAD';

  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _destinationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _startDate ?? now,
        end: _endDate ??
            (_startDate?.add(const Duration(days: 7)) ??
                now.add(const Duration(days: 7))),
      ),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kColorPrimary),
        ),
        child: child!,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = picked.start;
      _endDate = picked.end;
    });
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Trip name is required.');
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
        defaultCurrency: _spendingCurrency,
        homeCurrency: _homeCurrency,
      );
      await widget.onCreated(tripId);
      if (mounted) Navigator.pop(context);
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
                          DestinationAutocomplete(
                            controller: _destinationCtrl,
                            label: 'Destination (optional)',
                            hint: 'e.g. Tokyo, Japan',
                          ),
                          const SizedBox(height: kSpace4),
                          Row(
                            children: [
                              Expanded(
                                child: _DateTile(
                                  label: 'Start date',
                                  date: _startDate,
                                  onTap: _pickDateRange,
                                ),
                              ),
                              const SizedBox(width: kSpace3),
                              Expanded(
                                child: _DateTile(
                                  label: 'End date',
                                  date: _endDate,
                                  onTap: _pickDateRange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: kSpace4),
                          _CurrencyField(
                            label: 'Spending currency',
                            description: 'The currency you\'ll use at your destination — receipts will be pre-filled with this.',
                            value: _spendingCurrency,
                            onChanged: (v) => setState(() => _spendingCurrency = v),
                          ),
                          const SizedBox(height: kSpace4),
                          _CurrencyField(
                            label: 'Settlement currency',
                            description: 'The currency everyone pays each other back in (usually your home currency).',
                            value: _homeCurrency,
                            onChanged: (v) => setState(() => _homeCurrency = v),
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

// ─── Currency field ───────────────────────────────────────────────────────────

class _CurrencyField extends StatefulWidget {
  const _CurrencyField({
    required this.label,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String description;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_CurrencyField> createState() => _CurrencyFieldState();
}

class _CurrencyFieldState extends State<_CurrencyField> {
  static const _kOther = '__other__';
  late bool _isCustom;
  late final TextEditingController _customCtrl;

  @override
  void initState() {
    super.initState();
    _isCustom = !kCurrencies.any((c) => c.$1 == widget.value);
    _customCtrl = TextEditingController(text: _isCustom ? widget.value : '');
  }

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _onDropdownChanged(String? v) {
    if (v == _kOther) {
      setState(() { _isCustom = true; _customCtrl.clear(); });
    } else if (v != null) {
      setState(() => _isCustom = false);
      widget.onChanged(v);
    }
  }

  void _onCustomChanged(String raw) {
    final upper = raw.toUpperCase();
    if (upper != raw) {
      _customCtrl.value = TextEditingValue(
        text: upper,
        selection: TextSelection.collapsed(offset: upper.length),
      );
    }
    if (upper.length == 3 && RegExp(r'^[A-Z]{3}$').hasMatch(upper)) {
      widget.onChanged(upper);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: 2),
        Text(widget.description, style: kStyleCaption.copyWith(color: kColorInkSoft)),
        const SizedBox(height: kSpace2),
        DecoratedBox(
          decoration: BoxDecoration(
            color: kColorCream,
            borderRadius: kRadiusMd,
            border: Border.all(color: kColorBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _isCustom ? _kOther : widget.value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 2),
              borderRadius: kRadiusMd,
              items: [
                ...kCurrencies.map((c) {
                  final (code, lbl) = c;
                  return DropdownMenuItem(
                    value: code,
                    child: Text(lbl, style: kStyleBodyMedium),
                  );
                }),
                DropdownMenuItem(
                  value: _kOther,
                  child: Text(
                    'Other (enter 3-letter code)',
                    style: kStyleBodyMedium.copyWith(color: kColorInkSoft),
                  ),
                ),
              ],
              onChanged: _onDropdownChanged,
            ),
          ),
        ),
        if (_isCustom) ...[
          const SizedBox(height: kSpace2),
          TextField(
            controller: _customCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 3,
            style: kStyleBodyMedium,
            onChanged: _onCustomChanged,
            decoration: InputDecoration(
              hintText: 'e.g. CHF',
              hintStyle: TextStyle(color: kColorInkSoft.withAlpha(120)),
              counterText: '',
              filled: true,
              fillColor: kColorCream,
              border: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorPrimary, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              isDense: true,
            ),
          ),
        ],
      ],
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
