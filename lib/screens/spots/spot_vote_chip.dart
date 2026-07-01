import 'package:flutter/material.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';

/// A single tappable vote pill matching the design reference (colored dot + label).
class SpotVoteChip extends StatelessWidget {
  const SpotVoteChip({
    super.key,
    required this.type,
    this.selected = false,
    this.count,
    this.compact = false,
    this.onTap,
  });

  final VoteType type;
  final bool selected;
  final int? count;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final chipColor = type.color;
    final bg = selected ? type.softColor : kColorPaper;
    final borderColor = selected ? chipColor : kColorBorder;
    final borderWidth = selected ? 1.5 : 1.0;
    final labelColor = selected ? kColorInk : kColorInkSoft;
    final fontWeight = selected ? FontWeight.w600 : FontWeight.w500;
    final height = compact ? 22.0 : 30.0;
    final padX = compact ? 8.0 : 12.0;
    final dotSize = compact ? 6.0 : 7.0;

    Widget chip = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeInOut,
      height: height,
      padding: EdgeInsets.symmetric(horizontal: padX),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: kRadiusPill,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dotSize,
            height: dotSize,
            decoration: BoxDecoration(color: chipColor, shape: BoxShape.circle),
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            count != null ? '${type.label} ×$count' : type.label,
            style: kStyleOverline.copyWith(
              color: labelColor,
              fontWeight: fontWeight,
            ),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: chip,
      );
    }
    return chip;
  }
}

/// Full four-chip row: Must-do / Want / Maybe / Skip.
/// [selected] is the currently active vote (null = none).
class SpotVoteChipGroup extends StatelessWidget {
  const SpotVoteChipGroup({
    super.key,
    this.selected,
    this.onChanged,
  });

  final VoteType? selected;
  final ValueChanged<VoteType?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: kSpace2,
      runSpacing: kSpace2,
      children: VoteType.values.map((type) {
        final isSelected = selected == type;
        return SpotVoteChip(
          type: type,
          selected: isSelected,
          onTap: onChanged == null
              ? null
              : () => onChanged!(isSelected ? null : type),
        );
      }).toList(),
    );
  }
}

/// Compact vote summary row shown on list tiles (only active vote types with counts).
class SpotVoteSummary extends StatelessWidget {
  const SpotVoteSummary({super.key, required this.votes});
  final SpotVotes votes;

  @override
  Widget build(BuildContext context) {
    final active = votes.activeTypes;
    if (active.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: kSpace2,
      runSpacing: kSpace1,
      children: active
          .map((type) => SpotVoteChip(
                type: type,
                count: votes.count(type),
                compact: true,
              ))
          .toList(),
    );
  }
}
