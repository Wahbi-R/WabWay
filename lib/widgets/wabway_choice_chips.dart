import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

class WabwayChoice<T> {
  const WabwayChoice(this.value, this.label, {this.icon, this.color});
  final T value;
  final String label;
  final IconData? icon;

  /// Selected fill colour; defaults to the primary orange.
  final Color? color;
}

/// The one single-select picker for short fixed sets (status, category, type —
/// roughly 8 options or fewer). Use [WabwaySelectField] for long/open lists and
/// [WabwayFilterStrip] for list filtering with counts.
class WabwayChoiceChips<T> extends StatelessWidget {
  const WabwayChoiceChips({
    super.key,
    required this.choices,
    required this.selected,
    required this.onChanged,
    this.label,
  });

  final List<WabwayChoice<T>> choices;
  final T? selected;
  final ValueChanged<T> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final chips = Wrap(
      spacing: kSpace2,
      runSpacing: kSpace2,
      children: [
        for (final c in choices) _Chip(choice: c, selected: c.value == selected, onTap: () => onChanged(c.value)),
      ],
    );
    if (label == null) return chips;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label!, style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        chips,
      ],
    );
  }
}

class _Chip<T> extends StatelessWidget {
  const _Chip({required this.choice, required this.selected, required this.onTap});
  final WabwayChoice<T> choice;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fill = choice.color ?? kColorPrimary;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: kDurationFast,
          padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? fill : kColorSurfaceSunken,
            borderRadius: kRadiusPill,
            border: Border.all(color: selected ? fill : kColorBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (choice.icon != null) ...[
                Icon(choice.icon, size: 14, color: selected ? Colors.white : kColorInkSoft),
                const SizedBox(width: 4),
              ],
              Text(
                choice.label,
                style: kStyleCaption.copyWith(
                  color: selected ? Colors.white : kColorInk,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
