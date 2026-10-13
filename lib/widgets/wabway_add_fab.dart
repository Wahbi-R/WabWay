import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import 'wabway_button.dart';

/// The one primary "add" FAB for list screens on mobile: orange, extended,
/// always labelled ("Add a spot", "Add receipt"…). Desktop layouts put the
/// same action in the header as `WabwayButton(variant: primary)` instead.
class WabwayAddFab extends StatelessWidget {
  const WabwayAddFab({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
    this.heroTag,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final Object? heroTag;

  @override
  Widget build(BuildContext context) => FloatingActionButton.extended(
        heroTag: heroTag ?? label,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary)),
      );
}

/// Desktop counterpart of [WabwayAddFab]: the primary labelled button in the
/// screen header. Renders nothing on mobile, where the FAB carries the action —
/// so a screen can use both unconditionally.
class WabwayHeaderAddButton extends StatelessWidget {
  const WabwayHeaderAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.add_rounded,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    if (!isDesktopLayout(context)) return const SizedBox.shrink();
    return WabwayButton(label: label, icon: icon, size: WabwayButtonSize.sm, onPressed: onPressed);
  }
}

/// True at desktop widths — the one breakpoint check for adaptive chrome.
bool isDesktopLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
