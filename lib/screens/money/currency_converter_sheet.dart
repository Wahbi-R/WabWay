import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';

// Shows a quick currency converter bottom sheet.
// Rates are derived from the stored exchange_rate values on existing receipts,
// so no network call is needed during travel.
Future<void> showCurrencyConverterSheet(
  BuildContext context, {
  required String homeCurrency,
  required List<Receipt> receipts,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: kColorPaper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _CurrencyConverterSheet(
      homeCurrency: homeCurrency,
      receipts: receipts,
    ),
  );
}

class _CurrencyConverterSheet extends StatefulWidget {
  const _CurrencyConverterSheet({
    required this.homeCurrency,
    required this.receipts,
  });

  final String homeCurrency;
  final List<Receipt> receipts;

  @override
  State<_CurrencyConverterSheet> createState() => _CurrencyConverterSheetState();
}

class _CurrencyConverterSheetState extends State<_CurrencyConverterSheet> {
  final _ctrl = TextEditingController();
  late String _fromCurrency;
  late Map<String, double> _rates; // currency → 1 unit in homeCurrency

  @override
  void initState() {
    super.initState();
    _rates = _buildRates();
    // Default to the first foreign currency seen, or home currency
    final foreign = _rates.keys
        .where((c) => c != widget.homeCurrency)
        .toList();
    _fromCurrency = foreign.isNotEmpty ? foreign.first : widget.homeCurrency;
  }

  // Build a rate map from existing receipts.
  // Keeps the most recently seen exchange_rate per currency.
  Map<String, double> _buildRates() {
    final rates = <String, double>{widget.homeCurrency: 1.0};
    for (final r in widget.receipts) {
      if (r.currency != widget.homeCurrency && r.exchangeRate > 0) {
        rates[r.currency] = r.exchangeRate;
      }
    }
    return rates;
  }

  double? get _convertedAmount {
    final input = double.tryParse(_ctrl.text.replaceAll(',', '.'));
    if (input == null) return null;
    if (_fromCurrency == widget.homeCurrency) return input;
    final rate = _rates[_fromCurrency];
    if (rate == null) return null;
    return input * rate;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currencies = _rates.keys.toList()..sort();
    final converted = _convertedAmount;
    final isHome = _fromCurrency == widget.homeCurrency;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: kColorBorder, borderRadius: kRadiusPill),
            ),
          ),
          const SizedBox(height: 16),
          Text('Currency converter', style: kStyleTitle),
          const SizedBox(height: 4),
          Text(
            _rates.length <= 1
                ? 'Log a receipt in a foreign currency to unlock conversions'
                : 'Rates from your logged receipts — works offline',
            style: kStyleCaption,
          ),
          const SizedBox(height: 20),

          // Amount input row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Currency picker
              Container(
                decoration: BoxDecoration(
                  color: kColorCream,
                  borderRadius: kRadiusMd,
                  border: Border.all(color: kColorBorder),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _fromCurrency,
                    items: currencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: kStyleBodyMedium)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _fromCurrency = v);
                    },
                    style: kStyleBodyMedium,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Amount field
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: kColorInk),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: TextStyle(fontSize: 24, color: kColorInkSoft.withAlpha(100)),
                    border: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorPrimary, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: kColorCream,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Result
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kColorCream,
              borderRadius: kRadiusMd,
              border: Border.all(color: kColorBorder),
            ),
            child: isHome
                ? Text(
                    'Select a foreign currency above',
                    style: kStyleCaption.copyWith(color: kColorInkSoft),
                  )
                : converted == null
                    ? Text(
                        'Enter an amount',
                        style: kStyleCaption.copyWith(color: kColorInkSoft),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('≈', style: kStyleCaption.copyWith(color: kColorInkSoft)),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.homeCurrency} ${converted.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: kColorInk,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Rate: 1 $_fromCurrency = ${_rates[_fromCurrency]!.toStringAsFixed(4)} ${widget.homeCurrency}',
                            style: kStyleCaption.copyWith(color: kColorInkSoft),
                          ),
                        ],
                      ),
          ),

          if (_rates.length <= 1) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kColorWarning.withAlpha(20),
                borderRadius: kRadiusMd,
                border: Border.all(color: kColorWarning.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: kColorWarning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Rates appear here automatically once you log a receipt in a foreign currency.',
                      style: kStyleCaption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
