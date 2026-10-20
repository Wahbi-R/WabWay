import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/async_screen_mixin.dart';
import '../../core/booking_merge.dart';
import '../../core/booking_receipt.dart';
import '../../core/pdf_pages.dart';
import '../../core/receipt_followups.dart';
import '../../core/receipt_scan_service.dart';
import '../../core/receipts_link_service.dart';
import '../../core/supabase/connection_service.dart';
import '../../core/supabase/exchange_rate_service.dart';
import '../../core/supabase/money_service.dart';
import '../../core/ocr/parsed_booking.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/accommodation_service.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/plan_service.dart';
import '../../core/supabase/travel_service.dart';
import '../../core/text_utils.dart';
import '../../data/accommodation_data.dart';
import '../../data/connection_data.dart' show EntityType;
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../data/share_data.dart' show ImportPrefill;
import '../../data/plan_data.dart';
import '../../data/travel_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import '../accommodations/add_accommodation_sheet.dart';
import '../money/add_receipt_sheet.dart';
import '../plan/add_item_sheet.dart';
import '../plan/day_picker_sheet.dart';
import '../travel/add_travel_sheet.dart';
import '../travel/travellers_section.dart';

/// Review what "Read booking" found, then save each booking where it belongs:
/// transport → Travel (optionally also the Plan day), stays → Stays,
/// tickets & reservations → that Plan day. Bookings already in the trip are
/// updated (empty fields filled, file attached) instead of duplicated.
/// "Edit" opens the entity's own Add sheet, pre-filled.
class BookingReviewScreen extends ConsumerStatefulWidget {
  const BookingReviewScreen({
    super.key,
    required this.bookings,
    required this.tripId,
    required this.userId,
    this.sourceBytes,
    this.sourceExt,
    this.sourceFileName,
    this.onDone,
  });

  final List<ParsedBooking> bookings;
  final String tripId;
  final String userId;

  /// The shared file, uploaded once to Docs and attached to everything saved.
  final Uint8List? sourceBytes;
  final String? sourceExt;
  final String? sourceFileName;
  final VoidCallback? onDone;

  @override
  ConsumerState<BookingReviewScreen> createState() => _BookingReviewScreenState();
}

enum _Action { add, update, skip }

class _Row {
  _Row(this.booking);

  ParsedBooking booking;

  /// The matching item already in the trip (TravelItem / Accommodation /
  /// ItineraryItem), if any.
  Object? existing;
  _Action action = _Action.add;

  /// Travel only: also put it on its Plan day.
  bool addToPlan = true;

  /// Set once saved (an Edit sheet that saves itself, or a partial Save).
  String? savedId;

  /// The receipt this booking's payment becomes in Money (null: not paid,
  /// or no price shown).
  BookingReceiptDraft? receipt;
  bool addReceipt = false;

  /// A receipt already in Money for this payment — linked instead.
  Receipt? existingReceipt;

  /// Receipt made from Edit receipt, or by a (partial) save.
  String? receiptId;
  bool receiptLinked = false;
}

class _BookingReviewScreenState extends ConsumerState<BookingReviewScreen>
    with AsyncScreenMixin {
  late final List<_Row> _rows = [for (final b in widget.bookings) _Row(b)];
  List<TravelItem> _travel = [];
  List<Accommodation> _stays = [];
  List<TripDay> _days = [];
  List<Receipt> _receipts = [];
  bool _saving = false;

  /// Receipts made here follow the Add receipt "Share as a Receipts link"
  /// choice.
  bool _createLink = true;

  /// The uploaded source file — kept so a retry after a failed save doesn't
  /// upload it twice.
  String? _docId;

  @override
  void initState() {
    super.initState();
    for (final r in _rows) {
      _matchReceipt(r);
    }
    _load();
    ReceiptsLinkService.defaultCreateLink().then((v) {
      if (v != null && mounted) setState(() => _createLink = v);
    });
  }

  Future<void> _load() async {
    final gen = beginLoad();
    try {
      final results = await Future.wait<Object>([
        TravelService.loadItems(widget.tripId),
        AccommodationService.loadAll(widget.tripId),
        PlanService.loadAll(widget.tripId),
        MoneyService.loadReceipts(widget.tripId).catchError((_) => <Receipt>[]),
      ]);
      commitLoad(gen, () {
        _travel = results[0] as List<TravelItem>;
        _stays = results[1] as List<Accommodation>;
        _days = results[2] as List<TripDay>;
        _receipts = results[3] as List<Receipt>;
        for (final r in _rows) {
          _match(r);
          _matchReceipt(r);
        }
      });
    } catch (_) {
      // Offline: still allow saving as new — duplicates just can't be spotted.
      failLoad(gen, silent: true);
      if (mounted) setState(() => loading = false);
    }
  }

  void _match(_Row r) {
    r.existing = findExistingBooking(r.booking, travel: _travel, stays: _stays, days: _days);
    r.action = r.existing == null
        ? _Action.add
        : r.booking is ParsedPlan ? _Action.skip : _Action.update;
  }

  List<String> get _memberIds => [
        for (final m in ref.read(tripMembersProvider)) m.userId,
        if (ref.read(tripMembersProvider).isEmpty) widget.userId,
      ];

  /// What the booking's receipt would be, and whether Money already has it.
  void _matchReceipt(_Row r) {
    if (r.receiptId != null) return;
    r.receipt = receiptForBooking(r.booking, payerId: widget.userId, memberIds: _memberIds);
    r.existingReceipt =
        r.receipt == null ? null : findExistingReceipt(r.receipt!, _receipts);
    r.addReceipt = r.receipt != null && r.existingReceipt == null;
  }

  List<_Row> get _toSave =>
      _rows.where((r) => r.action != _Action.skip && r.savedId == null && _canSave(r)).toList();

  bool _canSave(_Row r) => r.booking is! ParsedPlan || r.booking.date != null;

  // ─── Edit (the entity's own Add sheet) ──────────────────────────────────────

  Future<void> _edit(_Row r) async {
    switch (r.booking) {
      case ParsedTravel(:final item):
        final b = r.booking as ParsedTravel;
        final draft = await showAddTravelSheet(context, prefillItem: item);
        if (draft == null || !mounted) return;
        setState(() {
          r.booking = b.withItem(draft);
          _match(r);
          _matchReceipt(r); // travellers decide the split
        });
      case ParsedStay(:final stay):
        final result = await showAddStaySheet(context,
            tripId: widget.tripId, userId: widget.userId, draft: stay);
        final saved = result?.accommodation;
        if (saved == null || !mounted) return;
        setState(() {
          r.booking = (r.booking as ParsedStay).withStay(saved);
          r.savedId = saved.id; // the sheet saved it; Save only attaches the file
          r.action = _Action.add;
        });
      case ParsedPlan(:final item, :final day):
        var date = day;
        if (date == null || _dayOn(date) == null) {
          if (_days.isEmpty) {
            showWabwaySnack(context, 'Set your trip dates in Trip settings to start planning days.');
            return;
          }
          final picked = await showDayPickerSheet(context, days: _days);
          if (picked == null || !mounted) return;
          date = _days.firstWhere((d) => d.id == picked.$1).date;
        }
        final trip = ref.read(activeTripProvider);
        final draft = await showAddItemSheet(context,
            dayId: _dayOn(date)?.id ?? '',
            defaultCurrency: trip?.defaultCurrency ?? 'CAD',
            prefillItem: item);
        if (draft == null || !mounted) return;
        setState(() {
          r.booking = (r.booking as ParsedPlan).withItem(draft, day: date);
          _match(r);
        });
    }
  }

  // ─── Receipt ────────────────────────────────────────────────────────────────

  List<TripMember> get _tripMembers => [
        for (final m in ref.read(tripMembersProvider))
          TripMember(id: m.userId, name: m.profile.displayName, isMe: m.userId == widget.userId),
      ];

  /// Change payer / split / amount in the normal Add receipt sheet — it saves
  /// the receipt (and its Receipts link) itself; Save then links it.
  Future<void> _editReceipt(_Row r) async {
    final draft = r.receipt;
    if (draft == null) return;
    final trip = ref.read(activeTripProvider);
    String? docId;
    try {
      docId = _docId ??= await _uploadSource();
    } catch (_) {} // the receipt can still be made without the file
    if (!mounted) return;
    final saved = await showAddReceiptSheet(
      context,
      tripId: widget.tripId,
      userId: widget.userId,
      members: _tripMembers,
      homeCurrency: trip?.homeCurrency ?? 'CAD',
      defaultCurrency: draft.currency,
      prefill: ImportPrefill(
        title: draft.title,
        notes: draft.notes,
        amount: draft.amount,
        currency: draft.currency,
        linkedDocIds: [if (docId != null) docId],
      ),
    );
    if (saved == null || !mounted) return;
    setState(() {
      r.receiptId = saved.id;
      r.addReceipt = false;
    });
  }

  /// Pictures for the Receipts link: the booking's own PDF pages, or the
  /// shared photo.
  Future<List<ScanImage>> _linkPhotos(_Row r) async {
    final bytes = widget.sourceBytes;
    final ext = widget.sourceExt?.toLowerCase();
    if (bytes == null || ext == null) return const [];
    if (ext == 'pdf') return pdfPageImages(bytes, pages: r.booking.pages, maxPages: 3);
    final photo = ScanImage(bytes, ext);
    return photo.isScannable ? [photo] : const [];
  }

  /// Creates the receipt for a saved booking (exchange rate from the day's
  /// rate, file attached, Receipts link per the usual setting). Returns
  /// false when the exchange rate couldn't be fetched.
  Future<bool> _makeReceipt(_Row r, String? docId) async {
    final d = r.receipt!;
    final home = ref.read(activeTripProvider)?.homeCurrency ?? d.currency;
    final rate = await ExchangeRateService.fetch(d.currency, home);
    if (rate == null) return false;
    var receipt = await MoneyService.createReceipt(
      tripId: widget.tripId,
      paidBy: d.paidById,
      title: d.title,
      amount: d.amount,
      currency: d.currency,
      homeAmount: d.amount * rate,
      exchangeRate: rate,
      transactionFeePct: 0,
      category: d.category,
      date: DateTime.now(),
      splits: d.splits,
      notes: d.notes,
      items: d.items,
    );
    r.receiptId = receipt.id;
    receipt = (await runReceiptFollowups(
      tripId: widget.tripId,
      userId: widget.userId,
      receipt: receipt,
      members: _tripMembers,
      docIds: [if (docId != null) docId],
      createLink: _createLink,
      linkPhotos: _createLink ? await _linkPhotos(r) : const [],
    )).receipt;
    return true;
  }

  /// The booking and its receipt open each other (Connections).
  Future<void> _linkReceipt(_Row r, String receiptId) async {
    final (type, id) = switch (r.booking) {
      ParsedTravel() => (EntityType.travel, r.savedId!),
      ParsedStay() => (EntityType.stay, r.savedId!),
      ParsedPlan() => (EntityType.planItem, r.savedId!),
    };
    await ConnectionService.add(
      tripId: widget.tripId,
      userId: widget.userId,
      typeA: EntityType.receipt,
      idA: receiptId,
      typeB: type,
      idB: id,
    );
    r.receiptLinked = true;
  }

  // ─── Save ───────────────────────────────────────────────────────────────────

  TripDay? _dayOn(DateTime date) => _days
      .where((d) => d.date.year == date.year && d.date.month == date.month && d.date.day == date.day)
      .firstOrNull;

  /// The plan day for [date], created (like Plan → Add all trip days) if missing.
  Future<TripDay> _dayFor(DateTime date) async {
    final day = _dayOn(date);
    if (day != null) return day;
    final created = await PlanService.createMissingTripDays(
      tripId: widget.tripId,
      start: date,
      end: date,
      createdBy: widget.userId,
      existing: _days,
    );
    _days = [..._days, ...created];
    return _dayOn(date)!;
  }

  Future<String?> _uploadSource() async {
    final bytes = widget.sourceBytes;
    final ext = widget.sourceExt;
    if (bytes == null || ext == null) return null;
    final first = widget.bookings.firstOrNull;
    final doc = await DocService.uploadAndCreate(
      tripId: widget.tripId,
      userId: widget.userId,
      title: widget.sourceFileName?.replaceAll(RegExp(r'\.[^.]+$'), '') ??
          first?.title ??
          'Booking',
      type: switch (first) {
        ParsedTravel(:final item) when item.type == TravelItemType.flight => DocType.flight,
        ParsedTravel(:final item) when item.type == TravelItemType.train => DocType.train,
        ParsedTravel() => DocType.ticket,
        ParsedStay() => DocType.hotel,
        _ => DocType.reservation,
      },
      ext: ext.toLowerCase(),
      bytes: bytes,
      fileSizeKb: (bytes.length / 1024).round(),
    );
    return doc.id;
  }

  Future<void> _attach(String? docId, EntityType type, String entityId) async {
    if (docId == null) return;
    await DocService.attach(
      tripId: widget.tripId,
      userId: widget.userId,
      docIds: [docId],
      entityType: type,
      entityId: entityId,
    );
  }

  Future<void> _saveRow(_Row r, String? docId) async {
    switch (r.booking) {
      case ParsedTravel(:final item):
        if (r.action == _Action.update && r.existing is TravelItem) {
          final existing = r.existing as TravelItem;
          await TravelService.updateItem(mergeTravel(existing, item));
          await _attach(docId, EntityType.travel, existing.id);
          r.savedId = existing.id;
          return;
        }
        final created = await TravelService.createFromDraft(
          item.withDocIds([if (docId != null) docId]),
          tripId: widget.tripId,
          createdBy: widget.userId,
        );
        r.savedId = created.id;
        if (r.addToPlan && item.date != null) {
          final day = await _dayFor(item.date!);
          final planItem = await PlanService.createItem(
            tripId: widget.tripId,
            dayId: day.id,
            title: item.title,
            type: _planTypeFor(item.type),
            createdBy: widget.userId,
            time: item.time,
            linkedDocIds: [if (docId != null) docId],
            sortOrder: day.items.length,
          );
          await TravelService.linkToDay(created.id, dayId: day.id, itineraryItemId: planItem.id);
        }
      case ParsedStay(:final stay):
        if (r.savedId != null) {
          await _attach(docId, EntityType.stay, r.savedId!);
          return;
        }
        if (r.action == _Action.update && r.existing is Accommodation) {
          final existing = r.existing as Accommodation;
          await AccommodationService.update(mergeStay(existing, stay));
          await _attach(docId, EntityType.stay, existing.id);
          r.savedId = existing.id;
          return;
        }
        final created = await AccommodationService.createFromDraft(stay);
        await _attach(docId, EntityType.stay, created.id);
        r.savedId = created.id;
      case ParsedPlan(:final item, :final day):
        final planDay = await _dayFor(day!);
        final created = await PlanService.createItemFromDraft(
          item.copyWith(linkedDocIds: [if (docId != null) docId]),
          tripId: widget.tripId,
          dayId: planDay.id,
          createdBy: widget.userId,
          sortOrder: planDay.items.length,
        );
        r.savedId = created.id;
    }
  }

  static ItineraryItemType _planTypeFor(TravelItemType t) => switch (t) {
        TravelItemType.flight => ItineraryItemType.travel,
        TravelItemType.other  => ItineraryItemType.other,
        _                     => ItineraryItemType.transport,
      };

  Future<void> _save() async {
    // Rows an Edit sheet already saved still get the file attached.
    final rows = [
      ..._toSave,
      ..._rows.where((r) => r.savedId != null && r.booking is ParsedStay && r.action != _Action.skip),
    ];
    final receiptsOwed = _rows.any((r) =>
        r.action != _Action.skip && r.savedId != null && !r.receiptLinked &&
        (r.addReceipt || r.receiptId != null || r.existingReceipt != null));
    if (rows.isEmpty && !receiptsOwed) {
      widget.onDone?.call();
      return;
    }
    setState(() => _saving = true);
    var added = 0, updated = 0, receipts = 0, noRate = 0;
    try {
      final docId = _docId ??= await _uploadSource();
      for (final r in rows) {
        final wasUpdate = r.action == _Action.update;
        final wasSaved = r.savedId != null;
        await _saveRow(r, docId);
        if (wasUpdate) {
          updated++;
        } else if (!wasSaved) {
          added++;
        }
      }
      // Receipts after the bookings, so a retry finishes the ones still owed.
      for (final r in _rows) {
        if (r.action == _Action.skip || r.savedId == null || r.receiptLinked) continue;
        if (r.receiptId == null && r.addReceipt && r.receipt != null) {
          if (await _makeReceipt(r, docId)) {
            receipts++;
          } else {
            noRate++;
            continue;
          }
        }
        final receiptId = r.receiptId ?? (r.addReceipt ? null : r.existingReceipt?.id);
        if (receiptId != null) await _linkReceipt(r, receiptId);
      }
      if (!mounted) return;
      showWabwaySnack(
          context,
          joinNonEmpty([
            if (added > 0) 'Added ${pluralize(added, 'booking')}',
            if (updated > 0) 'updated $updated',
            if (receipts > 0) '${pluralize(receipts, 'receipt')} in Money',
            if (noRate > 0)
              "couldn't get today's exchange rate for ${pluralize(noRate, 'receipt')} — add it from Money",
          ], ', ').ifEmpty('Saved'),
          duration: Duration(seconds: noRate > 0 ? 6 : 3));
      widget.onDone?.call();
    } catch (_) {
      if (!mounted) return;
      // Saved rows keep their savedId, so retrying won't duplicate them.
      setState(() => _saving = false);
      showWabwaySnack(context, "Couldn't save everything — check your connection and try again.",
          error: true);
    }
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final count = _toSave.length;
    final ocr = widget.bookings.any((b) => !b.isAi);
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Review bookings', style: kStyleTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Cancel',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace2),
            child: Text(
              joinNonEmpty([
                'Found ${pluralize(widget.bookings.length, 'booking')}',
                if (widget.sourceBytes != null) 'the file is saved to Docs and attached',
                if (ocr) 'read on your phone (flights only), so check the details',
              ], ' · '),
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          ),
          if (loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(kSpace4),
              itemCount: _rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
              itemBuilder: (_, i) => _BookingCard(
                row: _rows[i],
                checkingDuplicates: loading,
                onAction: (a) => setState(() => _rows[i].action = a),
                onPlanToggle: (v) => setState(() => _rows[i].addToPlan = v),
                onEdit: () => _edit(_rows[i]),
                createLink: _createLink,
                onReceiptToggle: (v) => setState(() => _rows[i].addReceipt = v),
                onEditReceipt: () => _editReceipt(_rows[i]),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(kSpace4),
              child: WabwayButton(
                label: count == 0 ? 'Done' : 'Save ${pluralize(count, 'booking')}',
                fullWidth: true,
                size: WabwayButtonSize.lg,
                loading: _saving,
                onPressed: _saving || loading ? null : _save,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

// ─── Booking card ─────────────────────────────────────────────────────────────

class _BookingCard extends ConsumerWidget {
  const _BookingCard({
    required this.row,
    required this.checkingDuplicates,
    required this.onAction,
    required this.onPlanToggle,
    required this.onEdit,
    required this.createLink,
    required this.onReceiptToggle,
    required this.onEditReceipt,
  });

  final _Row row;
  final bool checkingDuplicates;
  final bool createLink;
  final ValueChanged<bool> onReceiptToggle;
  final VoidCallback onEditReceipt;
  final ValueChanged<_Action> onAction;
  final ValueChanged<bool> onPlanToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = row.booking;
    final (icon, color, kind) = switch (b) {
      ParsedTravel(:final item) => (item.type.icon, item.type.color, item.type.label),
      ParsedStay() => (Icons.hotel_rounded, const Color(0xFF8A6BAE), 'Stay'),
      ParsedPlan(:final item) => (Icons.confirmation_number_rounded, kColorPrimary, item.type.label),
    };
    final facts = _facts(b, ref);
    final existingTitle = switch (row.existing) {
      TravelItem(:final title) => title,
      Accommodation(:final name) => name,
      ItineraryItem(:final title) => title,
      _ => null,
    };
    final saved = row.savedId != null;

    return WabwayCard(
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12), borderRadius: kRadiusSm),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.title, style: kStyleBodySemibold, maxLines: 2, overflow: TextOverflow.ellipsis),
                    Text(kind, style: kStyleCaption.copyWith(color: kColorInkSoft)),
                  ],
                ),
              ),
              if (saved) const WabwayBadge(label: 'Saved', tone: WabwayBadgeTone.success),
            ],
          ),
          const SizedBox(height: kSpace3),
          for (final (icon, text) in facts)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 14, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Expanded(child: Text(text, style: kStyleCaption.copyWith(color: kColorInk))),
                ],
              ),
            ),
          if (b is ParsedPlan && b.day == null)
            Text('No date found — tap Edit to pick a day.',
                style: kStyleCaption.copyWith(color: kColorDanger)),
          if (b.originalLanguage != null)
            Padding(
              padding: const EdgeInsets.only(top: kSpace1),
              child: Text('Translated from ${b.originalLanguage}',
                  style: kStyleCaption.copyWith(color: kColorInkSoft, fontStyle: FontStyle.italic)),
            ),
          if (b.price case final price?) ...[
            const SizedBox(height: kSpace2),
            _PriceLine(price: price, people: b.passengerCount),
          ],
          if (row.action != _Action.skip && !row.receiptLinked)
            _ReceiptRow(
              row: row,
              createLink: createLink,
              onToggle: onReceiptToggle,
              onEdit: onEditReceipt,
            ),
          if (existingTitle != null && !saved) ...[
            const SizedBox(height: kSpace2),
            Text('Already in your trip: $existingTitle',
                style: kStyleCaption.copyWith(color: kColorPrimary, fontWeight: FontWeight.w600)),
          ],
          if (!saved) ...[
            const SizedBox(height: kSpace3),
            WabwayChoiceChips<_Action>(
              choices: [
                if (row.existing != null && b is! ParsedPlan)
                  const WabwayChoice(_Action.update, 'Update existing'),
                WabwayChoice(_Action.add, row.existing != null ? 'Add anyway' : 'Add'),
                const WabwayChoice(_Action.skip, 'Skip'),
              ],
              selected: row.action,
              onChanged: onAction,
            ),
          ],
          if (b is ParsedTravel && b.item.date != null && row.action == _Action.add && !saved)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text('Also add to the plan for ${fmtDate(b.item.date!)}', style: kStyleCaption),
              value: row.addToPlan,
              activeThumbColor: kColorPrimary,
              onChanged: onPlanToggle,
            ),
          if (!saved && !checkingDuplicates)
            Align(
              alignment: Alignment.centerLeft,
              child: WabwayButton(
                label: 'Edit details',
                icon: Icons.edit_rounded,
                variant: WabwayButtonVariant.ghost,
                size: WabwayButtonSize.sm,
                onPressed: onEdit,
              ),
            ),
        ],
      ),
    );
  }

  static List<(IconData, String)> _facts(ParsedBooking b, WidgetRef ref) {
    switch (b) {
      case ParsedTravel(:final item):
        final when = item.date == null
            ? null
            : joinNonEmpty([
                fmtDate(item.date!),
                joinNonEmpty([item.time, item.endTime], ' → '),
                if (item.endDate != null) 'arrives ${fmtDate(item.endDate!)}',
              ]);
        final who = travellersSummary(
            item.travellers, ref.watch(tripMembersProvider), ref.watch(profileProvider)?.id);
        final seats = item.travellers.map((t) => t.seat).nonNulls.join(', ');
        return [
          if (when != null) (Icons.schedule_rounded, when),
          if (item.location != null || item.destination != null)
            (Icons.route_rounded, joinNonEmpty([item.location, item.destination], ' → ')),
          if (item.departureTerminal != null || item.gate != null)
            (Icons.sensors_rounded, joinNonEmpty([item.departureTerminal, if (item.gate != null) 'Gate ${item.gate}'])),
          if (who != null) (Icons.people_alt_rounded, who),
          if (seats.isNotEmpty) (Icons.event_seat_rounded, seats),
          if (item.confirmationNumber != null)
            (Icons.confirmation_number_outlined, 'Ref ${item.confirmationNumber}'),
        ];
      case ParsedStay(:final stay):
        return [
          if (stay.checkIn != null)
            (
              Icons.date_range_rounded,
              joinNonEmpty([
                '${stay.checkInLabel} → ${stay.checkOutLabel ?? '?'}',
                if (stay.nights != null) pluralize(stay.nights!, 'night'),
              ]),
            ),
          if (stay.address != null || stay.city.isNotEmpty)
            (Icons.place_rounded, stay.address ?? stay.city),
          if (stay.pricePerNight != null)
            (Icons.payments_outlined, '${fmtAmount(stay.pricePerNight!, stay.currency)} / night'),
          if (stay.confirmationNumber != null)
            (Icons.confirmation_number_outlined, 'Ref ${stay.confirmationNumber}'),
        ];
      case ParsedPlan(:final item, :final day):
        return [
          if (day != null) (Icons.event_rounded, joinNonEmpty([fmtDate(day), item.time])),
          if (item.location != null) (Icons.place_rounded, item.location!),
          if (item.plannedCost != null)
            (Icons.payments_outlined, fmtAmount(item.plannedCost!, item.currency ?? '')),
        ];
    }
  }
}

// ─── Price and receipt ────────────────────────────────────────────────────────

class _PriceLine extends StatelessWidget {
  const _PriceLine({required this.price, this.people});

  final BookingPrice price;
  final int? people;

  @override
  Widget build(BuildContext context) {
    final p = price;
    final main = joinNonEmpty([
      switch (p.status) {
        PaidStatus.paid => 'Paid ${fmtAmount(p.total, p.currency)}',
        PaidStatus.due => '${fmtAmount(p.total, p.currency)} to pay',
        PaidStatus.partPaid =>
          'Paid ${fmtAmount(p.paidAmount, p.currency)} of ${fmtAmount(p.total, p.currency)}',
        PaidStatus.unknown => fmtAmount(p.total, p.currency),
      },
      if (people != null && people! > 1) '${fmtAmount(p.total / people!, p.currency)} each',
      if (p.amountDue != null && p.amountDue! > 0 && p.status != PaidStatus.due)
        '${fmtAmount(p.amountDue!, p.currency)} still due',
      p.points,
    ]);
    final warn = kStyleCaption.copyWith(color: kColorDanger, fontWeight: FontWeight.w600);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.payments_outlined, size: 14, color: kColorInkSoft),
            const SizedBox(width: kSpace2),
            Expanded(child: Text(main, style: kStyleCaption.copyWith(color: kColorInk))),
          ],
        ),
        for (final l in p.lines)
          Padding(
            padding: const EdgeInsets.only(left: 22, top: 2),
            child: Text(
              '${l.quantity != 1 ? '${l.quantity % 1 == 0 ? l.quantity.toInt() : l.quantity} × ' : ''}'
              '${l.label} · ${fmtAmount(l.amount, p.currency)}',
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          ),
        if (p.currencyGuessed)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Check the currency — the booking didn\'t say clearly (${p.currency}?)',
                style: warn),
          ),
        if (p.linesMismatch)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text("The price lines don't add up to the total — check before saving.",
                style: warn),
          ),
      ],
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({
    required this.row,
    required this.createLink,
    required this.onToggle,
    required this.onEdit,
  });

  final _Row row;
  final bool createLink;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    if (row.receiptId != null) {
      return Padding(
        padding: const EdgeInsets.only(top: kSpace2),
        child: Text('Receipt added to Money — it\'ll be linked to this booking.',
            style: kStyleCaption.copyWith(color: kColorSuccess, fontWeight: FontWeight.w600)),
      );
    }
    final d = row.receipt;
    if (d == null) return const SizedBox.shrink();
    final existing = row.existingReceipt;
    final people = d.splitWith.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          title: Text('Add receipt to Money', style: kStyleCaption.copyWith(color: kColorInk)),
          subtitle: Text(
            existing != null && !row.addReceipt
                ? 'Already in Money: ${existing.title} — it\'ll be linked instead'
                : joinNonEmpty([
                    fmtAmount(d.amount, d.currency),
                    'paid by you',
                    people == 1 ? 'just you' : 'split $people ways',
                    if (d.items != null) 'itemised',
                    if (createLink) 'Receipts link',
                  ]),
            style: kStyleCaption.copyWith(color: kColorInkSoft),
          ),
          value: row.addReceipt,
          activeThumbColor: kColorPrimary,
          onChanged: onToggle,
        ),
        if (row.addReceipt)
          Align(
            alignment: Alignment.centerLeft,
            child: WabwayButton(
              label: 'Change payer or split',
              icon: Icons.receipt_long_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: onEdit,
            ),
          ),
      ],
    );
  }
}
