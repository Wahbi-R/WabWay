import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/exchange_rate_service.dart';
import '../../core/supabase/money_service.dart';
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

/// Opens the Add Receipt form, or Edit Receipt when [existingReceipt] is passed.
///
/// Pass [tripId], [userId], and [members] from MoneyScreen so the form can
/// save to Supabase. When called without those params the form returns a
/// locally-constructed Receipt and skips the Supabase write.
Future<Receipt?> showAddReceiptSheet(
  BuildContext context, {
  String? tripId,
  String? userId,
  List<TripMember>? members,
  Receipt? existingReceipt,
  String homeCurrency = 'CAD',
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
            tripId:          tripId,
            userId:          effectiveUserId,
            members:         effectiveMembers,
            existingReceipt: existingReceipt,
            homeCurrency:    homeCurrency,
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
      tripId:          tripId,
      userId:          effectiveUserId,
      members:         effectiveMembers,
      existingReceipt: existingReceipt,
      homeCurrency:    homeCurrency,
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
    required this.homeCurrency,
    this.existingReceipt,
  });

  final ValueChanged<Receipt> onSubmit;
  final String? tripId;
  final String userId;
  final List<TripMember> members;
  final String homeCurrency;
  final Receipt? existingReceipt;

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
          tripId:           tripId,
          userId:           userId,
          members:          members,
          existingReceipt:  existingReceipt,
          homeCurrency:     homeCurrency,
          scrollController: ctrl,
          onSubmit:         onSubmit,
          showDragHandle:   true,
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
    required this.homeCurrency,
    this.existingReceipt,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ValueChanged<Receipt> onSubmit;
  /// Null means local-only mode (no Supabase write).
  final String? tripId;
  final String userId;
  final List<TripMember> members;
  final String homeCurrency;
  /// When set, the form pre-fills with this receipt and updates rather than creates.
  final Receipt? existingReceipt;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddReceiptContent> createState() => _AddReceiptContentState();
}

class _AddReceiptContentState extends State<_AddReceiptContent> {
  final _formKey    = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  final _rateCtrl   = TextEditingController();
  final _feePctCtrl = TextEditingController(text: '0');
  final _homeAmountCtrl = TextEditingController();

  late String _paidById;
  late Set<String> _splitWith;
  late Map<String, TextEditingController> _customCtrls;

  ReceiptCategory _category  = ReceiptCategory.food;
  String          _currency  = 'JPY';
  _SplitMode      _splitMode = _SplitMode.equal;
  bool            _loading      = false;
  bool            _fetchingRate = false;
  bool            _showFee      = false;
  bool            _homeOverride = false; // user typed home amount directly
  String?         _error;

  bool get _needsConversion => _currency != widget.homeCurrency;

  // Derived home amount from rate + fee; null if inputs are invalid.
  double? get _derivedHomeAmount {
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null) return null;
    if (!_needsConversion) return amount;
    final rate = double.tryParse(_rateCtrl.text.trim());
    if (rate == null || rate <= 0) return null;
    final feePct = double.tryParse(_feePctCtrl.text.trim()) ?? 0;
    return amount * rate * (1 + feePct / 100);
  }

  // The home amount to use when building splits.
  double get _effectiveHomeAmount {
    if (!_needsConversion) return double.tryParse(_amountCtrl.text.trim()) ?? 0;
    if (_homeOverride) return double.tryParse(_homeAmountCtrl.text.trim()) ?? 0;
    return _derivedHomeAmount ?? 0;
  }

  void _recomputeHome() {
    if (!_homeOverride) setState(() {});
  }

  Future<void> _fetchRate() async {
    if (!_needsConversion) return;
    setState(() => _fetchingRate = true);
    final rate = await ExchangeRateService.fetch(
      _currency, widget.homeCurrency, DateTime.now());
    if (!mounted) return;
    setState(() {
      _fetchingRate = false;
      if (rate != null) {
        _rateCtrl.text = rate.toStringAsFixed(6);
        _homeOverride  = false;
      }
    });
  }

  Uint8List? _photoBytes;
  String?    _photoExt;
  String?    _existingStoragePath;

  // Unified list of linked documents shown in the sheet.
  // Pre-populated with existing links in edit mode; diffed on submit.
  List<TripDocument> _linkedDocs    = [];
  Set<String>        _originalDocIds = {};

  bool get _isEditing => widget.existingReceipt != null;

  @override
  void initState() {
    super.initState();
    final ex = widget.existingReceipt;
    if (ex != null) {
      _titleCtrl.text      = ex.title;
      _amountCtrl.text     = ex.amount.toStringAsFixed(ex.amount.truncateToDouble() == ex.amount ? 0 : 2);
      _notesCtrl.text      = ex.notes ?? '';
      _category            = ex.category;
      _currency            = ex.currency;
      _paidById            = ex.paidById;
      _existingStoragePath = ex.storagePath;
      _splitWith           = {for (final s in ex.splits) s.memberId};
      _customCtrls         = {
        for (final m in widget.members) m.id: TextEditingController(
          text: ex.splits
              .where((s) => s.memberId == m.id)
              .fold(0.0, (a, s) => a + s.amount)
              .toStringAsFixed(2),
        ),
      };
      _splitMode = _SplitMode.custom;
      // Pre-fill conversion fields
      if (ex.exchangeRate != 1.0) {
        _rateCtrl.text    = ex.exchangeRate.toStringAsFixed(6);
        _feePctCtrl.text  = ex.transactionFeePct.toStringAsFixed(2);
      }

      // Pre-load existing linked documents so the user can see and remove them.
      DocService.loadLinkedDocuments(
        linkedType: DocLinkedType.receipt,
        linkedId:   ex.id,
      ).then((docs) {
        if (mounted) {
          setState(() {
            _linkedDocs     = List.of(docs);
            _originalDocIds = docs.map((d) => d.id).toSet();
          });
        }
      }).catchError((_) {});
    } else {
      _paidById  = widget.userId;
      _splitWith = {for (final m in widget.members) m.id};
      _customCtrls = {
        for (final m in widget.members) m.id: TextEditingController(),
      };
      // Fetch the rate for the default currency on first open.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRate());
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _rateCtrl.dispose();
    _feePctCtrl.dispose();
    _homeAmountCtrl.dispose();
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

    // Compute home-currency amounts for splits.
    final homeTotal    = _effectiveHomeAmount;
    final exchangeRate = _needsConversion
        ? (double.tryParse(_rateCtrl.text.trim()) ?? 1.0)
        : 1.0;
    final feePct = _needsConversion
        ? (double.tryParse(_feePctCtrl.text.trim()) ?? 0.0)
        : 0.0;

    List<ReceiptSplit> splits;
    if (_splitMode == _SplitMode.equal) {
      // Splits are stored in home currency.
      final share = _splitWith.isEmpty ? 0.0 : homeTotal / _splitWith.length;
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
        id:                DateTime.now().millisecondsSinceEpoch.toString(),
        title:             title,
        amount:            total,
        currency:          _currency,
        homeAmount:        homeTotal,
        exchangeRate:      exchangeRate,
        transactionFeePct: feePct,
        paidById:          _paidById,
        splits:            splits,
        category:          _category,
        date:              DateTime.now(),
        notes:             notes,
      ));
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      Receipt receipt;
      if (_isEditing) {
        receipt = await MoneyService.updateReceipt(
          receiptId:         widget.existingReceipt!.id,
          paidBy:            _paidById,
          title:             title,
          amount:            total,
          currency:          _currency,
          homeAmount:        homeTotal,
          exchangeRate:      exchangeRate,
          transactionFeePct: feePct,
          category:          _category,
          date:              widget.existingReceipt!.date,
          splits:            splits,
          notes:             notes,
        );
      } else {
        receipt = await MoneyService.createReceipt(
          tripId:            widget.tripId!,
          paidBy:            _paidById,
          title:             title,
          amount:            total,
          currency:          _currency,
          homeAmount:        homeTotal,
          exchangeRate:      exchangeRate,
          transactionFeePct: feePct,
          category:          _category,
          date:              DateTime.now(),
          splits:            splits,
          notes:             notes,
        );
      }
      // Upload photo as a linked document (non-fatal — receipt already saved).
      if (_photoBytes != null && widget.tripId != null) {
        try {
          final userId = supabase.auth.currentUser?.id ?? '';
          final doc = await DocService.uploadAndCreate(
            tripId:    widget.tripId!,
            userId:    userId,
            title:     title,
            type:      DocType.receipt,
            ext:       _photoExt ?? 'jpg',
            bytes:     _photoBytes!,
            fileSizeKb: (_photoBytes!.lengthInBytes / 1024).round(),
          );
          await DocService.addLink(
            documentId: doc.id,
            linkedType: DocLinkedType.receipt,
            linkedId:   receipt.id,
            createdBy:  userId,
          );
        } catch (_) {}
      }
      // Sync document links: add new ones, remove deleted ones (non-fatal).
      final userId       = supabase.auth.currentUser?.id ?? '';
      final currentIds   = _linkedDocs.map((d) => d.id).toSet();
      for (final doc in _linkedDocs) {
        if (!_originalDocIds.contains(doc.id)) {
          try {
            await DocService.addLink(
              documentId: doc.id,
              linkedType: DocLinkedType.receipt,
              linkedId:   receipt.id,
              createdBy:  userId,
            );
          } catch (_) {}
        }
      }
      for (final removedId in _originalDocIds) {
        if (!currentIds.contains(removedId)) {
          try {
            await DocService.deleteLink(
              documentId: removedId,
              linkedType: DocLinkedType.receipt,
              linkedId:   receipt.id,
            );
          } catch (_) {}
        }
      }
      if (mounted) widget.onSubmit(receipt);
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not save receipt.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPad = MediaQuery.viewInsetsOf(context).bottom;
    final navBarPad   = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle) const WabwayDragHandle(),

        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: Row(
            children: [
              Text(_isEditing ? 'Edit receipt' : 'Add receipt', style: kStyleTitle),
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
            padding: EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace4 + keyboardPad),
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
                          onChanged: (_) => _recomputeHome(),
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
                          onChanged: (v) {
                            setState(() {
                              _currency     = v ?? 'JPY';
                              _homeOverride = false;
                              _rateCtrl.clear();
                            });
                            _fetchRate();
                          },
                          items: const [
                            WabwaySelectItem(value: 'JPY', label: 'JPY ¥'),
                            WabwaySelectItem(value: 'USD', label: 'USD \$'),
                            WabwaySelectItem(value: 'EUR', label: 'EUR €'),
                            WabwaySelectItem(value: 'GBP', label: 'GBP £'),
                            WabwaySelectItem(value: 'CAD', label: 'CAD C\$'),
                            WabwaySelectItem(value: 'AUD', label: 'AUD A\$'),
                            WabwaySelectItem(value: 'KRW', label: 'KRW ₩'),
                            WabwaySelectItem(value: 'THB', label: 'THB ฿'),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Conversion section (only when currency ≠ home currency) ──
                  if (_needsConversion) ...[
                    const SizedBox(height: kSpace4),
                    _ConversionSection(
                      homeCurrency:     widget.homeCurrency,
                      rateCtrl:         _rateCtrl,
                      feePctCtrl:       _feePctCtrl,
                      homeAmountCtrl:   _homeAmountCtrl,
                      fetchingRate:     _fetchingRate,
                      showFee:          _showFee,
                      homeOverride:     _homeOverride,
                      derivedHomeAmount: _derivedHomeAmount,
                      onRefetchRate:    _fetchRate,
                      onRateChanged:    (_) => setState(() => _homeOverride = false),
                      onFeeToggle:      () => setState(() => _showFee = !_showFee),
                      onFeeChanged:     (_) => setState(() {}),
                      onHomeOverride:   (v) => setState(() {
                        _homeOverride = true;
                        _homeAmountCtrl.text = v;
                      }),
                      onHomeOverrideClear: () => setState(() {
                        _homeOverride = false;
                        _homeAmountCtrl.clear();
                      }),
                    ),
                  ],
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
                  Text(
                    _needsConversion
                        ? 'Split method  ·  amounts in ${widget.homeCurrency}'
                        : 'Split method',
                    style: kStyleCaptionMedium.copyWith(color: kColorInk),
                  ),
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
                  const SizedBox(height: kSpace4),

                  _PhotoUploadZone(
                    photoBytes:          _photoBytes,
                    existingStoragePath: _existingStoragePath,
                    onPicked: (bytes, ext) => setState(() {
                      _photoBytes = bytes;
                      _photoExt   = ext;
                    }),
                    onRemoved: () => setState(() {
                      _photoBytes          = null;
                      _photoExt            = null;
                      _existingStoragePath = null;
                    }),
                  ),
                  const SizedBox(height: kSpace4),

                  if (widget.tripId != null)
                    _DocLinkSection(
                      tripId:     widget.tripId!,
                      linkedDocs: _linkedDocs,
                      onAdd:      (doc) => setState(() => _linkedDocs.add(doc)),
                      onRemove:   (doc) => setState(() => _linkedDocs.remove(doc)),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Sticky footer — always visible above nav bar
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 0),
            child: Text(_error!, style: kStyleBody.copyWith(color: kColorDanger)),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace4 + navBarPad),
          child: WabwayButton(
            label: _isEditing ? 'Save changes' : 'Add receipt',
            icon: Icons.receipt_long_rounded,
            fullWidth: true,
            size: WabwayButtonSize.lg,
            loading: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ),
      ],
    );
  }
}

// ─── Conversion section ───────────────────────────────────────────────────────

class _ConversionSection extends StatelessWidget {
  const _ConversionSection({
    required this.homeCurrency,
    required this.rateCtrl,
    required this.feePctCtrl,
    required this.homeAmountCtrl,
    required this.fetchingRate,
    required this.showFee,
    required this.homeOverride,
    required this.derivedHomeAmount,
    required this.onRefetchRate,
    required this.onRateChanged,
    required this.onFeeToggle,
    required this.onFeeChanged,
    required this.onHomeOverride,
    required this.onHomeOverrideClear,
  });

  final String homeCurrency;
  final TextEditingController rateCtrl;
  final TextEditingController feePctCtrl;
  final TextEditingController homeAmountCtrl;
  final bool fetchingRate;
  final bool showFee;
  final bool homeOverride;
  final double? derivedHomeAmount;
  final VoidCallback onRefetchRate;
  final ValueChanged<String> onRateChanged;
  final VoidCallback onFeeToggle;
  final ValueChanged<String> onFeeChanged;
  final ValueChanged<String> onHomeOverride;
  final VoidCallback onHomeOverrideClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kColorPrimarySoft,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorPrimary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.currency_exchange_rounded, size: 14, color: kColorPrimary),
              const SizedBox(width: kSpace2),
              Text('Exchange to $homeCurrency',
                  style: kStyleCaptionMedium.copyWith(color: kColorPrimary)),
            ],
          ),
          const SizedBox(height: kSpace3),

          // Exchange rate row
          Row(
            children: [
              Expanded(
                child: WabwayTextField(
                  label: 'Exchange rate',
                  hint: '0.000000',
                  controller: rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onChanged: onRateChanged,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                ),
              ),
              const SizedBox(width: kSpace2),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: fetchingRate
                    ? const SizedBox(
                        width: 36, height: 36,
                        child: Center(child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kColorPrimary),
                        )),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        color: kColorPrimary,
                        tooltip: 'Refresh rate',
                        onPressed: onRefetchRate,
                      ),
              ),
            ],
          ),

          // Transaction fee toggle
          const SizedBox(height: kSpace2),
          GestureDetector(
            onTap: onFeeToggle,
            child: Row(
              children: [
                Icon(
                  showFee
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16, color: kColorInkSoft,
                ),
                const SizedBox(width: 4),
                Text(
                  showFee ? 'Hide card fee' : 'Add card fee',
                  style: kStyleCaption.copyWith(color: kColorInkSoft),
                ),
              ],
            ),
          ),

          if (showFee) ...[
            const SizedBox(height: kSpace3),
            WabwayTextField(
              label: 'Transaction fee %',
              hint: '0',
              controller: feePctCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              onChanged: onFeeChanged,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            ),
          ],

          const SizedBox(height: kSpace3),
          const Divider(height: 1),
          const SizedBox(height: kSpace3),

          // Home amount display / override
          if (!homeOverride) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$homeCurrency equivalent',
                          style: kStyleCaption.copyWith(color: kColorInkSoft)),
                      const SizedBox(height: 2),
                      Text(
                        derivedHomeAmount != null
                            ? fmtAmount(derivedHomeAmount!, homeCurrency)
                            : '—',
                        style: kStyleBodySemibold.copyWith(color: kColorPrimary),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    final v = derivedHomeAmount?.toStringAsFixed(2) ?? '';
                    onHomeOverride(v);
                  },
                  child: Text('Override', style: kStyleCaption.copyWith(color: kColorInkSoft)),
                ),
              ],
            ),
          ] else ...[
            WabwayTextField(
              label: '$homeCurrency equivalent (overridden)',
              hint: '0.00',
              controller: homeAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
            ),
            const SizedBox(height: kSpace2),
            GestureDetector(
              onTap: onHomeOverrideClear,
              child: Text('← Use calculated amount',
                  style: kStyleCaption.copyWith(color: kColorInkSoft)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Photo upload zone ────────────────────────────────────────────────────────

class _PhotoUploadZone extends StatelessWidget {
  const _PhotoUploadZone({
    required this.onPicked,
    required this.onRemoved,
    this.photoBytes,
    this.existingStoragePath,
  });

  final Uint8List? photoBytes;
  final String? existingStoragePath;
  final void Function(Uint8List bytes, String ext) onPicked;
  final VoidCallback onRemoved;

  bool get _hasPhoto => photoBytes != null || existingStoragePath != null;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 2048,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final ext   = file.name.contains('.')
        ? file.name.split('.').last.toLowerCase()
        : 'jpg';
    onPicked(bytes, ext);
  }

  void _showSourcePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WabwayDragHandle(),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take photo'),
              onTap: () { Navigator.pop(ctx); _pick(context, ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () { Navigator.pop(ctx); _pick(context, ImageSource.gallery); },
            ),
            if (_hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: kColorDanger),
                title: const Text('Remove photo', style: TextStyle(color: kColorDanger)),
                onTap: () { Navigator.pop(ctx); onRemoved(); },
              ),
            const SizedBox(height: kSpace2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        GestureDetector(
          onTap: () => _showSourcePicker(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _hasPhoto ? kColorPrimarySoft : kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border: Border.all(
                color: _hasPhoto ? kColorPrimary : kColorBorder,
              ),
            ),
            child: photoBytes != null
                // New photo picked — show thumbnail with remove ✕
                ? Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Image.memory(
                        photoBytes!,
                        height: 180,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                      Padding(
                        padding: const EdgeInsets.all(kSpace2),
                        child: Material(
                          color: Colors.black54,
                          borderRadius: kRadiusPill,
                          child: InkWell(
                            borderRadius: kRadiusPill,
                            onTap: onRemoved,
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                // No new photo — show icon + label (existing or empty)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: kSpace5),
                    child: Column(
                      children: [
                        Icon(
                          _hasPhoto
                              ? Icons.check_circle_outline_rounded
                              : Icons.add_photo_alternate_rounded,
                          size: 32,
                          color: _hasPhoto ? kColorPrimary : kColorInkSoft,
                        ),
                        const SizedBox(height: kSpace2),
                        Text(
                          _hasPhoto
                              ? 'Photo attached — tap to replace'
                              : 'Tap to add a photo',
                          style: kStyleBodyMedium.copyWith(
                            color: _hasPhoto ? kColorPrimary : kColorInkSoft,
                          ),
                        ),
                        if (!_hasPhoto) ...[
                          const SizedBox(height: kSpace1),
                          Text('Camera or gallery', style: kStyleCaption),
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

// ─── Document link section ────────────────────────────────────────────────────

class _DocLinkSection extends StatefulWidget {
  const _DocLinkSection({
    required this.tripId,
    required this.linkedDocs,
    required this.onAdd,
    required this.onRemove,
  });

  final String tripId;
  final List<TripDocument> linkedDocs;
  final ValueChanged<TripDocument> onAdd;
  final ValueChanged<TripDocument> onRemove;

  @override
  State<_DocLinkSection> createState() => _DocLinkSectionState();
}

class _DocLinkSectionState extends State<_DocLinkSection> {
  List<TripDocument>? _allDocs;

  @override
  void initState() {
    super.initState();
    DocService.loadDocuments(widget.tripId).then((docs) {
      if (mounted) setState(() => _allDocs = docs);
    }).catchError((_) {
      if (mounted) setState(() => _allDocs = []);
    });
  }

  void _showPicker() {
    if (_allDocs == null || _allDocs!.isEmpty) return;
    final available = _allDocs!
        .where((d) => !widget.linkedDocs.any((l) => l.id == d.id))
        .toList();
    if (available.isEmpty) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, ctrl) => Column(
          children: [
            const WabwayDragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select document', style: kStyleTitle),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: ctrl,
                itemCount: available.length,
                itemBuilder: (_, i) {
                  final doc = available[i];
                  return ListTile(
                    leading: Icon(doc.type.icon, color: kColorInkSoft),
                    title: Text(doc.title, style: kStyleBodyMedium),
                    subtitle: Text(doc.type.label, style: kStyleCaption),
                    onTap: () {
                      Navigator.pop(ctx);
                      widget.onAdd(doc);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Documents', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),

        if (widget.linkedDocs.isNotEmpty) ...[
          ...widget.linkedDocs.map((doc) => Padding(
            padding: const EdgeInsets.only(bottom: kSpace2),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
              decoration: BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusMd,
                border: Border.all(color: kColorBorder),
              ),
              child: Row(
                children: [
                  Icon(doc.type.icon, size: 16, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(doc.title, style: kStyleBodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  GestureDetector(
                    onTap: () => widget.onRemove(doc),
                    child: const Icon(Icons.close_rounded, size: 16, color: kColorInkSoft),
                  ),
                ],
              ),
            ),
          )),
          const SizedBox(height: kSpace2),
        ],

        GestureDetector(
          onTap: _allDocs == null ? null : _showPicker,
          child: Container(
            padding: const EdgeInsets.all(kSpace3),
            decoration: BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border: Border.all(color: kColorBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.attach_file_rounded, size: 18, color: kColorInkSoft),
                const SizedBox(width: kSpace2),
                Text(
                  _allDocs == null
                      ? 'Loading documents…'
                      : (_allDocs!.isEmpty
                          ? 'No documents in this trip'
                          : 'Attach a document'),
                  style: kStyleBody.copyWith(color: kColorInkSoft),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Split controls ───────────────────────────────────────────────────────────

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
