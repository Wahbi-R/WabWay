import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/async_screen_mixin.dart';
import '../../core/booking_merge.dart';
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
import '../../data/money_data.dart' show fmtAmount;
import '../../data/plan_data.dart';
import '../../data/travel_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import '../accommodations/add_accommodation_sheet.dart';
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
}

class _BookingReviewScreenState extends ConsumerState<BookingReviewScreen>
    with AsyncScreenMixin {
  late final List<_Row> _rows = [for (final b in widget.bookings) _Row(b)];
  List<TravelItem> _travel = [];
  List<Accommodation> _stays = [];
  List<TripDay> _days = [];
  bool _saving = false;

  /// The uploaded source file — kept so a retry after a failed save doesn't
  /// upload it twice.
  String? _docId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final gen = beginLoad();
    try {
      final results = await Future.wait<Object>([
        TravelService.loadItems(widget.tripId),
        AccommodationService.loadAll(widget.tripId),
        PlanService.loadAll(widget.tripId),
      ]);
      commitLoad(gen, () {
        _travel = results[0] as List<TravelItem>;
        _stays = results[1] as List<Accommodation>;
        _days = results[2] as List<TripDay>;
        for (final r in _rows) {
          _match(r);
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

  List<_Row> get _toSave =>
      _rows.where((r) => r.action != _Action.skip && r.savedId == null && _canSave(r)).toList();

  bool _canSave(_Row r) => r.booking is! ParsedPlan || r.booking.date != null;

  // ─── Edit (the entity's own Add sheet) ──────────────────────────────────────

  Future<void> _edit(_Row r) async {
    switch (r.booking) {
      case ParsedTravel(:final item, :final parsedBy):
        final draft = await showAddTravelSheet(context, prefillItem: item);
        if (draft == null || !mounted) return;
        setState(() {
          r.booking = ParsedTravel(draft, parsedBy: parsedBy);
          _match(r);
        });
      case ParsedStay(:final stay):
        final result = await showAddStaySheet(context,
            tripId: widget.tripId, userId: widget.userId, draft: stay);
        final saved = result?.accommodation;
        if (saved == null || !mounted) return;
        setState(() {
          r.booking = ParsedStay(saved, parsedBy: r.booking.parsedBy);
          r.savedId = saved.id; // the sheet saved it; Save only attaches the file
          r.action = _Action.add;
        });
      case ParsedPlan(:final item, :final day, :final parsedBy):
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
          r.booking = ParsedPlan(draft, day: date, parsedBy: parsedBy);
          _match(r);
        });
    }
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
    if (rows.isEmpty) {
      widget.onDone?.call();
      return;
    }
    setState(() => _saving = true);
    var added = 0, updated = 0;
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
      if (!mounted) return;
      showWabwaySnack(
          context,
          joinNonEmpty([
            if (added > 0) 'Added ${pluralize(added, 'booking')}',
            if (updated > 0) 'updated $updated',
          ], ', ').ifEmpty('Saved'));
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
  });

  final _Row row;
  final bool checkingDuplicates;
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
