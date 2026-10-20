import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/notifications/push_notifier.dart';
import '../../core/receipt_followups.dart';
import '../../core/receipt_scan_service.dart';
import '../../core/receipts_link_service.dart';
import '../../core/supabase/client.dart';
import '../../core/sync_queue.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/exchange_rate_service.dart';
import '../../core/supabase/money_service.dart';
import '../../data/docs_data.dart';
import 'receipt_items_editor.dart';
import '../notification_settings_screen.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../core/text_utils.dart';
import '../../widgets/widgets.dart';
import '../../data/currencies.dart';
import '../../data/share_data.dart';

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
  String? defaultCurrency,
  bool isDuplicate = false,
  ImportPrefill? prefill,
}) {
  final effectiveUserId = userId ?? supabase.auth.currentUser?.id ?? kYouId;
  final effectiveMembers = (members != null && members.isNotEmpty)
      ? members
      : kMockMembers.isNotEmpty
          ? kMockMembers
          : [TripMember(id: effectiveUserId, name: 'You', isMe: true)];

  return showWabwayFormSheet<Receipt>(
    context,
    desktopHeightFactor: 0.90,
    initialChildSize: 0.92,
    minChildSize: 0.5,
    maxChildSize: 0.97,
    builder: (ctx, scroll, handle, close) => _AddReceiptContent(
      tripId:          tripId,
      userId:          effectiveUserId,
      members:         effectiveMembers,
      existingReceipt: existingReceipt,
      homeCurrency:    homeCurrency,
      defaultCurrency: defaultCurrency,
      prefill: prefill,
      isDuplicate:     isDuplicate,
      scrollController: scroll,
      showDragHandle: handle,
      onSubmit: close,
    ),
  );
}

enum _SplitMode { equal, custom, items }

class _AddReceiptContent extends StatefulWidget {
  const _AddReceiptContent({
    required this.onSubmit,
    required this.tripId,
    required this.userId,
    required this.members,
    required this.homeCurrency,
    this.defaultCurrency,
    this.prefill,
    this.existingReceipt,
    this.isDuplicate = false,
    this.scrollController,
    this.showDragHandle = false,
  });

  final ValueChanged<Receipt> onSubmit;
  /// Null means local-only mode (no Supabase write).
  final String? tripId;
  final String userId;
  final List<TripMember> members;
  final String homeCurrency;

  /// Currency a NEW receipt starts in — the trip's spending currency.
  /// Falls back to [homeCurrency].
  final String? defaultCurrency;
  final ImportPrefill? prefill;
  /// When set, the form pre-fills with this receipt and updates rather than creates.
  final Receipt? existingReceipt;
  /// When true, pre-fills from [existingReceipt] but creates a new receipt instead of editing.
  final bool isDuplicate;
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
  late String     _currency  = widget.defaultCurrency ?? widget.homeCurrency;
  _SplitMode      _splitMode = _SplitMode.equal;
  bool            _loading      = false;
  bool            _fetchingRate = false;
  bool            _showFee      = false;
  bool            _homeOverride = false; // user typed home amount directly
  bool            _scanning     = false;
  bool            _createLink   = true;
  /// The itemized bill when splitting by item.
  ReceiptItemization? _items;
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
    if (_homeOverride) {
      _rateFromHome(); // the typed home amount stays; the rate follows it
    } else {
      setState(() {});
    }
  }

  /// The home amount was typed (Override): work the exchange rate back out
  /// of it — amount × rate × (1 + card fee) = home amount — so the rate on
  /// the receipt matches what was actually charged.
  void _rateFromHome() {
    final home = double.tryParse(_homeAmountCtrl.text.trim());
    final amount = double.tryParse(_amountCtrl.text.trim());
    final feePct = double.tryParse(_feePctCtrl.text.trim()) ?? 0;
    if (home == null || home <= 0 || amount == null || amount <= 0) return;
    setState(() => _rateCtrl.text = (home / (amount * (1 + feePct / 100))).toStringAsFixed(6));
  }

  Future<void> _fetchRate() async {
    if (!_needsConversion) return;
    setState(() => _fetchingRate = true);
    final rate = await ExchangeRateService.fetch(_currency, widget.homeCurrency);
    if (!mounted) return;
    setState(() {
      _fetchingRate = false;
      if (rate != null) {
        _rateCtrl.text = rate.toStringAsFixed(6);
        _homeOverride  = false;
      }
    });
  }

  /// New photos (several for a long receipt, top to bottom).
  final List<ScanImage> _photos = [];
  String?    _existingStoragePath;

  // Documents to attach to a NEW receipt (an existing receipt manages its
  // attachments from its detail page — AttachedDocsSection).
  List<TripDocument> _tripDocs = [];
  final Set<String>  _docIds   = {};

  bool get _isEditing => widget.existingReceipt != null && !widget.isDuplicate;

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
              .toStringAsFixed(currencyDecimals(ex.currency)),
        ),
      };
      _items     = ex.items;
      _splitMode = ex.isItemized ? _SplitMode.items : _SplitMode.custom;
      // Pre-fill conversion fields
      if (ex.exchangeRate != 1.0) {
        _rateCtrl.text    = ex.exchangeRate.toStringAsFixed(6);
        _feePctCtrl.text  = ex.transactionFeePct.toStringAsFixed(2);
      }
    } else {
      final pre = widget.prefill;
      if (pre != null) {
        _titleCtrl.text = pre.title ?? '';
        _notesCtrl.text = pre.notes ?? '';
        if (pre.amount != null) {
          _amountCtrl.text = pre.amount!.toStringAsFixed(
              pre.amount!.truncateToDouble() == pre.amount ? 0 : 2);
        }
        if (pre.currency != null) _currency = pre.currency!;
        if (pre.fileBytes != null) {
          _photos.add(ScanImage(pre.fileBytes!, pre.fileExt ?? 'jpg'));
        }
        _docIds.addAll(pre.linkedDocIds);
      }
      if (widget.tripId != null) {
        DocService.loadDocuments(widget.tripId!).then((docs) {
          if (mounted) setState(() => _tripDocs = docs);
        }).catchError((_) {});
      }
      _paidById  = widget.userId;
      _splitWith = {for (final m in widget.members) m.id};
      _customCtrls = {
        for (final m in widget.members) m.id: TextEditingController(),
      };
      // Fetch the rate for the default currency on first open.
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRate());
      ReceiptsLinkService.defaultCreateLink().then((v) {
        if (v != null && mounted) setState(() => _createLink = v);
      });
    }
  }

  void _setCreateLink(bool v) {
    setState(() => _createLink = v);
    ReceiptsLinkService.setDefaultCreateLink(v);
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

  /// Scan the photos and open the item split with what was read.
  Future<void> _scan() async {
    if (_photos.isEmpty || _scanning) return;
    setState(() => _scanning = true);
    final outcome = await ReceiptScanService.scan(_photos);
    if (!mounted) return;
    setState(() => _scanning = false);
    if (!outcome.ok) {
      showWabwaySnack(context, outcome.error!, error: true, duration: const Duration(seconds: 5));
      return;
    }
    final scanned = outcome.itemization!;
    if (_titleCtrl.text.trim().isEmpty && (scanned.title?.isNotEmpty ?? false)) {
      _titleCtrl.text = scanned.title!;
    }
    await _editItems(scanned);
  }

  /// Open the item split (works offline — items can be typed in by hand).
  Future<void> _editItems([ReceiptItemization? start]) async {
    final result = await showReceiptItemsEditor(
      context,
      initial:  start ?? _items ?? ReceiptItemization.empty,
      members:  widget.members,
      currency: _currency,
    );
    if (result == null || !mounted) return;
    setState(() {
      _items     = result;
      _splitMode = _SplitMode.items;
      _amountCtrl.text = result.total.toStringAsFixed(currencyDecimals(_currency));
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // A foreign-currency receipt needs a rate (or a manual home amount) —
    // otherwise it would save with a 0 home amount, totals show $0 and the
    // equal split collapses to nothing.
    if (_needsConversion && _effectiveHomeAmount <= 0) {
      if (_fetchingRate) {
        setState(() => _error = 'Still fetching the exchange rate — try again in a moment.');
      } else {
        setState(() => _error =
            "Couldn't get a ${_currency}→${widget.homeCurrency} rate. Enter the rate or the ${widget.homeCurrency} amount.");
        _fetchRate();
      }
      return;
    }

    if (_splitMode == _SplitMode.items && (_items == null || _items!.isEmpty)) {
      setState(() => _error = 'Add the items (scan or by hand), or pick Equal / Custom.');
      return;
    }
    final total = _splitMode == _SplitMode.items
        ? _items!.total
        : double.tryParse(_amountCtrl.text.trim()) ?? 0;
    final title = _titleCtrl.text.trim();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    // The home-currency equivalent of the whole receipt (for totals). Shares
    // themselves are in the receipt's currency.
    final homeTotal    = _effectiveHomeAmount;
    final exchangeRate = _needsConversion
        ? (double.tryParse(_rateCtrl.text.trim()) ?? 1.0)
        : 1.0;
    final feePct = _needsConversion
        ? (double.tryParse(_feePctCtrl.text.trim()) ?? 0.0)
        : 0.0;

    final items = _splitMode == _SplitMode.items ? _items : null;
    final splits = switch (_splitMode) {
      _SplitMode.equal => [
          for (final id in _splitWith)
            ReceiptSplit(memberId: id, amount: total / _splitWith.length),
        ],
      _SplitMode.custom => [
          for (final m in widget.members)
            ReceiptSplit(
              memberId: m.id,
              amount: double.tryParse(_customCtrls[m.id]?.text.trim() ?? '') ?? 0,
            ),
        ],
      _SplitMode.items => items!.toSplits(widget.members.map((m) => m.id), _currency),
    };

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
        items:             items,
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
          items:             items,
          previousSplits:    widget.existingReceipt!.splits,
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
          items:             items,
        );
      }
      // Photos → attached Receipt documents; picked docs attached; Receipts
      // link published (or queued). All non-fatal — the receipt is saved.
      final followups = await runReceiptFollowups(
        tripId:     widget.tripId!,
        userId:     supabase.auth.currentUser?.id ?? widget.userId,
        receipt:    receipt,
        members:    widget.members,
        photos:     _photos,
        docIds:     _isEditing ? const [] : _docIds,
        createLink: !_isEditing && _createLink,
      );
      receipt = followups.receipt;
      var linkChangedRemotely = false;
      if (_isEditing && receipt.splitLinkId != null) {
        final (result, pushed) = await ReceiptsLinkService.push(receipt, widget.members);
        receipt = pushed;
        linkChangedRemotely = result == LinkPushResult.remoteChanged;
      }
      if (!mounted) return;
      if (followups.docsFailed) {
        showWabwaySnack(context, 'Receipt saved, but some photos or documents could not be attached.');
      } else if (followups.linkQueued) {
        showWabwaySnack(context, "Receipt saved — the Receipts link will be created when you're back online.");
      } else if (linkChangedRemotely) {
        showWabwaySnack(context,
            'Saved. People changed the Receipts link too — open the receipt to review their changes.',
            duration: const Duration(seconds: 5));
      }
      widget.onSubmit(receipt);
      if (!_isEditing && widget.tripId != null) {
        pushNotify(
          tripId: widget.tripId!,
          title: 'New receipt added',
          body: '$title · ${_currency} ${total.toStringAsFixed(2)}',
          excludeUserId: supabase.auth.currentUser?.id,
          data: {'screen': 'money', 'trip_id': widget.tripId!},
          prefKey: kPrefNotifMoney,
        );
      }
    } catch (_) {
      // If offline and this is a new receipt (not an edit), queue it for replay.
      if (!_isEditing && widget.tripId != null) {
        final connectivity = await Connectivity().checkConnectivity();
        final isOffline = connectivity.every((r) => r == ConnectivityResult.none);
        if (isOffline) {
          try {
            await SyncQueue.enqueueReceipt(
              widget.tripId!,
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
              items:             items,
              photos:            _photos,
              docIds:            _docIds,
              createLink:        _createLink,
            );
            if (mounted) {
              Navigator.of(context).pop();
              showWabwaySnack(context, 'Saved offline — will sync when you reconnect', duration: Duration(seconds: 4));
            }
            return;
          } catch (_) {
            // Fall through to generic error state below.
          }
        }
      }
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
              Text(widget.isDuplicate ? 'Duplicate receipt' : _isEditing ? 'Edit receipt' : 'Add receipt', style: kStyleTitle),
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
                          readOnly: _splitMode == _SplitMode.items,
                          helpText: _splitMode == _SplitMode.items ? 'From the items' : null,
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
                              _currency     = v ?? widget.homeCurrency;
                              _homeOverride = false;
                              _rateCtrl.clear();
                              if (_splitMode == _SplitMode.items && _items != null) {
                                _amountCtrl.text = _items!.total
                                    .toStringAsFixed(currencyDecimals(_currency));
                              }
                            });
                            _fetchRate();
                          },
                          items: [
                            for (final c in currencyOptions(include: _currency))
                              WabwaySelectItem(value: c.$1, label: c.$2),
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
                      onFeeChanged:     (_) => _recomputeHome(),
                      onHomeOverride:   (v) => setState(() {
                        _homeOverride = true;
                        _homeAmountCtrl.text = v;
                      }),
                      onHomeTyped:      (_) => _rateFromHome(),
                      onHomeOverrideClear: () => setState(() {
                        _homeOverride = false;
                        _homeAmountCtrl.clear();
                      }),
                    ),
                  ],
                  const SizedBox(height: kSpace4),

                  WabwayChoiceChips<ReceiptCategory>(
                    label: 'Category',
                    choices: [
                      for (final c in ReceiptCategory.values) WabwayChoice(c, c.label, icon: c.icon),
                    ],
                    selected: _category,
                    onChanged: (c) => setState(() => _category = c),
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

                  // Split method — shares are in the receipt's currency.
                  Text(
                    'Split method  ·  amounts in $_currency',
                    style: kStyleCaptionMedium.copyWith(color: kColorInk),
                  ),
                  const SizedBox(height: kSpace2),
                  _SplitToggle(
                    mode: _splitMode,
                    onChanged: (m) {
                      if (m == _SplitMode.items && (_items == null || _items!.isEmpty)) {
                        _photos.isNotEmpty ? _scan() : _editItems();
                        return;
                      }
                      setState(() => _splitMode = m);
                    },
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
                      members: widget.members,
                      controllers: _customCtrls,
                      currency: _currency,
                      total: double.tryParse(_amountCtrl.text.trim()) ?? 0,
                      onChanged: () => setState(() {}),
                    ),

                  if (_splitMode == _SplitMode.items && _items != null)
                    _ItemsSummary(
                      items: _items!,
                      members: widget.members,
                      currency: _currency,
                      canScan: _photos.isNotEmpty,
                      scanning: _scanning,
                      onEdit: () => _editItems(),
                      onRescan: _scan,
                    ),

                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Notes',
                    hint: 'Optional notes…',
                    controller: _notesCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),
                  const SizedBox(height: kSpace4),

                  _PhotoStrip(
                    photos:              _photos,
                    existingStoragePath: _existingStoragePath,
                    onPicked: (img) => setState(() => _photos.add(img)),
                    onRemoved: (i) => setState(() => _photos.removeAt(i)),
                    onRemoveExisting: () => setState(() => _existingStoragePath = null),
                  ),
                  if (_photos.isNotEmpty) ...[
                    const SizedBox(height: kSpace2),
                    _ScanItemsButton(
                      scanning:  _scanning,
                      hasResult: _items != null && !_items!.isEmpty,
                      photoCount: _photos.length,
                      onScan:    _scan,
                    ),
                  ],
                  const SizedBox(height: kSpace4),

                  if (!_isEditing && widget.tripId != null) ...[
                    _LinkSwitch(value: _createLink, onChanged: _setCreateLink),
                    const SizedBox(height: kSpace4),
                  ],

                  if (!_isEditing)
                    DocMultiPicker(
                      docs: _tripDocs,
                      selectedIds: _docIds,
                      onChanged: (id, checked) => setState(() =>
                          checked ? _docIds.add(id) : _docIds.remove(id)),
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
            label: widget.isDuplicate ? 'Save as new' : _isEditing ? 'Save changes' : 'Add receipt',
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
    required this.onHomeTyped,
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
  final ValueChanged<String> onHomeTyped;

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
              label: '$homeCurrency equivalent',
              hint: '0.00',
              helpText: 'What you were charged — the exchange rate above is worked out from it',
              controller: homeAmountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
              onChanged: onHomeTyped,
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

// ─── Photos ───────────────────────────────────────────────────────────────────

class _PhotoStrip extends StatelessWidget {
  const _PhotoStrip({
    required this.photos,
    required this.onPicked,
    required this.onRemoved,
    required this.onRemoveExisting,
    this.existingStoragePath,
  });

  final List<ScanImage> photos;
  final String? existingStoragePath;
  final ValueChanged<ScanImage> onPicked;
  final ValueChanged<int> onRemoved;
  final VoidCallback onRemoveExisting;

  Future<void> _pick(ImageSource source) async {
    final picker = ImagePicker();
    if (source == ImageSource.gallery) {
      final files = await picker.pickMultiImage(imageQuality: 85, maxWidth: 2048);
      for (final f in files) {
        onPicked(ScanImage(await f.readAsBytes(), _ext(f.name)));
      }
      return;
    }
    final file = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 2048);
    if (file == null) return;
    onPicked(ScanImage(await file.readAsBytes(), _ext(file.name)));
  }

  static String _ext(String name) =>
      name.contains('.') ? name.split('.').last.toLowerCase() : 'jpg';

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
              onTap: () { Navigator.pop(ctx); _pick(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Choose from gallery'),
              onTap: () { Navigator.pop(ctx); _pick(ImageSource.gallery); },
            ),
            if (existingStoragePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: kColorDanger),
                title: const Text('Remove attached photo', style: TextStyle(color: kColorDanger)),
                onTap: () { Navigator.pop(ctx); onRemoveExisting(); },
              ),
            const SizedBox(height: kSpace2),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final empty = photos.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(photos.length > 1 ? 'Photos · top to bottom' : 'Photo',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        if (empty)
          GestureDetector(
            onTap: () => _showSourcePicker(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: kSpace5),
              decoration: BoxDecoration(
                color: existingStoragePath != null ? kColorPrimarySoft : kColorSurfaceSunken,
                borderRadius: kRadiusMd,
                border: Border.all(
                    color: existingStoragePath != null ? kColorPrimary : kColorBorder),
              ),
              child: Column(
                children: [
                  Icon(
                    existingStoragePath != null
                        ? Icons.check_circle_outline_rounded
                        : Icons.add_photo_alternate_rounded,
                    size: 32,
                    color: existingStoragePath != null ? kColorPrimary : kColorInkSoft,
                  ),
                  const SizedBox(height: kSpace2),
                  Text(
                    existingStoragePath != null
                        ? 'Photo attached — tap to add more'
                        : 'Tap to add a photo',
                    style: kStyleBodyMedium.copyWith(
                        color: existingStoragePath != null ? kColorPrimary : kColorInkSoft),
                  ),
                  const SizedBox(height: kSpace1),
                  Text('Long receipt? Add several overlapping photos', style: kStyleCaption),
                ],
              ),
            ),
          )
        else
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photos.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: kSpace2),
              itemBuilder: (_, i) {
                if (i == photos.length) {
                  return GestureDetector(
                    onTap: () => _showSourcePicker(context),
                    child: Container(
                      width: 96,
                      decoration: BoxDecoration(
                        color: kColorSurfaceSunken,
                        borderRadius: kRadiusMd,
                        border: Border.all(color: kColorBorder),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_a_photo_rounded, color: kColorInkSoft),
                          const SizedBox(height: kSpace1),
                          Text('Add', style: kStyleCaption),
                        ],
                      ),
                    ),
                  );
                }
                return ClipRRect(
                  borderRadius: kRadiusMd,
                  child: Stack(
                    children: [
                      Image.memory(photos[i].bytes, width: 96, height: 128, fit: BoxFit.cover),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: kRadiusPill,
                          child: InkWell(
                            borderRadius: kRadiusPill,
                            onTap: () => onRemoved(i),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                      if (photos.length > 1)
                        Positioned(
                          left: 4,
                          bottom: 4,
                          child: WabwayBadge(label: '${i + 1}', tone: WabwayBadgeTone.neutral),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _LinkSwitch extends StatelessWidget {
  const _LinkSwitch({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: kColorPrimary,
        dense: true,
        secondary: const Icon(Icons.link_rounded, color: kColorInkSoft),
        title: Text('Share as a Receipts link', style: kStyleBodyMedium),
        subtitle: Text(
          'Anyone with the link can claim items and mark paid on receipts.wabble.ca. '
          'Made when you are online; you can also do it later.',
          style: kStyleCaption,
        ),
      ),
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
              label: switch (m) {
                _SplitMode.equal  => 'Equal',
                _SplitMode.custom => 'Custom',
                _SplitMode.items  => 'By item',
              },
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
              name: m.name, size: WabwayAvatarSize.sm),
          activeColor: kColorPrimary,
          contentPadding: EdgeInsets.zero,
          dense: true,
        );
      }).toList(),
    );
  }
}

class _CustomSplitPicker extends StatelessWidget {
  const _CustomSplitPicker({
    required this.members,
    required this.controllers,
    required this.currency,
    required this.total,
    required this.onChanged,
  });
  final List<TripMember> members;
  final Map<String, TextEditingController> controllers;
  final String currency;
  final double total;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final assigned = members.fold(
        0.0, (a, m) => a + (double.tryParse(controllers[m.id]?.text.trim() ?? '') ?? 0));
    final left = total - assigned;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...members.map((m) {
          return Padding(
            padding: const EdgeInsets.only(bottom: kSpace3),
            child: Row(
              children: [
                WabwayAvatar(
                    name: m.name, size: WabwayAvatarSize.sm),
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
                    onChanged: (_) => onChanged(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                  ),
                ),
              ],
            ),
          );
        }),
        if (total > 0)
          Text(
            left.abs() < 0.01
                ? 'All ${fmtAmount(total, currency)} assigned'
                : left > 0
                    ? '${fmtAmount(left, currency)} not assigned — the payer covers it'
                    : 'Assigned ${fmtAmount(-left, currency)} more than the total',
            style: kStyleCaption.copyWith(
                color: left.abs() < 0.01 ? kColorInkSoft : kColorWarning),
          ),
      ],
    );
  }
}

class _ItemsSummary extends StatelessWidget {
  const _ItemsSummary({
    required this.items,
    required this.members,
    required this.currency,
    required this.canScan,
    required this.scanning,
    required this.onEdit,
    required this.onRescan,
  });

  final ReceiptItemization items;
  final List<TripMember> members;
  final String currency;
  final bool canScan;
  final bool scanning;
  final VoidCallback onEdit;
  final VoidCallback onRescan;

  @override
  Widget build(BuildContext context) {
    final totals = items.personTotals(members.map((m) => m.id));
    final unclaimed = items.unclaimedTotal;
    return WabwayCard(
      padding: const EdgeInsets.all(kSpace3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${pluralize(items.items.length, 'item')} · ${fmtAmount(items.total, currency)}',
              style: kStyleBodySemibold),
          const SizedBox(height: kSpace2),
          for (final m in members)
            if ((totals[m.id] ?? 0) > 0.005)
              Padding(
                padding: const EdgeInsets.only(bottom: kSpace1),
                child: Row(
                  children: [
                    WabwayAvatar(name: m.name, size: WabwayAvatarSize.xs),
                    const SizedBox(width: kSpace2),
                    Expanded(child: Text(m.label, style: kStyleBody)),
                    Text(fmtAmount(totals[m.id]!, currency), style: kStyleBodyMedium),
                  ],
                ),
              ),
          if (unclaimed > 0.005)
            Padding(
              padding: const EdgeInsets.only(top: kSpace1),
              child: Text('${fmtAmount(unclaimed, currency)} not claimed — the payer covers it',
                  style: kStyleCaption.copyWith(color: kColorWarning)),
            ),
          const SizedBox(height: kSpace2),
          Wrap(
            spacing: kSpace2,
            children: [
              WabwayButton(
                label: 'Edit items & who had what',
                icon: Icons.edit_note_rounded,
                size: WabwayButtonSize.sm,
                variant: WabwayButtonVariant.secondary,
                onPressed: onEdit,
              ),
              if (canScan)
                WabwayButton(
                  label: 'Re-scan',
                  icon: Icons.document_scanner_rounded,
                  size: WabwayButtonSize.sm,
                  variant: WabwayButtonVariant.ghost,
                  loading: scanning,
                  onPressed: onRescan,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Scan items button ────────────────────────────────────────────────────────

class _ScanItemsButton extends StatelessWidget {
  const _ScanItemsButton({
    required this.scanning,
    required this.hasResult,
    required this.photoCount,
    required this.onScan,
  });
  final bool scanning;
  final bool hasResult;
  final int photoCount;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: scanning ? null : onScan,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpace3, vertical: kSpace2 + 2),
        decoration: BoxDecoration(
          color: kColorPrimarySoft,
          borderRadius: kRadiusMd,
          border: Border.all(color: kColorPrimary.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (scanning)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kColorPrimary),
              )
            else
              Icon(
                hasResult
                    ? Icons.edit_note_rounded
                    : Icons.document_scanner_rounded,
                size: 16,
                color: kColorPrimary,
              ),
            const SizedBox(width: kSpace2),
            Text(
              scanning
                  ? 'Scanning${photoCount > 1 ? ' $photoCount photos' : ''}… (up to a minute)'
                  : hasResult
                      ? 'Re-scan & re-split'
                      : 'Scan receipt & split by item',
              style: kStyleCaptionMedium.copyWith(color: kColorPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
