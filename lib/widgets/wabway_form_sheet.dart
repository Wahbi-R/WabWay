import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';

/// Builds the form body. [scrollController] is non-null on mobile (wire it to
/// the form's scroll view so the sheet drags). [showDragHandle] is true only on
/// mobile. Call [close] with the result to dismiss.
typedef WabwayFormSheetBuilder<T> = Widget Function(
  BuildContext context,
  ScrollController? scrollController,
  bool showDragHandle,
  void Function([T? result]) close,
);

/// The one way to present a create/edit form.
///
/// Adaptive: a centred dialog on desktop (no drag handle), a draggable bottom
/// sheet with a drag handle on mobile. Every `showAdd*Sheet` goes through this.
Future<T?> showWabwayFormSheet<T>(
  BuildContext context, {
  required WabwayFormSheetBuilder<T> builder,
  double desktopWidth = 520,
  double desktopHeightFactor = 0.85,
  double initialChildSize = 0.88,
  double minChildSize = 0.5,
  double maxChildSize = 0.96,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<T>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding: const EdgeInsets.symmetric(horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: desktopWidth,
          height: MediaQuery.sizeOf(dialogCtx).height * desktopHeightFactor,
          child: builder(dialogCtx, null, false, ([r]) => Navigator.pop(dialogCtx, r)),
        ),
      ),
    );
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetCtx) => DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      builder: (_, scrollCtrl) => DecoratedBox(
        decoration: const BoxDecoration(color: kColorPaper, borderRadius: kRadiusSheet),
        child: builder(sheetCtx, scrollCtrl, true, ([r]) => Navigator.pop(sheetCtx, r)),
      ),
    ),
  );
}

/// Content-sized variant of [showWabwayFormSheet] for short sheets that size
/// to their content (settings, single-section forms). Same adaptive rule:
/// centred dialog on desktop, bottom sheet with drag handle on mobile.
Future<T?> showWabwayAutoSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, bool showDragHandle) builder,
  double desktopWidth = 520,
}) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
  if (isDesktop) {
    return showDialog<T>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: kSpace8, vertical: kSpace8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: desktopWidth,
            maxHeight: MediaQuery.sizeOf(dialogCtx).height * 0.85,
          ),
          child: builder(dialogCtx, false),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    // Always give the sheet its paper panel — content shouldn't have to
    // remember to draw one (the quick-add menu didn't, and rendered see-through).
    builder: (sheetCtx) => DecoratedBox(
      decoration: const BoxDecoration(color: kColorPaper, borderRadius: kRadiusSheet),
      child: builder(sheetCtx, true),
    ),
  );
}
