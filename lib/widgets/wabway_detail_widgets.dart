import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

// ─── Drag handle for modal bottom sheets ──────────────────────────────────────

class WabwayDragHandle extends StatelessWidget {
  const WabwayDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: kSpace3, bottom: kSpace1),
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: 40,
          height: 4,
          decoration: const BoxDecoration(
            color: kColorBorder,
            borderRadius: kRadiusPill,
          ),
        ),
      ),
    );
  }
}

// ─── Entity type badge (colored pill with icon + label) ───────────────────────

class WabwayEntityBadge extends StatelessWidget {
  const WabwayEntityBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.iconSize = 13,
  });

  final IconData icon;
  final String label;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: kRadiusPill,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: iconSize, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: kStyleCaption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Horizontal meta row: icon · label · value ────────────────────────────────

class WabwayMetaRow extends StatelessWidget {
  const WabwayMetaRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kColorInkSoft),
        const SizedBox(width: kSpace2),
        Text(label, style: kStyleCaption),
        const Spacer(),
        Text(value, style: valueStyle ?? kStyleBodyMedium),
      ],
    );
  }
}

// ─── Notes section (label + sunken text box) ──────────────────────────────────

class WabwayNotesSection extends StatelessWidget {
  const WabwayNotesSection({super.key, required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(kSpace3),
          decoration: const BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
          ),
          child: Text(notes, style: kStyleBody),
        ),
      ],
    );
  }
}

// ─── Sheet action list tile ───────────────────────────────────────────────────

class WabwayActionTile extends StatelessWidget {
  const WabwayActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.color,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? kColorInk;
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label, style: kStyleBodyMedium.copyWith(color: c)),
      subtitle: subtitle != null
          ? Text(subtitle!, style: kStyleCaption.copyWith(color: kColorInkSoft))
          : null,
      onTap: onTap,
    );
  }
}

// ─── Attach document / photo placeholder ─────────────────────────────────────

class WabwayAttachPlaceholder extends StatelessWidget {
  const WabwayAttachPlaceholder({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: kSpace6),
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        children: [
          const Icon(Icons.attach_file_rounded, size: 24, color: kColorInkSoft),
          const SizedBox(height: kSpace2),
          Text(label, style: kStyleCaption),
        ],
      ),
    );
  }
}
