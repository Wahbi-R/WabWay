import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';

class WabwayCard extends StatefulWidget {
  const WabwayCard({
    super.key,
    required this.child,
    this.padding,
    this.hoverable = false,
    this.selected = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool hoverable;
  final bool selected;
  final VoidCallback? onTap;

  @override
  State<WabwayCard> createState() => _WabwayCardState();
}

class _WabwayCardState extends State<WabwayCard> {
  bool _hovered = false;

  bool get _elevated => (widget.hoverable && _hovered) || widget.selected;

  @override
  Widget build(BuildContext context) {
    Widget content = widget.padding != null
        ? Padding(padding: widget.padding!, child: widget.child)
        : widget.child;

    if (widget.onTap != null) {
      content = InkWell(
        onTap: widget.onTap,
        borderRadius: kRadiusLg,
        splashColor: kColorPrimarySoft,
        highlightColor: kColorPrimarySoft.withValues(alpha: 0.4),
        child: content,
      );
    }

    return MouseRegion(
      onEnter: widget.hoverable ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.hoverable ? (_) => setState(() => _hovered = false) : null,
      child: AnimatedContainer(
        duration: kDurationBase,
        curve: kEaseStandard,
        decoration: BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusLg,
          border: Border.all(
            color: widget.selected ? kColorPrimary : kColorBorder,
          ),
          boxShadow: _elevated ? kShadowMd : kShadowSm,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: kRadiusLg,
          child: content,
        ),
      ),
    );
  }
}
