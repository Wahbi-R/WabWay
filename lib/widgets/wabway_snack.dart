import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

/// The one toast. Use for create/update/delete/vote feedback and errors.
/// Styling comes from `snackBarTheme` in wabway_theme.dart.
ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? showWabwaySnack(
  BuildContext context,
  String message, {
  bool error = false,
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
  bool? persist,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return null;
  messenger.hideCurrentSnackBar();
  return messenger.showSnackBar(SnackBar(
      content: Text(message, style: kStyleBody.copyWith(color: Colors.white)),
      backgroundColor: error ? kColorDanger : null,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      action: action,
      // Flutter keeps a toast with an action up until it's dismissed; ours
      // all time out after [duration] unless asked to [persist].
      persist: persist ?? false,
    ));
}

/// Ids hidden by [deleteWithUndo] whose delete hasn't run yet. Screens drop
/// them from fresh loads ([withoutPendingDeletes]) so a reload during the
/// Undo window doesn't bring them back.
final Set<String> _pendingDeletes = {};

List<T> withoutPendingDeletes<T>(List<T> items, String Function(T) idOf) =>
    _pendingDeletes.isEmpty ? items : items.where((x) => !_pendingDeletes.contains(idOf(x))).toList();

/// Delete with an Undo toast, for anything that can be deleted by a swipe.
/// [hide] takes the item off screen now; the real delete ([commit]) only runs
/// once the toast closes without Undo, so Undo just calls [restore] and
/// nothing has to be rebuilt. If [commit] fails the item comes back.
Future<void> deleteWithUndo(
  BuildContext context, {
  required String id,
  required String message,
  required VoidCallback hide,
  required VoidCallback restore,
  required Future<void> Function() commit,
  String? failMessage,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  _pendingDeletes.add(id);
  hide();
  var undone = false;
  final toast = showWabwaySnack(
    context,
    message,
    duration: const Duration(seconds: 5),
    action: SnackBarAction(label: 'Undo', onPressed: () => undone = true),
  );
  final reason = await toast?.closed;
  _pendingDeletes.remove(id);
  if (undone || reason == SnackBarClosedReason.action) {
    restore();
    return;
  }
  try {
    await commit();
  } catch (_) {
    restore();
    messenger?.showSnackBar(SnackBar(
      content: Text(failMessage ?? "Couldn't delete it — it's back.",
          style: kStyleBody.copyWith(color: Colors.white)),
      backgroundColor: kColorDanger,
      behavior: SnackBarBehavior.floating,
    ));
  }
}
