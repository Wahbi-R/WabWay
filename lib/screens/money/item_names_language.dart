import 'package:flutter/material.dart';
import '../../core/receipt_scan_service.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

/// Rebuilds with whether item names show in English (per device).
class ItemNamesLanguage extends StatefulWidget {
  const ItemNamesLanguage({super.key, required this.builder});
  final Widget Function(BuildContext context, bool english) builder;

  @override
  State<ItemNamesLanguage> createState() => _ItemNamesLanguageState();
}

class _ItemNamesLanguageState extends State<ItemNamesLanguage> {
  @override
  void initState() {
    super.initState();
    ReceiptScanService.loadEnglishPref();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: ReceiptScanService.showEnglish,
        builder: (context, english, _) => widget.builder(context, english),
      );
}

/// An item's name in the chosen language, with the printed name underneath
/// when showing a translation (so it still matches the paper).
class ItemNameText extends StatelessWidget {
  const ItemNameText({super.key, required this.item, required this.english, this.prefix = '', this.style});
  final ReceiptItem item;
  final bool english;
  final String prefix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final translated = english && item.nameEn != null && item.nameEn!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$prefix${item.displayName(english: english)}', style: style ?? kStyleBodyMedium),
        if (translated)
          Text(item.name, style: kStyleCaption.copyWith(color: kColorInkSoft)),
      ],
    );
  }
}

/// "Show original / Show English", plus "Translate" when some names aren't
/// in English yet and [onTranslated] is given (it receives the items with
/// translations added — save them).
class ItemNamesLanguageBar extends StatefulWidget {
  const ItemNamesLanguageBar({
    super.key,
    required this.items,
    required this.english,
    this.onTranslated,
  });
  final ReceiptItemization items;
  final bool english;
  final ValueChanged<ReceiptItemization>? onTranslated;

  @override
  State<ItemNamesLanguageBar> createState() => _ItemNamesLanguageBarState();
}

class _ItemNamesLanguageBarState extends State<ItemNamesLanguageBar> {
  bool _busy = false;

  Future<void> _translate() async {
    setState(() => _busy = true);
    final (result, error) = await ReceiptScanService.translate(widget.items);
    if (!mounted) return;
    setState(() => _busy = false);
    if (result == null) {
      showWabwaySnack(context, error ?? "Couldn't translate.", error: true);
      return;
    }
    ReceiptScanService.setShowEnglish(true);
    widget.onTranslated!(result);
  }

  @override
  Widget build(BuildContext context) {
    final canTranslate = widget.onTranslated != null && widget.items.needsTranslation;
    final hasTranslations = widget.items.hasTranslations;
    if (!canTranslate && !hasTranslations) return const SizedBox.shrink();
    return Wrap(
      spacing: kSpace2,
      runSpacing: kSpace1,
      children: [
        if (hasTranslations)
          WabwayButton(
            label: widget.english ? 'Show original' : 'Show English',
            icon: Icons.translate_rounded,
            size: WabwayButtonSize.sm,
            variant: WabwayButtonVariant.ghost,
            onPressed: () => ReceiptScanService.setShowEnglish(!widget.english),
          ),
        if (canTranslate)
          WabwayButton(
            label: _busy ? 'Translating…' : 'Translate to English',
            icon: Icons.g_translate_rounded,
            size: WabwayButtonSize.sm,
            variant: WabwayButtonVariant.ghost,
            onPressed: _busy ? null : _translate,
          ),
      ],
    );
  }
}
