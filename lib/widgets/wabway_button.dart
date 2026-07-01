import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

enum WabwayButtonVariant { primary, secondary, ghost, danger }
enum WabwayButtonSize { sm, md, lg }

class WabwayButton extends StatefulWidget {
  const WabwayButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = WabwayButtonVariant.primary,
    this.size = WabwayButtonSize.md,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final WabwayButtonVariant variant;
  final WabwayButtonSize size;
  final IconData? icon;
  final bool loading;
  final bool fullWidth;

  @override
  State<WabwayButton> createState() => _WabwayButtonState();
}

class _WabwayButtonState extends State<WabwayButton> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _disabled => widget.onPressed == null || widget.loading;

  Color get _bgColor {
    if (_disabled) return kColorBorder;
    switch (widget.variant) {
      case WabwayButtonVariant.primary:
        if (_pressed) return kColorPrimaryActive();
        if (_hovered) return kColorPrimaryHover();
        return kColorPrimary;
      case WabwayButtonVariant.secondary:
        if (_pressed) return kColorSecondaryActive();
        if (_hovered) return kColorSecondaryHover();
        return kColorSecondary;
      case WabwayButtonVariant.ghost:
        if (_pressed) return kColorPrimarySoftBorder;
        if (_hovered) return kColorPrimarySoft;
        return Colors.transparent;
      case WabwayButtonVariant.danger:
        if (_pressed) return kColorDangerActive();
        if (_hovered) return kColorDangerHover();
        return kColorDanger;
    }
  }

  Color get _fgColor {
    if (_disabled) return kColorInkSoft;
    return switch (widget.variant) {
      WabwayButtonVariant.ghost => kColorPrimaryDark,
      _ => kColorTextOnPrimary,
    };
  }

  Border? get _border => switch (widget.variant) {
    WabwayButtonVariant.ghost => Border.all(color: kColorBorder),
    _ => null,
  };

  double get _height => switch (widget.size) {
    WabwayButtonSize.sm => 36,
    WabwayButtonSize.md => kTapMin,
    WabwayButtonSize.lg => kTapComfortable,
  };

  double get _padX => switch (widget.size) {
    WabwayButtonSize.sm => 14,
    WabwayButtonSize.md => 20,
    WabwayButtonSize.lg => 26,
  };

  double get _gap => switch (widget.size) {
    WabwayButtonSize.sm => 6,
    WabwayButtonSize.md => 8,
    WabwayButtonSize.lg => 10,
  };

  BorderRadius get _radius => switch (widget.size) {
    WabwayButtonSize.sm => kRadiusSm,
    _ => kRadiusMd,
  };

  TextStyle get _textStyle => switch (widget.size) {
    WabwayButtonSize.sm => kStyleButtonSm.copyWith(color: _fgColor),
    WabwayButtonSize.md => kStyleButtonMd.copyWith(color: _fgColor),
    WabwayButtonSize.lg => kStyleButtonLg.copyWith(color: _fgColor),
  };

  double get _iconSize => switch (widget.size) {
    WabwayButtonSize.sm => 15,
    WabwayButtonSize.md => 18,
    WabwayButtonSize.lg => 20,
  };

  @override
  Widget build(BuildContext context) {
    final hasShadow = widget.variant != WabwayButtonVariant.ghost && !_disabled;
    return Semantics(
      button: true,
      enabled: !_disabled,
      label: widget.label,
      child: MouseRegion(
        cursor: _disabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTapDown: _disabled ? null : (_) => setState(() => _pressed = true),
          onTapUp: _disabled ? null : (_) {
            setState(() => _pressed = false);
            widget.onPressed?.call();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: kDurationFast,
            curve: kEaseStandard,
            height: _height,
            width: widget.fullWidth ? double.infinity : null,
            padding: EdgeInsets.symmetric(horizontal: _padX),
            decoration: BoxDecoration(
              color: _bgColor,
              borderRadius: _radius,
              border: _border,
              boxShadow: hasShadow ? kShadowXs : null,
            ),
            child: Row(
              mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.loading) ...[
                  SizedBox(
                    width: _iconSize,
                    height: _iconSize,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation(_fgColor),
                    ),
                  ),
                  SizedBox(width: _gap),
                ] else if (widget.icon != null) ...[
                  Icon(widget.icon, size: _iconSize, color: _fgColor),
                  SizedBox(width: _gap),
                ],
                Text(widget.label, style: _textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
