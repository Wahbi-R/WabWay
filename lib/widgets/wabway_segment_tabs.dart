import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

/// Underline view-switcher with the same look as the themed `TabBar` (Crew,
/// spot detail) but driven by plain state — for headers where a TabController
/// doesn't fit (Money desktop bar, Map/List). Use `TabBar` when you already
/// have a TabController; never pill chips or SegmentedButton for view tabs.
class WabwaySegmentTabs<T> extends StatelessWidget {
  const WabwaySegmentTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onChanged,
  });

  final List<(T value, String label, IconData? icon)> tabs;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (value, label, icon) in tabs)
          _Tab(
            label: label,
            icon: icon,
            selected: value == selected,
            onTap: () => onChanged(value),
          ),
      ],
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? kColorPrimary : kColorInkSoft;
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: kRadiusSm,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: selected ? kColorPrimary : Colors.transparent, width: 2),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: (selected ? kStyleBodySemibold : kStyleBodyMedium).copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
