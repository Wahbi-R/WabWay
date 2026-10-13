import 'package:flutter/material.dart';
import '../data/docs_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import 'wabway_button.dart';
import 'wabway_detail_widgets.dart';
import 'wabway_form_sheet.dart';

/// "Choose from Library" — pick trip documents to attach. Returns the full
/// selected set (pre-checked with [initialSelectedIds]), or null if dismissed.
/// Adaptive: dialog on desktop, draggable sheet on mobile.
Future<List<String>?> showDocAttachSheet(
  BuildContext context, {
  required List<TripDocument> docs,
  required Set<String> initialSelectedIds,
}) {
  return showWabwayFormSheet<List<String>>(
    context,
    initialChildSize: 0.6,
    minChildSize: 0.35,
    maxChildSize: 0.9,
    builder: (ctx, scroll, handle, close) => _DocAttachContent(
      docs: docs,
      initialSelectedIds: initialSelectedIds,
      scrollController: scroll,
      showDragHandle: handle,
      onSave: close,
    ),
  );
}

class _DocAttachContent extends StatefulWidget {
  const _DocAttachContent({
    required this.docs,
    required this.initialSelectedIds,
    required this.onSave,
    this.scrollController,
    this.showDragHandle = false,
  });
  final List<TripDocument> docs;
  final Set<String> initialSelectedIds;
  final void Function([List<String>?]) onSave;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_DocAttachContent> createState() => _DocAttachContentState();
}

class _DocAttachContentState extends State<_DocAttachContent> {
  late final Set<String> _selected = Set.from(widget.initialSelectedIds);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, kSpace2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.showDragHandle) const WabwayDragHandle(),
              const SizedBox(height: kSpace2),
              Text('Choose from Library', style: kStyleTitle),
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
            controller: widget.scrollController,
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
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, kSpace4),
            child: WabwayButton(
              label: 'Save',
              fullWidth: true,
              onPressed: () => widget.onSave(_selected.toList()),
            ),
          ),
        ),
      ],
    );
  }
}
