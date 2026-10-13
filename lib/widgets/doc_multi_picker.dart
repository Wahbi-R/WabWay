import 'package:flutter/material.dart';
import '../data/docs_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

/// Collapsible checklist for attaching trip documents to an item
/// (plan items, travel items). The ONE doc multi-picker.
class DocMultiPicker extends StatefulWidget {
  const DocMultiPicker({
    super.key,
    required this.docs,
    required this.selectedIds,
    required this.onChanged,
  });
  final List<TripDocument> docs;
  final Set<String> selectedIds;
  final void Function(String id, bool checked) onChanged;

  @override
  State<DocMultiPicker> createState() => _DocMultiPickerState();
}

class _DocMultiPickerState extends State<DocMultiPicker> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.selectedIds.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.docs.isEmpty) return const SizedBox.shrink();
    final selectedCount = widget.selectedIds.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              Text('Attach documents (optional)',
                  style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              if (selectedCount > 0) ...[
                const SizedBox(width: kSpace2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kColorPrimary,
                    borderRadius: kRadiusPill,
                  ),
                  child: Text(
                    '$selectedCount',
                    style: kStyleCaption.copyWith(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Icon(
                _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                size: 18,
                color: kColorInkSoft,
              ),
            ],
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: _expanded
              ? Column(
                  children: [
                    const SizedBox(height: kSpace2),
                    ...widget.docs.map((d) {
                      final checked = widget.selectedIds.contains(d.id);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (v) => widget.onChanged(d.id, v ?? false),
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
                    }),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
