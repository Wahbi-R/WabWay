import 'package:flutter/material.dart';
import '../core/text_utils.dart';
import '../theme/app_text_theme.dart';

export '../core/text_utils.dart' show initialsFor;

enum WabwayAvatarSize { xs, sm, md, lg, xl }

const _kAvatarPalette = [
  Color(0xFFC96F4A),
  Color(0xFF7D9A75),
  Color(0xFFD6A84F),
  Color(0xFF9F4F34),
  Color(0xFF6F8FA8),
  Color(0xFFB07AA0),
];

Color avatarColorFor(String name) {
  int h = 0;
  for (final c in name.codeUnits) {
    h = ((h * 31) + c) & 0xFFFFFFFF;
  }
  return _kAvatarPalette[h % _kAvatarPalette.length];
}


class WabwayAvatar extends StatelessWidget {
  const WabwayAvatar({
    super.key,
    required this.name,
    this.src,
    this.size = WabwayAvatarSize.md,
    this.ring = false,
  });

  final String name;
  final ImageProvider? src;
  final WabwayAvatarSize size;
  final bool ring;

  double get _px => switch (size) {
    WabwayAvatarSize.xs => 22,
    WabwayAvatarSize.sm => 28,
    WabwayAvatarSize.md => 36,
    WabwayAvatarSize.lg => 48,
    WabwayAvatarSize.xl => 64,
  };

  @override
  Widget build(BuildContext context) {
    final px = _px;
    final fontSize = px * 0.4;
    final color = src != null ? null : avatarColorFor(name);

    return Container(
      width: px,
      height: px,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        image: src != null
            ? DecorationImage(image: src!, fit: BoxFit.cover)
            : null,
        border: ring
            ? Border.all(color: Colors.white, width: 2)
            : null,
      ),
      child: src == null
          ? Center(
              child: Text(
                initialsFor(name).isEmpty ? '?' : initialsFor(name),
                style: kStyleButtonMd.copyWith(
                  fontSize: fontSize,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            )
          : null,
    );
  }
}
