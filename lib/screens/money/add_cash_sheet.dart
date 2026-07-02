import 'package:flutter/material.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/money_service.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

/// Opens the Add Withdrawal form.
///
/// Pass [tripId], [userId], and [members] from MoneyScreen so the form can
/// save to Supabase. When called without those params the form returns a
/// locally-constructed CashWithdrawal and skips the Supabase write.
Future<CashWithdrawal?> showAddCashSheet(
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
    return showDialog<CashWithdrawal>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: kSpace8, vertical: kSpace8),
        child: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(dialogCtx).height * 0.90,
          child: _AddCashContent(
            tripId:  tripId,
            userId:  effectiveUserId,
            members: effectiveMembers,
            onSubmit: (w) => Navigator.pop(dialogCtx, w),
          ),
        ),
      ),
    );
  }

  return showModalBottomSheet<CashWithdrawal>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddCashSheet(
      tripId:  tripId,
      userId:  effectiveUserId,
      members: effectiveMembers,
      onSubmit: (w) => Navigator.pop(ctx, w),
    ),
  );
}

class _AddCashSheet extends StatelessWidget {
  const _AddCashSheet({
    required this.onSubmit,
    required this.tripId,
    required this.userId,
    required this.members,
  });

  final ValueChanged<CashWithdrawal> onSubmit;
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
        child: _AddCashContent(
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

class _AddCashContent extends StatefulWidget {
  const _AddCashContent({
    required this.onSubmit,
    required this.tripId,
    required this.userId,
    required this.members,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ValueChanged<CashWithdrawal> onSubmit;
  /// Null means local-only mode (no Supabase write).
  final String? tripId;
  final String userId;
  final List<TripMember> members;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddCashContent> createState() => _AddCashContentState();
}

class _AddCashContentState extends State<_AddCashContent> {
  final _formKey    = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _feeCtrl    = TextEditingController();
  final _notesCtrl  = TextEditingController();

  late String _withdrawnById;
  late Map<String, TextEditingController> _distCtrls;

  String  _currency = 'JPY';
  bool    _loading  = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _withdrawnById = widget.userId;
    _distCtrls = {
      for (final m in widget.members) m.id: TextEditingController(),
    };
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _feeCtrl.dispose();
    _notesCtrl.dispose();
    for (final c in _distCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final fee    = double.tryParse(_feeCtrl.text.trim()) ?? 0;
    final notes  =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    final distributions = widget.members.map((m) {
      final v =
          double.tryParse(_distCtrls[m.id]?.text.trim() ?? '') ?? 0;
      return CashDistribution(memberId: m.id, amount: v);
    }).where((d) => d.amount > 0).toList();

    // Local-only mode when tripId was not provided.
    if (widget.tripId == null) {
      widget.onSubmit(CashWithdrawal(
        id:           DateTime.now().millisecondsSinceEpoch.toString(),
        withdrawnById: _withdrawnById,
        amount:       amount,
        currency:     _currency,
        atmFee:       fee,
        date:         DateTime.now(),
        notes:        notes,
        distributions: distributions,
      ));
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final withdrawal = await MoneyService.createWithdrawal(
        tripId:        widget.tripId!,
        withdrawnBy:   _withdrawnById,
        amount:        amount,
        currency:      _currency,
        atmFee:        fee,
        date:          DateTime.now(),
        distributions: distributions,
        notes:         notes,
      );
      if (mounted) widget.onSubmit(withdrawal);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not save withdrawal.'; });
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
              Text('Add withdrawal', style: kStyleTitle),
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
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: WabwayTextField(
                          label: 'Amount withdrawn',
                          hint: '0',
                          controller: _amountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            if (double.tryParse(v.trim()) == null) {
                              return 'Invalid';
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

                  WabwayTextField(
                    label: 'ATM fee (optional)',
                    hint: '0',
                    controller: _feeCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    prefixIcon: Icons.atm_rounded,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<String>(
                    label: 'Withdrawn by',
                    value: _withdrawnById,
                    onChanged: (v) =>
                        setState(() => _withdrawnById = v ?? widget.userId),
                    items: widget.members
                        .map((m) => WabwaySelectItem(
                              value: m.id,
                              label: m.isYou ? 'You' : m.name,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  Text(
                    'Distribute cash to',
                    style: kStyleCaptionMedium.copyWith(color: kColorInk),
                  ),
                  Text(
                    'Enter how much cash each person received.',
                    style: kStyleCaption,
                  ),
                  const SizedBox(height: kSpace3),

                  ...widget.members.map((m) => Padding(
                        padding: const EdgeInsets.only(bottom: kSpace3),
                        child: Row(
                          children: [
                            WabwayAvatar(
                                name: m.isYou ? 'You' : m.name,
                                size: WabwayAvatarSize.sm),
                            const SizedBox(width: kSpace3),
                            Expanded(
                              child: Text(m.isYou ? 'You' : m.name,
                                  style: kStyleBodyMedium),
                            ),
                            const SizedBox(width: kSpace3),
                            SizedBox(
                              width: 120,
                              child: WabwayTextField(
                                hint: '0',
                                controller: _distCtrls[m.id],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ],
                        ),
                      )),

                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Notes',
                    hint: 'ATM location, purpose…',
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
                    label: 'Add withdrawal',
                    icon: Icons.atm_rounded,
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
