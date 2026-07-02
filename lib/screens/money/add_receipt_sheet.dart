import 'package:flutter/material.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/money_service.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

/// Opens the Add Receipt form.
///
/// Pass [tripId], [userId], and [members] from MoneyScreen so the form can
/// save to Supabase. When called without those params (e.g. from doc_detail as
/// a placeholder) the form returns a locally-constructed Receipt and skips the
/// Supabase write.
Future<Receipt?> showAddReceiptSheet(
  BuildContext context, {
  String? tripId,
  String? userId,
  List<TripMember>? members,
}) {
  final effectiveUserId = userId ?? supabase.auth.currentUser?.id ?? kYouId;
  final effectiveMembers = (members != null && members.isNotEmpty)
      ? members
      : kMockMembers.isNotEmpty
          ? kMockMembers
          : [TripMember(id: effectiveUserId, name: 'You')];

  final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

  if (isDesktop) {
    return showDialog<Receipt>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(dialogCtx).height * 0.90,
          child: _AddReceiptContent(
            tripId:  tripId,
            userId:  effectiveUserId,
            members: effectiveMembers,
            onSubmit: (r) => Navigator.pop(dialogCtx, r),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<Receipt>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddReceiptSheet(
      tripId:  tripId,
      userId:  effectiveUserId,
      members: effectiveMembers,
      onSubmit: (r) => Navigator.pop(ctx, r),
    ),
  );
}

class _AddReceiptSheet extends StatelessWidget {
  const _AddReceiptSheet({
    required this.onSubmit,
    required this.tripId,
    required this.userId,
    required this.members,
  });

  final ValueChanged<Receipt> onSubmit;
  final String? tripId;
  final String userId;
  final List<TripMember> members;

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
        child: _AddReceiptContent(
          tripId:          tripId,
          userId:          userId,
          members:         members,
          scrollController: ctrl,
          onSubmit:        onSubmit,
          showDragHandle:  true,
        ),
      ),
    );
  }
}

enum _SplitMode { equal, custom }

class _AddReceiptContent extends StatefulWidget {
  const _AddReceiptContent({
    required this.onSubmit,
    required this.tripId,
    required this.userId,
    required this.members,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ValueChanged<Receipt> onSubmit;
  /// Null means local-only mode (no Supabase write).
  final String? tripId;
  final String userId;
  final List<TripMember> members;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddReceiptContent> createState() => _AddReceiptContentState();
}

class _AddReceiptContentState extends State<_AddReceiptContent> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();

  late String _paidById;
  late Set<String> _splitWith;
  late Map<String, TextEditingController> _customCtrls;

  ReceiptCategory _category  = ReceiptCategory.food;
  String          _currency  = 'JPY';
  _SplitMode      _splitMode = _SplitMode.equal;
  bool            _loading   = false;
  String?         _error;

  @override
  void initState() {
    super.initState();
    _paidById  = widget.userId;
    _splitWith = {for (final m in widget.members) m.id};
    _customCtrls = {
      for (final m in widget.members) m.id: TextEditingController(),
    };
  }

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final total = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final title = _titleCtrl.text.trim();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    List<ReceiptSplit> splits;
    if (_splitMode == _SplitMode.equal) {
      final share = _splitWith.isEmpty ? 0.0 : total / _splitWith.length;
      splits = _splitWith
          .map((id) => ReceiptSplit(memberId: id, amount: share))
          .toList();
    } else {
      splits = widget.members.map((m) {
        final v = double.tryParse(_customCtrls[m.id]?.text.trim() ?? '') ?? 0;
        return ReceiptSplit(memberId: m.id, amount: v);
      }).toList();
    }

    // Local-only mode when tripId was not provided.
    if (widget.tripId == null) {
      widget.onSubmit(Receipt(
        id:       DateTime.now().millisecondsSinceEpoch.toString(),
        title:    title,
        amount:   total,
        currency: _currency,
        paidById: _paidById,
        splits:   splits,
        category: _category,
        date:     DateTime.now(),
        notes:    notes,
      ));
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final receipt = await MoneyService.createReceipt(
        tripId:   widget.tripId!,
        paidBy:   _paidById,
        title:    title,
        amount:   total,
        currency: _currency,
        category: _category,
        date:     DateTime.now(),
        splits:   splits,
        notes:    notes,
      );
      if (mounted) widget.onSubmit(receipt);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not save receipt.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.viewInsetsOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle) const WabwayDragHandle(),

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
            padding: EdgeInsets.fromLTRB(
                kSpace4, 0, kSpace4, kSpace6 + bottomPad),
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
                        (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                  ),
                  const SizedBox(height: kSpace4),

                  // Amount + currency
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: WabwayTextField(
                          label: 'Amount',
                          hint: '0',
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (double.tryParse(v.trim()) == null) {
                              return 'Invalid number';
                            }
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
                          onChanged: (v) =>
                              setState(() => _currency = v ?? 'JPY'),
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
                    onChanged: (v) =>
                        setState(() => _category = v ?? ReceiptCategory.food),
                    items: ReceiptCategory.values
                        .map((c) =>
                            WabwaySelectItem(value: c, label: c.label))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<String>(
                    label: 'Paid by',
                    value: _paidById,
                    onChanged: (v) =>
                        setState(() => _paidById = v ?? widget.userId),
                    items: widget.members
                        .map((m) => WabwaySelectItem(
                              value: m.id,
                              label: m.isYou ? 'You' : m.name,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  // Split method
                  Text('Split method',
                      style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                  const SizedBox(height: kSpace2),
                  _SplitToggle(
                    mode: _splitMode,
                    onChanged: (m) => setState(() => _splitMode = m),
                  ),
                  const SizedBox(height: kSpace3),

                  if (_splitMode == _SplitMode.equal)
                    _EqualSplitPicker(
                      members: widget.members,
                      selected: _splitWith,
                      onChanged: (id, checked) => setState(() {
                        if (checked) {
                          _splitWith.add(id);
                        } else {
                          _splitWith.remove(id);
                        }
                      }),
                    ),

                  if (_splitMode == _SplitMode.custom)
                    _CustomSplitPicker(
                        members: widget.members, controllers: _customCtrls),

                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Notes',
                    hint: 'Optional notes…',
                    controller: _notesCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: kSpace3),
                    Text(_error!,
                        style: kStyleBody.copyWith(color: kColorDanger)),
                  ],

                  const SizedBox(height: kSpace6),

                  WabwayButton(
                    label: 'Add receipt',
                    icon: Icons.receipt_long_rounded,
                    fullWidth: true,
                    size: WabwayButtonSize.lg,
                    onPressed: _loading ? null : _submit,
                  ),

                  if (_loading) ...[
                    const SizedBox(height: kSpace4),
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
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
  const _ToggleChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
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
  const _EqualSplitPicker(
      {required this.members, required this.selected, required this.onChanged});
  final List<TripMember> members;
  final Set<String> selected;
  final void Function(String id, bool checked) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: members.map((m) {
        final isChecked = selected.contains(m.id);
        return CheckboxListTile(
          value: isChecked,
          onChanged: (v) => onChanged(m.id, v ?? false),
          title: Text(m.isYou ? 'You' : m.name, style: kStyleBodyMedium),
          secondary: WabwayAvatar(
              name: m.isYou ? 'You' : m.name, size: WabwayAvatarSize.sm),
          activeColor: kColorPrimary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }
}

class _CustomSplitPicker extends StatelessWidget {
  const _CustomSplitPicker(
      {required this.members, required this.controllers});
  final List<TripMember> members;
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: members.map((m) {
        return Padding(
          padding: const EdgeInsets.only(bottom: kSpace3),
          child: Row(
            children: [
              WabwayAvatar(
                  name: m.isYou ? 'You' : m.name, size: WabwayAvatarSize.sm),
              const SizedBox(width: kSpace3),
              Expanded(
                child:
                    Text(m.isYou ? 'You' : m.name, style: kStyleBodyMedium),
              ),
              const SizedBox(width: kSpace3),
              SizedBox(
                width: 120,
                child: WabwayTextField(
                  hint: '0',
                  controller: controllers[m.id],
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
