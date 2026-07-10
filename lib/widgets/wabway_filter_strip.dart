import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import 'wabway_tag.dart';

/// A horizontal scrolling row of filter chips used by Stays, Receipts, and Links screens.
///
/// Pass [options] as a pre-built list of (value, label, count). The widget renders
/// an "All (total)" chip first, then one chip per option. Set [autoHide] to hide the
/// strip when fewer than 2 options are present (default true).
class WabwayFilterStrip<T> extends StatelessWidget {
  const WabwayFilterStrip({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.allLabel = 'All',
    this.allCount,
    this.autoHide = true,
  });

  final List<({T value, String label, int count})> options;
  final T? selected;
  final ValueChanged<T?> onChanged;

  /// Label for the "show all" chip. Set null to omit the All chip entirely.
  final String? allLabel;

  /// Count shown in the All chip. If null, omits the count suffix.
  final int? allCount;

  /// When true, hides the strip if there are fewer than 2 options.
  final bool autoHide;

  @override
  Widget build(BuildContext context) {
    if (autoHide && options.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
        children: [
          if (allLabel != null)
            Padding(
              padding: EdgeInsets.only(right: kSpace2),
              child: WabwayTag(
                label: allCount != null ? '$allLabel ($allCount)' : allLabel!,
                selected: selected == null,
                onTap: () => onChanged(null),
              ),
            ),
          for (final opt in options)
            Padding(
              padding: EdgeInsets.only(right: kSpace2),
              child: WabwayTag(
                label: '${opt.label} (${opt.count})',
                selected: selected == opt.value,
                onTap: () => onChanged(selected == opt.value ? null : opt.value),
              ),
            ),
        ],
      ),
    );
  }
}
