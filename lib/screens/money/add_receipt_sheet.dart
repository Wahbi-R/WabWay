import 'package:flutter/material.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

Future<Receipt?> showAddReceiptSheet(BuildContext context) {
  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<Receipt>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding: const EdgeInsets.symmetric(horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(dialogCtx).height * 0.90,
          child: _AddReceiptContent(onSubmit: (r) => Navigator.pop(dialogCtx, r)),
        ),
      ),
    );
  }

  return showModalBottomSheet<Receipt>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddReceiptSheet(onSubmit: (r) => Navigator.pop(ctx, r)),
  );
}

class _AddReceiptSheet extends StatelessWidget {
  const _AddReceiptSheet({required this.onSubmit});
  final ValueChanged<Receipt> onSubmit;

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
        child: _AddReceiptContent(scrollController: ctrl, onSubmit: onSubmit, showDragHandle: true),
      ),
    );
  }
}

enum _SplitMode { equal, custom }

class _AddReceiptContent extends StatefulWidget {
  const _AddReceiptContent({
    required this.onSubmit,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ValueChanged<Receipt> onSubmit;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddReceiptContent> createState() => _AddReceiptContentState();
}

class _AddReceiptContentState extends State<_AddReceiptContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  ReceiptCategory _category = ReceiptCategory.food;
  String _currency = 'JPY';
  String _paidById = kYouId;
  _SplitMode _splitMode = _SplitMode.equal;
  final Set<String> _splitWith = {for (final m in kMockMembers) m.id};
  final Map<String, TextEditingController> _customCtrls = {
    for (final m in kMockMembers) m.id: TextEditingController(),
  };

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _customCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final total = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final members = _splitMode == _SplitMode.equal
        ? _splitWith.toList()
        : kMockMembers.map((m) => m.id).toList();

    List<ReceiptSplit> splits;
    if (_splitMode == _SplitMode.equal) {
      final share = _splitWith.isEmpty ? 0.0 : total / _splitWith.length;
      splits = members.map((id) => ReceiptSplit(memberId: id, amount: share)).toList();
    } else {
      splits = kMockMembers.map((m) {
        final v = double.tryParse(_customCtrls[m.id]!.text.trim()) ?? 0;
        return ReceiptSplit(memberId: m.id, amount: v);
      }).toList();
    }

    widget.onSubmit(Receipt(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim(),
      amount: total,
      currency: _currency,
      paidById: _paidById,
      splits: splits,
      category: _category,
      date: DateTime.now(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
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
              decoration: const BoxDecoration(
                color: kColorBorder,
                borderRadius: kRadiusPill,
              ),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: Row(
            children: [
              Text('Add receipt', style: kStyleTitle),
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
                    hint: 'e.g. Ramen Ichiran',
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: kSpace4),

                  // Amount + currency row
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: WabwayTextField(
                          label: 'Amount',
                          hint: '0',
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (double.tryParse(v.trim()) == null) return 'Invalid number';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: kSpace3),
                      Expanded(
                        flex: 2,
                        child: WabwaySelectField<String>(
                          label: 'Currency',
                          value: _currency,
                          onChanged: (v) => setState(() => _currency = v ?? 'JPY'),
                          items: const [
                            WabwaySelectItem(value: 'JPY', label: 'JPY ¥'),
                            WabwaySelectItem(value: 'USD', label: 'USD \$'),
                            WabwaySelectItem(value: 'EUR', label: 'EUR €'),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<ReceiptCategory>(
                    label: 'Category',
                    value: _category,
                    onChanged: (v) => setState(() => _category = v ?? ReceiptCategory.food),
                    items: ReceiptCategory.values
                        .map((c) => WabwaySelectItem(value: c, label: c.label))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<String>(
                    label: 'Paid by',
                    value: _paidById,
                    onChanged: (v) => setState(() => _paidById = v ?? kYouId),
                    items: kMockMembers
                        .map((m) => WabwaySelectItem(
                              value: m.id,
                              label: m.isYou ? 'You' : m.name,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  // Split method toggle
                  Text('Split method', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                  const SizedBox(height: kSpace2),
                  _SplitToggle(
                    mode: _splitMode,
                    onChanged: (m) => setState(() => _splitMode = m),
                  ),
                  const SizedBox(height: kSpace3),

                  // Equal split — checkboxes
                  if (_splitMode == _SplitMode.equal)
                    _EqualSplitPicker(
                      selected: _splitWith,
                      onChanged: (id, checked) => setState(() {
                        if (checked) { _splitWith.add(id); } else { _splitWith.remove(id); }
                      }),
                    ),

                  // Custom split — amount per person
                  if (_splitMode == _SplitMode.custom)
                    _CustomSplitPicker(controllers: _customCtrls),

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
                    label: 'Add receipt',
                    icon: Icons.receipt_long_rounded,
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

class _SplitToggle extends StatelessWidget {
  const _SplitToggle({required this.mode, required this.onChanged});
  final _SplitMode mode;
  final ValueChanged<_SplitMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final m in _SplitMode.values)
          Padding(
            padding: const EdgeInsets.only(right: kSpace2),
            child: _ToggleChip(
              label: m == _SplitMode.equal ? 'Equal' : 'Custom',
              selected: mode == m,
              onTap: () => onChanged(m),
            ),
          ),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
        decoration: BoxDecoration(
          color: selected ? kColorPrimary : kColorSurfaceSunken,
          borderRadius: kRadiusPill,
          border: Border.all(
            color: selected ? kColorPrimary : kColorBorder,
          ),
        ),
        child: Text(
          label,
          style: kStyleCaptionMedium.copyWith(
            color: selected ? kColorTextOnPrimary : kColorInkSoft,
          ),
        ),
      ),
    );
  }
}

class _EqualSplitPicker extends StatelessWidget {
  const _EqualSplitPicker({required this.selected, required this.onChanged});
  final Set<String> selected;
  final void Function(String id, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: kMockMembers.map((m) {
        final isChecked = selected.contains(m.id);
        return CheckboxListTile(
          value: isChecked,
          onChanged: (v) => onChanged(m.id, v ?? false),
          title: Text(m.isYou ? 'You' : m.name, style: kStyleBodyMedium),
          secondary: WabwayAvatar(name: m.isYou ? 'You' : m.name, size: WabwayAvatarSize.sm),
          activeColor: kColorPrimary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }
}

class _CustomSplitPicker extends StatelessWidget {
  const _CustomSplitPicker({required this.controllers});
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: kMockMembers.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: kSpace3),
          child: Row(
            children: [
              WabwayAvatar(name: m.isYou ? 'You' : m.name, size: WabwayAvatarSize.sm),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Text(m.isYou ? 'You' : m.name, style: kStyleBodyMedium),
              ),
              const SizedBox(width: kSpace3),
              SizedBox(
                width: 120,
                child: WabwayTextField(
                  hint: '0',
                  controller: controllers[m.id],
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
