import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

/// The one confirmation dialog. Small centred modal, grey Cancel + coloured
/// action. Returns true only when the user taps the action.
///
/// For deletes prefer [showWabwayDeleteConfirm], which applies the standard
/// copy template.
Future<bool> showWabwayConfirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
      title: Text(title, style: kStyleBodySemibold),
      content: Text(message, style: kStyleBody),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancelLabel, style: kStyleBody.copyWith(color: kColorInkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirmLabel,
            style: kStyleBodyMedium.copyWith(
                color: destructive ? kColorDanger : kColorPrimaryDark),
          ),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Standard delete confirmation:
/// "Delete {entity}?" / "This will permanently remove "{name}". This cannot be undone."
///
/// Pass [detail] to append extra context (e.g. "…for every member").
Future<bool> showWabwayDeleteConfirm(
  BuildContext context, {
  required String entity,
  String? name,
  String? detail,
}) {
  final what = (name == null || name.trim().isEmpty) ? 'this $entity' : '"$name"';
  final extra = detail == null ? '' : ' $detail';
  return showWabwayConfirm(
    context,
    title: 'Delete $entity?',
    message: 'This will permanently remove $what$extra. This cannot be undone.',
  );
}

/// Single-field prompt (rename, quick name). Returns the trimmed text, or null
/// if cancelled or left empty.
Future<String?> showWabwayTextPrompt(
  BuildContext context, {
  required String title,
  String? initialValue,
  String? hint,
  String? message,
  String? helper,
  int maxLines = 1,
  int? maxLength,
  String confirmLabel = 'Save',
}) async {
  final ctrl = TextEditingController(text: initialValue);
  try {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text(title, style: kStyleBodySemibold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (message != null) ...[
              Text(message, style: kStyleCaption),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: ctrl,
              autofocus: true,
              style: kStyleBody,
              maxLines: maxLines,
              maxLength: maxLength,
              textInputAction: maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
              onSubmitted: maxLines == 1 ? (_) => Navigator.pop(ctx, true) : null,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
                helperText: helper,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: kStyleBody.copyWith(color: kColorInkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: kStyleBodyMedium.copyWith(color: kColorPrimaryDark)),
          ),
        ],
      ),
    );
    final text = ctrl.text.trim();
    return ok == true && text.isNotEmpty ? text : null;
  } finally {
    ctrl.dispose();
  }
}
