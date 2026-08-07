import 'package:flutter/material.dart';
import '../../data/docs_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

/// Shows a doc-picker sheet and returns the selected doc IDs, or null if
/// the user dismissed without saving.
Future<List<String>?> showDocAttachSheet(
  BuildContext context, {
  required List<TripDocument> docs,
  required Set<String> initialSelectedIds,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DocAttachSheet(
      docs: docs,
      initialSelectedIds: initialSelectedIds,
    ),
  );
}

class _DocAttachSheet extends StatefulWidget {
  const _DocAttachSheet({
    required this.docs,
    required this.initialSelectedIds,
  });
  final List<TripDocument> docs;
  final Set<String> initialSelectedIds;

  @override
  State<_DocAttachSheet> createState() => _DocAttachSheetState();
}

class _DocAttachSheetState extends State<_DocAttachSheet> {
  late final Set<String> _selected = Set.from(widget.initialSelectedIds);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, kSpace2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WabwayDragHandle(),
                  const SizedBox(height: kSpace2),
                  Text('Link documents', style: kStyleBodySemibold),
                  const SizedBox(height: kSpace1),
                  Text(
                    'Select documents to attach to this item.',
                    style: kStyleCaption.copyWith(color: kColorInkSoft),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpace4, vertical: kSpace2),
                children: widget.docs.map((d) {
                  final checked = _selected.contains(d.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (v) => setState(() => (v ?? false)
                        ? _selected.add(d.id)
                        : _selected.remove(d.id)),
                    title: Text(d.title, style: kStyleBody),
                    subtitle: Text(d.type.label, style: kStyleCaption),
                    secondary: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: d.type.softColor,
                        borderRadius: kRadiusMd,
                      ),
                      child: Icon(d.type.icon, size: 16, color: d.type.color),
                    ),
                    activeColor: kColorPrimary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }).toList(),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    kSpace4, kSpace2, kSpace4, kSpace4),
                child: WabwayButton(
                  label: 'Save',
                  onPressed: () => Navigator.pop(context, _selected.toList()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
