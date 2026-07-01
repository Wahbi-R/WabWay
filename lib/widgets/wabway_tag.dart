import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

class WabwayTag extends StatefulWidget {
  const WabwayTag({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.onRemove,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  State<WabwayTag> createState() => _WabwayTagState();
}

class _WabwayTagState extends State<WabwayTag> {
  bool _hovered = false;

  Color get _bg {
    if (widget.selected) return kColorPrimary;
    return _hovered ? kColorSurfaceSunken : kColorPaper;
  }

  Color get _fg => widget.selected ? kColorTextOnPrimary : kColorInk;

  Color get _border => widget.selected ? Colors.transparent : kColorBorder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: widget.selected,
      button: widget.onTap != null,
      child: MouseRegion(
        cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: widget.onTap != null ? (_) => setState(() => _hovered = true) : null,
        onExit: widget.onTap != null ? (_) => setState(() => _hovered = false) : null,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: kDurationFast,
            curve: kEaseStandard,
            height: 30,
            padding: EdgeInsets.only(
              left: 12,
              right: widget.onRemove != null ? 6 : 12,
            ),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: kRadiusPill,
              border: Border.all(color: _border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.label, style: kStyleCaptionMedium.copyWith(color: _fg)),
                if (widget.onRemove != null) ...[
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: widget.onRemove,
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: _fg.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
