import 'package:flutter/material.dart';
import '../../data/share_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';

class DestinationSelector extends StatelessWidget {
  const DestinationSelector({
    super.key,
    required this.contentType,
    required this.selected,
    required this.onSelect,
  });

  final ShareContentType contentType;
  final ShareDestination? selected;
  final ValueChanged<ShareDestination> onSelect;

  @override
  Widget build(BuildContext context) {
    final suggested = contentType.suggestedDestinations;
    final others = ShareDestination.values
        .where((d) => !suggested.contains(d))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Save as',
          style: kStyleCaptionMedium.copyWith(color: kColorInk),
        ),
        const SizedBox(height: kSpace2),
        ...suggested.map(
          (dest) => Padding(
            padding: const EdgeInsets.only(bottom: kSpace2),
            child: _DestinationCard(
              destination: dest,
              isSelected: selected == dest,
              isSuggested: true,
              onTap: () => onSelect(dest),
            ),
          ),
        ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: kSpace2),
          Text(
            'Other options',
            style: kStyleOverline.copyWith(color: kColorInkSoft),
          ),
          const SizedBox(height: kSpace2),
          Wrap(
            spacing: kSpace2,
            runSpacing: kSpace2,
            children: others
                .map(
                  (dest) => _DestinationChip(
                    destination: dest,
                    isSelected: selected == dest,
                    onTap: () => onSelect(dest),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

// ─── Suggested destination card ───────────────────────────────────────────────

class _DestinationCard extends StatefulWidget {
  const _DestinationCard({
    required this.destination,
    required this.isSelected,
    required this.isSuggested,
    required this.onTap,
  });

  final ShareDestination destination;
  final bool isSelected;
  final bool isSuggested;
  final VoidCallback onTap;

  @override
  State<_DestinationCard> createState() => _DestinationCardState();
}

class _DestinationCardState extends State<_DestinationCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    final isActive = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kDurationFast,
          curve: kEaseStandard,
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            color: isActive
                ? dest.softColor
                : _hovered
                    ? kColorSurfaceSunken
                    : kColorPaper,
            borderRadius: kRadiusMd,
            border: Border.all(
              color: isActive
                  ? dest.color
                  : _hovered
                      ? kColorBorderStrong
                      : kColorBorder,
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive ? kShadowSm : null,
          ),
          child: Row(
            children: [
              _DestinationIcon(
                dest: dest,
                isActive: isActive,
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(dest.label, style: kStyleBodySemibold),
                        if (widget.isSuggested) ...[
                          const SizedBox(width: kSpace2),
                          _SuggestedBadge(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(dest.description, style: kStyleCaption),
                  ],
                ),
              ),
              const SizedBox(width: kSpace2),
              Icon(
                isActive
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 20,
                color: isActive ? dest.color : kColorBorder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({
    required this.dest,
    required this.isActive,
  });

  final ShareDestination dest;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isActive ? dest.color : dest.softColor,
        borderRadius: kRadiusSm,
      ),
      child: Icon(
        dest.icon,
        size: 18,
        color: isActive ? Colors.white : dest.color,
      ),
    );
  }
}

class _SuggestedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: kColorAccentSoft,
        borderRadius: kRadiusPill,
        border: Border.all(color: kColorAccentSoftBorder),
      ),
      child: Text(
        'Suggested',
        style: kStyleOverline.copyWith(color: kColorAccent),
      ),
    );
  }
}

// ─── Other destination chip ───────────────────────────────────────────────────

class _DestinationChip extends StatefulWidget {
  const _DestinationChip({
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final ShareDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_DestinationChip> createState() => _DestinationChipState();
}

class _DestinationChipState extends State<_DestinationChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    final isActive = widget.isSelected;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kDurationFast,
          curve: kEaseStandard,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? dest.softColor
                : _hovered
                    ? kColorSurfaceSunken
                    : kColorPaper,
            borderRadius: kRadiusPill,
            border: Border.all(
              color: isActive ? dest.color : kColorBorder,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                dest.icon,
                size: 14,
                color: isActive ? dest.color : kColorInkSoft,
              ),
              const SizedBox(width: 5),
              Text(
                dest.label,
                style: kStyleCaption.copyWith(
                  color: isActive ? dest.color : kColorInk,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
