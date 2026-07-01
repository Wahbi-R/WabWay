import 'package:flutter/material.dart';
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

Future<TripDocument?> showAddDocSheet(BuildContext context) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<TripDocument>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding: const EdgeInsets.symmetric(horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(ctx).height * 0.90,
          child: _AddDocContent(onSubmit: (d) => Navigator.pop(ctx, d)),
        ),
      ),
    );
  }

  return showModalBottomSheet<TripDocument>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddDocSheet(onSubmit: (d) => Navigator.pop(ctx, d)),
  );
}

class _AddDocSheet extends StatelessWidget {
  const _AddDocSheet({required this.onSubmit});
  final ValueChanged<TripDocument> onSubmit;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: _AddDocContent(
          scrollController: ctrl,
          onSubmit: onSubmit,
          showDragHandle: true,
        ),
      ),
    );
  }
}

class _AddDocContent extends StatefulWidget {
  const _AddDocContent({
    required this.onSubmit,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ValueChanged<TripDocument> onSubmit;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddDocContent> createState() => _AddDocContentState();
}

class _AddDocContentState extends State<_AddDocContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DocType _type = DocType.other;
  DocLinkedType? _linkType;
  String? _linkedId;
  String? _linkedLabel;
  bool _fileSelected = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    widget.onSubmit(TripDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      type: _type,
      ext: 'pdf',
      uploadedBy: 'You',
      uploadedAt: DateTime.now(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      links: (_linkType != null && _linkedId != null && _linkedLabel != null)
          ? [DocumentLink(type: _linkType!, linkedId: _linkedId!, label: _linkedLabel!)]
          : const [],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle)
          Padding(
            padding: const EdgeInsets.only(top: kSpace3, bottom: kSpace1),
            child: Container(
              width: 40,
              height: 4,
              decoration: const BoxDecoration(color: kColorBorder, borderRadius: kRadiusPill),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: Row(
            children: [
              Text('Add document', style: kStyleTitle),
              const Spacer(),
              WabwayIconButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: kSpace5),

        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace6 + bottomPad),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WabwayTextField(
                    label: 'Title',
                    hint: 'e.g. Flight confirmation',
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<DocType>(
                    label: 'Document type',
                    value: _type,
                    onChanged: (v) => setState(() => _type = v ?? DocType.other),
                    items: DocType.values
                        .map((t) => WabwaySelectItem(value: t, label: t.label))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  // File upload zone
                  _FileUploadZone(
                    selected: _fileSelected,
                    onTap: () => setState(() => _fileSelected = !_fileSelected),
                  ),
                  const SizedBox(height: kSpace4),

                  // Link to section
                  _LinkSection(
                    linkType: _linkType,
                    linkedId: _linkedId,
                    linkedLabel: _linkedLabel,
                    onLinkTypeChanged: (t) => setState(() {
                      _linkType = t;
                      if (t == DocLinkedType.trip) {
                        _linkedId = 'trip1';
                        _linkedLabel = 'Japan Nov 2024';
                      } else {
                        _linkedId = null;
                        _linkedLabel = null;
                      }
                    }),
                    onLinkItemChanged: (id, label) => setState(() {
                      _linkedId = id;
                      _linkedLabel = label;
                    }),
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Notes',
                    hint: 'Optional notes…',
                    controller: _notesCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: kSpace6),

                  WabwayButton(
                    label: 'Add document',
                    icon: Icons.insert_drive_file_rounded,
                    fullWidth: true,
                    size: WabwayButtonSize.lg,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── File upload zone ─────────────────────────────────────────────────────────

class _FileUploadZone extends StatelessWidget {
  const _FileUploadZone({required this.selected, required this.onTap});
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('File', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: kSpace6),
            decoration: BoxDecoration(
              color: selected ? kColorPrimarySoft : kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border: Border.all(
                color: selected ? kColorPrimary : kColorBorder,
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  size: 32,
                  color: selected ? kColorPrimary : kColorInkSoft,
                ),
                const SizedBox(height: kSpace2),
                Text(
                  selected ? 'File selected (mock)' : 'Tap to choose a file',
                  style: kStyleBodyMedium.copyWith(
                    color: selected ? kColorPrimary : kColorInkSoft,
                  ),
                ),
                if (!selected)
                  Padding(
                    padding: const EdgeInsets.only(top: kSpace1),
                    child: Text(
                      'PDF, JPG, PNG, DOCX…',
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Link section ─────────────────────────────────────────────────────────────

class _LinkSection extends StatelessWidget {
  const _LinkSection({
    required this.linkType,
    required this.linkedId,
    required this.linkedLabel,
    required this.onLinkTypeChanged,
    required this.onLinkItemChanged,
  });

  final DocLinkedType? linkType;
  final String? linkedId;
  final String? linkedLabel;
  final ValueChanged<DocLinkedType?> onLinkTypeChanged;
  final void Function(String id, String label) onLinkItemChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Link to (optional)', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),

        // Type selector
        WabwaySelectField<DocLinkedType?>(
          label: 'Link type',
          value: linkType,
          onChanged: onLinkTypeChanged,
          items: [
            const WabwaySelectItem(value: null, label: 'None'),
            ...DocLinkedType.values.map(
              (t) => WabwaySelectItem(value: t, label: t.label),
            ),
          ],
        ),

        // Item selector based on type
        if (linkType != null) ...[
          const SizedBox(height: kSpace3),
          _buildItemSelector(context),
        ],
      ],
    );
  }

  Widget _buildItemSelector(BuildContext context) {
    switch (linkType!) {
      case DocLinkedType.spot:
        return WabwaySelectField<String?>(
          label: 'Spot',
          value: linkedId,
          onChanged: (id) {
            if (id == null) return;
            final spot = kMockSpots.where((s) => s.id == id).firstOrNull;
            if (spot != null) onLinkItemChanged(id, spot.name);
          },
          items: kMockSpots
              .map((s) => WabwaySelectItem(value: s.id, label: s.name))
              .toList(),
        );

      case DocLinkedType.receipt:
        return WabwaySelectField<String?>(
          label: 'Receipt',
          value: linkedId,
          onChanged: (id) {
            if (id == null) return;
            final r = kMockReceipts.where((r) => r.id == id).firstOrNull;
            if (r != null) onLinkItemChanged(id, r.title);
          },
          items: kMockReceipts
              .map((r) => WabwaySelectItem(value: r.id, label: r.title))
              .toList(),
        );

      case DocLinkedType.cashWithdrawal:
        return WabwaySelectField<String?>(
          label: 'Withdrawal',
          value: linkedId,
          onChanged: (id) {
            if (id == null) return;
            final w = kMockWithdrawals.where((w) => w.id == id).firstOrNull;
            if (w != null) {
              onLinkItemChanged(id, 'ATM ${fmtAmount(w.amount, w.currency)}');
            }
          },
          items: kMockWithdrawals
              .map((w) => WabwaySelectItem(
                    value: w.id,
                    label: 'ATM ${fmtAmount(w.amount, w.currency)} · ${w.withdrawnById}',
                  ))
              .toList(),
        );

      case DocLinkedType.trip:
        return Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: const BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
          ),
          child: Row(
            children: [
              const Icon(Icons.luggage_rounded, size: 16, color: kColorInkSoft),
              const SizedBox(width: kSpace2),
              Text('Japan Nov 2024', style: kStyleBodyMedium),
            ],
          ),
        );

      default:
        return WabwayTextField(
          label: 'Item name',
          hint: 'Enter a label for this link',
          onChanged: (v) => onLinkItemChanged('custom', v),
        );
    }
  }
}
