import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

enum WabwayBadgeTone {
  neutral,
  primary,
  secondary,
  accent,
  success,
  warning,
  danger,
}

class WabwayBadge extends StatelessWidget {
  const WabwayBadge({
    super.key,
    required this.label,
    this.tone = WabwayBadgeTone.neutral,
    this.icon,
  });

  final String label;
  final WabwayBadgeTone tone;
  final IconData? icon;

  ({Color bg, Color fg, Color border}) get _colors => switch (tone) {
    WabwayBadgeTone.neutral   => (bg: kColorSurfaceSunken, fg: kColorInkSoft,   border: kColorBorder),
    WabwayBadgeTone.primary   => (bg: kColorPrimarySoft,   fg: kColorPrimaryDark, border: kColorPrimarySoftBorder),
    WabwayBadgeTone.secondary => (bg: kColorSecondarySoft, fg: const Color(0xFF4D6648), border: kColorSecondarySoftBorder),
    WabwayBadgeTone.accent    => (bg: kColorAccentSoft,    fg: const Color(0xFF8A6220), border: kColorAccentSoftBorder),
    WabwayBadgeTone.success   => (bg: kColorSuccessSoft,   fg: kColorSuccess,   border: kColorSuccessBorder),
    WabwayBadgeTone.warning   => (bg: kColorWarningSoft,   fg: kColorWarning,   border: kColorWarningBorder),
    WabwayBadgeTone.danger    => (bg: kColorDangerSoft,    fg: kColorDanger,    border: kColorDangerBorder),
  };

  @override
  Widget build(BuildContext context) {
    final c = _colors;
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: kRadiusPill,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: c.fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: kStyleOverline.copyWith(color: c.fg),
          ),
        ],
      ),
    );
  }
}
