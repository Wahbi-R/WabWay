import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

/// The one toast. Use for create/update/delete/vote feedback and errors.
/// Styling comes from `snackBarTheme` in wabway_theme.dart.
void showWabwaySnack(
  BuildContext context,
  String message, {
  bool error = false,
  Duration duration = const Duration(seconds: 2),
  SnackBarAction? action,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message, style: kStyleBody.copyWith(color: Colors.white)),
      backgroundColor: error ? kColorDanger : null,
      behavior: SnackBarBehavior.floating,
      duration: duration,
      action: action,
    ));
}
