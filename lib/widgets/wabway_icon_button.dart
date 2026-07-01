import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';

enum WabwayIconButtonVariant { ghost, solid }
enum WabwayIconButtonSize { sm, md, lg }

class WabwayIconButton extends StatefulWidget {
  const WabwayIconButton({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.variant = WabwayIconButtonVariant.ghost,
    this.size = WabwayIconButtonSize.md,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final WabwayIconButtonVariant variant;
  final WabwayIconButtonSize size;
  final bool active;

  @override
  State<WabwayIconButton> createState() => _WabwayIconButtonState();
}

class _WabwayIconButtonState extends State<WabwayIconButton> {
  bool _hovered = false;

  double get _dims => switch (widget.size) {
    WabwayIconButtonSize.sm => 32,
    WabwayIconButtonSize.md => kTapMin,
    WabwayIconButtonSize.lg => kTapComfortable,
  };

  double get _iconSize => _dims * 0.45;

  bool get _isSolid => widget.variant == WabwayIconButtonVariant.solid;
  bool get _disabled => widget.onPressed == null;

  Color get _bgColor {
    if (_isSolid) return _hovered ? kColorPrimaryHover() : kColorPrimary;
    if (widget.active) return kColorPrimarySoft;
    if (_hovered) return kColorSurfaceSunken;
    return Colors.transparent;
  }

  Color get _fgColor {
    if (_isSolid) return kColorTextOnPrimary;
    if (widget.active) return kColorPrimaryDark;
    return kColorInkSoft;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      enabled: !_disabled,
      child: Tooltip(
        message: widget.label,
        child: MouseRegion(
          cursor: _disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: _disabled ? null : widget.onPressed,
            child: AnimatedContainer(
              duration: kDurationFast,
              curve: kEaseStandard,
              width: _dims,
              height: _dims,
              decoration: BoxDecoration(
                color: _bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(widget.icon, size: _iconSize, color: _fgColor),
            ),
          ),
        ),
      ),
    );
  }
}
