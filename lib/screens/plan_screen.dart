import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/trip_provider.dart';
import '../core/trip/trip_state.dart';
import '../core/supabase/client.dart';
import '../core/supabase/accommodation_service.dart';
import '../core/supabase/connection_service.dart';
import '../core/supabase/plan_service.dart';
import '../core/supabase/spot_service.dart';
import '../core/supabase/doc_service.dart';
import '../data/accommodation_data.dart';
import '../data/connection_data.dart';
import '../data/money_data.dart' show fmtAmount;
import '../data/plan_data.dart';
import '../data/spot_data.dart';
import '../data/docs_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'plan/day_card.dart';
import 'plan/item_detail.dart';
import 'plan/add_item_sheet.dart';
import 'plan/day_picker_sheet.dart';

class PlanScreen extends ConsumerStatefulWidget {
  const PlanScreen({super.key});

  @override
  ConsumerState<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends ConsumerState<PlanScreen> {
  final List<TripDay> _days = [];
  final List<Spot> _spots = [];
  final List<TripDocument> _docs = [];
  final List<Accommodation> _stayItems = [];

  bool _loading = false;
  bool _offline = false;
  String? _error;
  String _activeTripId = '';
  String _userId = '';

  RealtimeChannel? _channel;
  Timer? _debounce;
  int _loadGen = 0;

  String? _selectedItemId;
  String? _selectedDayId;
  bool _unplannedExpanded = true;

  String _search = '';
  bool _hideCompleted = false;
  bool? _forceCollapsed;
  bool _showCalendar = false;
  DateTime _calFocus    = DateTime.now();
  DateTime? _calSelected;
  final _searchCtrl = TextEditingController();
  final _mobileListCtrl = ScrollController();

  ItineraryItem? get _selectedItem => itemById(_days, _selectedItemId ?? '');
  TripDay? get _selectedDay =>
      _selectedItem == null ? null : dayForItem(_days, _selectedItemId ?? '');

  // Returns a human-readable budget summary like "¥85,500 + $1,200" across all
  // plan items with a planned cost. Returns null if no costs are set.
  String? get _budgetSummary {
    final Map<String, double> totals = {};
    for (final day in _days) {
      for (final item in day.items) {
        if (item.plannedCost != null && item.plannedCost! > 0) {
          final c = item.currency ?? '';
          totals[c] = (totals[c] ?? 0) + item.plannedCost!;
        }
      }
    }
    if (totals.isEmpty) return null;
    return totals.entries.map((e) => fmtAmount(e.value, e.key)).join(' + ');
  }

  // Index of today's day in _days, or -1 if none.
  int get _todayDayIndex {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    return _days.indexWhere((d) {
      final k = DateTime(d.date.year, d.date.month, d.date.day);
      return k == todayKey;
    });
  }

  // Scrolls the mobile list to approximately today's day.
  // Uses estimated heights since ListView.builder items may not be rendered.
  void _scrollToToday() {
    final idx = _todayDayIndex;
    if (idx < 0 || !_mobileListCtrl.hasClients) return;

    double offset = 16.0; // ListView top padding
    if (_unplannedSpots.isNotEmpty) offset += 160.0; // rough unplanned section

    for (int i = 0; i < idx; i++) {
      final day = _days[i];
      offset += 60.0; // day card header
      offset += day.items.length * 56.0; // item tiles
      if (day.notes?.isNotEmpty == true) offset += 32.0; // notes row
      offset += 28.0; // card padding + spacing between cards
    }

    _mobileListCtrl.animateTo(
      offset.clamp(0.0, _mobileListCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  int get _completedCount =>
      _days.fold(0, (sum, d) => sum + d.items.where((i) => i.isDone).length);

  int get _totalItemCount =>
      _days.fold(0, (sum, d) => sum + d.items.length);

  List<Spot> get _unplannedSpots {
    final linkedIds = {
      for (final day in _days)
        for (final item in day.items)
          if (item.linkedSpotId != null) item.linkedSpotId!,
    };
    return _spots
        .where((s) =>
            (s.status == SpotStatus.confirmed ||
                s.status == SpotStatus.planned) &&
            !linkedIds.contains(s.id))
        .toList();
  }

  Map<String, TripDay> get _daysByDate {
    final m = <String, TripDay>{};
    for (final d in _days) {
      final k = '${d.date.year}-'
          '${d.date.month.toString().padLeft(2, '0')}-'
          '${d.date.day.toString().padLeft(2, '0')}';
      m[k] = d;
    }
    return m;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userId = supabase.auth.currentUser?.id ?? '';
      _activeTripId = ref.read(activeTripIdProvider);
      _loadAll();
      _subscribeRealtime(_activeTripId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _mobileListCtrl.dispose();
    _channel?.unsubscribe();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Search ───────────────────────────────────────────────────────────────────

  // Flatten all itinerary items across days and filter by the query.
  // Returns (item, day) pairs so search results can show day context.
  List<({ItineraryItem item, TripDay day})> get _planSearchResults {
    final q = _search.toLowerCase().trim();
    if (q.isEmpty) return const [];
    bool m(String? s) => s != null && s.toLowerCase().contains(q);
    final out = <({ItineraryItem item, TripDay day})>[];
    for (final day in _days) {
      for (final item in day.sortedItems) {
        if (m(item.title) || m(item.city) || m(item.location) || m(item.notes)) {
          out.add((item: item, day: day));
        }
      }
    }
    return out;
  }

  // ─── Data loading ─────────────────────────────────────────────────────────────

  // Loads all plan data. Pass silent:true for background refreshes triggered by
  // real-time CDC events — the loading spinner stays hidden to avoid a flash.
  Future<void> _loadAll({bool silent = false}) async {
    if (_activeTripId.isEmpty) return;
    final gen = ++_loadGen;
    if (!silent) setState(() { _loading = true; _error = null; _offline = false; _days.clear(); _spots.clear(); _docs.clear(); _stayItems.clear(); });

    if (!silent) {
      final cachedDaysFuture  = PlanService.loadFromCache(_activeTripId);
      final cachedSpotsFuture = SpotService.loadSpotsFromCache(_activeTripId);
      final cachedDocsFuture  = DocService.loadDocumentsFromCache(_activeTripId);
      final cachedStaysFuture = AccommodationService.loadFromCache(_activeTripId);
      final cachedDays  = await cachedDaysFuture;
      final cachedSpots = await cachedSpotsFuture;
      final cachedDocs  = await cachedDocsFuture;
      final cachedStays = await cachedStaysFuture;
      if (!mounted || gen != _loadGen) return;
      if (cachedDays != null) {
        setState(() {
          _days..clear()..addAll(cachedDays)..sort((a, b) => a.date.compareTo(b.date));
          _spots..clear()..addAll(cachedSpots ?? []);
          _docs..clear()..addAll(cachedDocs ?? []);
          _stayItems..clear()..addAll(cachedStays ?? []);
          _loading = false;
        });
      }
    }

    try {
      final daysFuture  = PlanService.loadAll(_activeTripId);
      final spotsFuture = SpotService.loadSpots(_activeTripId);
      final docsFuture  = DocService.loadDocuments(_activeTripId);
      final staysFuture = AccommodationService.loadAll(_activeTripId).catchError((_) => <Accommodation>[]);
      final days  = await daysFuture;
      final spots = await spotsFuture;
      final docs  = await docsFuture;
      final stays = await staysFuture;
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _days..clear()..addAll(days)..sort((a, b) => a.date.compareTo(b.date));
        _spots..clear()..addAll(spots);
        _docs..clear()..addAll(docs);
        _stayItems..clear()..addAll(stays);
        if (!silent) _loading = false;
        _offline = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      if (silent) { setState(() => _offline = true); return; }
      if (_days.isEmpty) {
        setState(() { _loading = false; _error = e.toString(); });
      } else {
        setState(() { _loading = false; _offline = true; });
      }
    }
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────────

  void _subscribeRealtime(String tripId) {
    _channel?.unsubscribe();
    _channel = supabase
        .channel('plan-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'itinerary_days',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => _debounceReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'itinerary_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => _debounceReload(),
        )
        .subscribe();
  }

  void _debounceReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _loadAll(silent: true));
  }

  // ─── UI actions ───────────────────────────────────────────────────────────────

  void _selectItem(String id) =>
      setState(() { _selectedItemId = id; _selectedDayId = null; });

  void _selectDay(String id) =>
      setState(() { _selectedDayId = id; _selectedItemId = null; });

  void _deleteItem(String itemId) {
    setState(() {
      for (final day in _days) {
        day.items.removeWhere((i) => i.id == itemId);
      }
      if (_selectedItemId == itemId) _selectedItemId = null;
    });
    PlanService.deleteItem(itemId).catchError((_) => _loadAll(silent: true));
  }

  void _updateItem(ItineraryItem updated) {
    // Detect spot connection changes before updating local state.
    String? oldSpotId;
    for (final day in _days) {
      final old = day.items.where((i) => i.id == updated.id).firstOrNull;
      if (old != null) { oldSpotId = old.linkedSpotId; break; }
    }

    setState(() {
      for (final day in _days) {
        final idx = day.items.indexWhere((i) => i.id == updated.id);
        if (idx != -1) {
          day.items[idx] = updated;
          break;
        }
      }
      _selectedItemId = updated.id;
    });
    PlanService.updateItem(updated).catchError((_) => _loadAll(silent: true));

    // Sync spot connection in trip_connections.
    final newSpotId = updated.linkedSpotId;
    if (oldSpotId != newSpotId) {
      if (oldSpotId != null) {
        ConnectionService.removeForEntityPair(updated.id, oldSpotId);
      }
      if (newSpotId != null) {
        ConnectionService.add(
          tripId: _activeTripId,
          userId: _userId,
          typeA:  EntityType.planItem,
          idA:    updated.id,
          typeB:  EntityType.spot,
          idB:    newSpotId,
        );
      }
    }
  }

  // Optimistically flips isDone and persists with a lightweight update.
  void _toggleItemDone(String itemId) {
    for (final day in _days) {
      final idx = day.items.indexWhere((i) => i.id == itemId);
      if (idx != -1) {
        final newDone = !day.items[idx].isDone;
        setState(() => day.items[idx] = day.items[idx].copyWith(isDone: newDone));
        PlanService.toggleDone(itemId, done: newDone)
            .catchError((_) => _loadAll(silent: true));
        return;
      }
    }
  }

  Future<void> _addItem(BuildContext context, String dayId) async {
    final messenger = ScaffoldMessenger.of(context);
    final draft = await showAddItemSheet(
      context,
      dayId: dayId,
      defaultCurrency: ref.read(activeTripProvider)?.homeCurrency ?? '',
      spots: _spots,
      docs: _docs,
      stays: _stayItems,
    );
    if (draft == null || !mounted) return;

    final day = _days.where((d) => d.id == dayId).firstOrNull;
    if (day == null) return;

    if (_activeTripId.isEmpty || _userId.isEmpty) {
      setState(() {
        day.items.add(draft);
        _selectedItemId = draft.id;
      });
      return;
    }

    try {
      final item = await PlanService.createItem(
        tripId:          _activeTripId,
        dayId:           dayId,
        title:           draft.title,
        type:            draft.type,
        createdBy:       _userId,
        time:            draft.time,
        city:            draft.city,
        country:         draft.country,
        location:        draft.location,
        mapsUrl:         draft.mapsUrl,
        confirmationUrl: draft.confirmationUrl,
        notes:           draft.notes,
        linkedDocIds:    draft.linkedDocIds,
        sortOrder:       day.items.length,
      );
      if (!mounted) return;
      // Write spot or stay connection to trip_connections if one was picked.
      if (draft.linkedSpotId != null) {
        await ConnectionService.add(
          tripId: _activeTripId,
          userId: _userId,
          typeA:  EntityType.planItem,
          idA:    item.id,
          typeB:  EntityType.spot,
          idB:    draft.linkedSpotId!,
        );
      } else if (draft.linkedStayId != null) {
        await ConnectionService.add(
          tripId: _activeTripId,
          userId: _userId,
          typeA:  EntityType.planItem,
          idA:    item.id,
          typeB:  EntityType.stay,
          idB:    draft.linkedStayId!,
        );
      }
      if (!mounted) return;
      setState(() {
        day.items.add(item.copyWith(linkedSpotId: draft.linkedSpotId, linkedStayId: draft.linkedStayId));
        _selectedItemId = item.id;
      });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Failed to add item: $e',
          style: kStyleBody.copyWith(color: Colors.white),
        ),
        backgroundColor: kColorDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _addItemForSpot(BuildContext context, Spot spot) async {
    if (_days.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Add a trip day first.', style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final result = await showDayPickerSheet(context, days: _days);
    if (result == null || !mounted) return;
    final (dayId, timeOfDay) = result;
    final day = _days.where((d) => d.id == dayId).firstOrNull;
    if (day == null) return;
    final itemType = _itemTypeForSpot(spot);
    final timeStr = timeOfDay != null
        ? '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}'
        : null;
    try {
      final item = await PlanService.createItem(
        tripId:       _activeTripId,
        dayId:        dayId,
        title:        spot.name,
        type:         itemType,
        createdBy:    _userId,
        time:         timeStr,
        city:         spot.city.isNotEmpty ? spot.city : spot.area,
        mapsUrl:      spot.mapsUrl,
        sortOrder:    day.items.length,
      );
      if (!mounted) return;
      await ConnectionService.add(
        tripId: _activeTripId,
        userId: _userId,
        typeA:  EntityType.planItem,
        idA:    item.id,
        typeB:  EntityType.spot,
        idB:    spot.id,
      );
      if (!mounted) return;
      setState(() {
        day.items.add(item.copyWith(linkedSpotId: spot.id));
        _selectedItemId = item.id;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to add item: $e', style: kStyleBody.copyWith(color: Colors.white)),
        backgroundColor: kColorDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  ItineraryItemType _itemTypeForSpot(Spot spot) => switch (spot.category) {
    SpotCategory.food      => ItineraryItemType.food,
    SpotCategory.nightlife => ItineraryItemType.activity,
    _                      => ItineraryItemType.spot,
  };

  int _dayDisplayNumber(TripDay day) => _days.indexOf(day) + 1;

  void _onEditDay(TripDay day) {
    _showEditDaySheet(context, day: day, displayNumber: _dayDisplayNumber(day), onSaved: (city, date, notes, clearNotes) {
      setState(() {
        final idx = _days.indexWhere((d) => d.id == day.id);
        if (idx != -1) {
          _days[idx] = TripDay(
            id: day.id,
            dayNumber: day.dayNumber,
            date: date ?? day.date,
            city: city ?? day.city,
            notes: clearNotes ? null : (notes ?? day.notes),
            items: _days[idx].items,
          );
        }
      });
      PlanService.updateDay(
        day.id, city: city, date: date, notes: notes, clearNotes: clearNotes,
      ).catchError((_) => _loadAll(silent: true));
    });
  }

  Future<void> _copyDay(TripDay day) async {
    final n = _dayDisplayNumber(day);
    final buf = StringBuffer();
    buf.writeln('Day $n – ${day.city}');
    final sorted = day.sortedItems;
    for (final item in sorted) {
      final prefix = item.hasTime ? '${item.time} ' : '';
      buf.writeln('• $prefix${item.title}');
    }
    await Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Day $n copied to clipboard'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteDay(TripDay day) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete day?'),
        content: Text(
          'Day ${_dayDisplayNumber(day)} (${day.city}) and all its itinerary items will be permanently deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _days.removeWhere((d) => d.id == day.id));
    PlanService.writeDaysToCache(_activeTripId, _days);
    PlanService.deleteDay(day.id).catchError((_) => _loadAll(silent: true));
  }

  void _onMoveItem(ItineraryItem item, String newDayId) {
    final fromDay = _days.where((d) => d.id == item.dayId).firstOrNull;
    final toDay   = _days.where((d) => d.id == newDayId).firstOrNull;
    if (fromDay == null || toDay == null) return;
    final moved = ItineraryItem(
      id: item.id, dayId: newDayId, title: item.title, type: item.type,
      time: item.time, city: item.city, location: item.location,
      mapsUrl: item.mapsUrl, confirmationUrl: item.confirmationUrl,
      notes: item.notes, linkedSpotId: item.linkedSpotId,
      linkedDocIds: item.linkedDocIds,
    );
    setState(() {
      fromDay.items.removeWhere((i) => i.id == item.id);
      toDay.items.add(moved);
      _selectedItemId = item.id;
    });
    PlanService.moveItem(item.id, newDayId).catchError((_) => _loadAll(silent: true));
  }

  void _onReorderItems(String dayId, List<ItineraryItem> newOrder) {
    final day = _days.where((d) => d.id == dayId).firstOrNull;
    if (day == null) return;
    setState(() {
      day.items
        ..clear()
        ..addAll(newOrder);
    });
    PlanService.reorderItemsInDay(newOrder).catchError((_) => _loadAll(silent: true));
  }

  Future<void> _onDuplicateItem(ItineraryItem item) async {
    if (_userId.isEmpty) return;
    try {
      final copy = await PlanService.duplicateItem(item, createdBy: _userId);
      if (!mounted) return;
      final day = _days.where((d) => d.id == copy.dayId).firstOrNull;
      if (day == null) return;
      setState(() => day.items.add(copy));
    } catch (_) {}
  }

  Future<void> _addDay(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    // Default to day after the latest existing day, or the trip start date, or today.
    DateTime defaultDate;
    if (_days.isNotEmpty) {
      final latest = _days.map((d) => d.date).reduce((a, b) => a.isAfter(b) ? a : b);
      defaultDate = latest.add(const Duration(days: 1));
    } else {
      defaultDate = TripState.maybeOf(context)?.trip.startDate ?? DateTime.now();
    }
    final draft = await _showAddDayDialog(context, defaultDate: defaultDate);
    if (draft == null || !mounted) return;
    if (_activeTripId.isEmpty || _userId.isEmpty) return;

    try {
      final day = await PlanService.createDay(
        tripId:    _activeTripId,
        dayNumber: _days.isEmpty ? 1 : _days.map((d) => d.dayNumber).reduce((a, b) => a > b ? a : b) + 1,
        date:      draft.date,
        city:      draft.city,
        createdBy: _userId,
        notes:     draft.notes,
      );
      if (!mounted) return;
      setState(() { _days.add(day); _days.sort((a, b) => a.date.compareTo(b.date)); });
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Failed to add day: $e',
          style: kStyleBody.copyWith(color: Colors.white),
        ),
        backgroundColor: kColorDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _addAllTripDays(BuildContext context) async {
    final trip = TripState.maybeOf(context)?.trip;
    if (trip == null || trip.startDate == null || trip.endDate == null) return;
    final messenger = ScaffoldMessenger.of(context);

    // Collect dates already covered by existing days (date-only comparison).
    final existingDates = _days
        .map((d) => DateTime(d.date.year, d.date.month, d.date.day))
        .toSet();

    // Enumerate every date in the trip range that is not yet covered.
    final missingDates = <DateTime>[];
    var current = DateTime(trip.startDate!.year, trip.startDate!.month, trip.startDate!.day);
    final tripEnd  = DateTime(trip.endDate!.year,  trip.endDate!.month,  trip.endDate!.day);
    while (!current.isAfter(tripEnd)) {
      if (!existingDates.contains(current)) missingDates.add(current);
      current = current.add(const Duration(days: 1));
    }

    if (missingDates.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('All trip days are already added.')));
      return;
    }
    if (_activeTripId.isEmpty || _userId.isEmpty) return;

    setState(() => _loading = true);
    int nextDayNumber = _days.isEmpty ? 0 : _days.map((d) => d.dayNumber).reduce((a, b) => a > b ? a : b);
    final newDays = <TripDay>[];
    try {
      for (final date in missingDates) {
        nextDayNumber++;
        final day = await PlanService.createDay(
          tripId:    _activeTripId,
          dayNumber: nextDayNumber,
          date:      date,
          city:      '',
          createdBy: _userId,
          notes:     null,
        );
        newDays.add(day);
      }
      if (!mounted) return;
      setState(() {
        _days.addAll(newDays);
        _days.sort((a, b) => a.date.compareTo(b.date));
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      messenger.showSnackBar(SnackBar(
        content: Text('Failed to add days: $e', style: kStyleBody.copyWith(color: Colors.white)),
        backgroundColor: kColorDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _exportPlan() {
    if (_days.isEmpty) return;
    final buf = StringBuffer();
    final tripName = ref.read(activeTripProvider)?.name ?? 'Trip';
    buf.writeln('$tripName — Itinerary');
    buf.writeln('=' * 40);
    for (var di = 0; di < _days.length; di++) {
      final day = _days[di];
      buf.writeln('\nDay ${di + 1} · ${day.city} · ${fmtDate(day.date)}');
      if (day.notes != null && day.notes!.isNotEmpty) {
        buf.writeln('  Note: ${day.notes}');
      }
      final items = day.sortedItems;
      if (items.isEmpty) {
        buf.writeln('  (no items)');
      } else {
        for (final item in items) {
          final time = item.time != null ? '[${item.time}] ' : '';
          buf.write('  • $time${item.title}');
          if (item.location != null && item.location!.isNotEmpty) {
            buf.write(' @ ${item.location}');
          }
          buf.writeln();
          if (item.notes != null && item.notes!.isNotEmpty) {
            buf.writeln('    ${item.notes}');
          }
        }
      }
    }
    final text = buf.toString().trim();
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export is not supported on web.',
            style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    unawaited(Share.share(text, subject: '$tripName — Itinerary'));
  }

  Future<void> _exportToCalendar() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Calendar export is not supported on web.',
            style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_days.isEmpty) return;
    final tripName = ref.read(activeTripProvider)?.name ?? 'Trip';

    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//WabWay//EN');
    buf.writeln('CALSCALE:GREGORIAN');
    buf.writeln('METHOD:PUBLISH');

    String icsDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

    String icsDateTime(DateTime d, String? timeStr) {
      if (timeStr == null) return icsDate(d);
      final parts = timeStr.split(':');
      if (parts.length < 2) return icsDate(d);
      return '${icsDate(d)}T${parts[0].padLeft(2, '0')}${parts[1].padLeft(2, '0')}00';
    }

    for (final day in _days) {
      for (final item in day.sortedItems) {
        buf.writeln('BEGIN:VEVENT');
        buf.writeln('UID:wabway-${item.id}@wabway.app');
        buf.writeln('SUMMARY:${item.title.replaceAll(',', '\\,')}');
        if (item.time != null) {
          buf.writeln('DTSTART:${icsDateTime(day.date, item.time)}');
          buf.writeln('DTEND:${icsDateTime(day.date, item.time)}');
        } else {
          buf.writeln('DTSTART;VALUE=DATE:${icsDate(day.date)}');
          buf.writeln('DTEND;VALUE=DATE:${icsDate(day.date)}');
        }
        if (item.location != null && item.location!.isNotEmpty) {
          buf.writeln('LOCATION:${item.location!.replaceAll(',', '\\,')}');
        }
        if (item.notes != null && item.notes!.isNotEmpty) {
          buf.writeln('DESCRIPTION:${item.notes!.replaceAll('\n', '\\n').replaceAll(',', '\\,')}');
        }
        buf.writeln('END:VEVENT');
      }
    }
    buf.writeln('END:VCALENDAR');

    try {
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/wabway_itinerary.ics');
      await file.writeAsString(buf.toString());
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/calendar')],
        subject: '$tripName — Calendar',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not export calendar.',
              style: kStyleBody.copyWith(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _activeTripId) {
        _activeTripId = next;
        _loadAll();
        _subscribeRealtime(next);
      }
    });
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final base = isDesktop ? _buildDesktop(context) : _buildMobile(context);
    if (!_offline) return base;
    return Stack(
      children: [
        base,
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: OfflineBanner(onRetry: () => _loadAll(silent: true)),
        ),
      ],
    );
  }

  // ─── Desktop ──────────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Column(
        children: [
          _DesktopPlanBar(
            dayCount: _days.length,
            onAddDay: () => _addDay(context),
            onAddAllDays: () => _addAllTripDays(context),
            showAddAllDays: () { final t = TripState.maybeOf(context)?.trip; return t?.startDate != null && t?.endDate != null; }(),
            onExport: _days.isNotEmpty ? _exportPlan : null,
            onExportCalendar: (_days.isNotEmpty && !kIsWeb) ? _exportToCalendar : null,
            hideCompleted: _hideCompleted,
            onToggleHideCompleted: (_hideCompleted || _completedCount > 0)
                ? () => setState(() => _hideCompleted = !_hideCompleted)
                : null,
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: WabwayEmptyState(
                          icon: Icons.error_outline_rounded,
                          title: 'Could not load plan',
                          description: _error!,
                        ),
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 420,
                            child: (_days.isEmpty && _unplannedSpots.isEmpty)
                                ? _buildEmptyTimeline(context)
                                : Column(
                                    children: [
                                      WabwaySearchBar(
                                        controller: _searchCtrl,
                                        hint: 'Search plan items…',
                                        onChanged: (v) => setState(() => _search = v),
                                      ),
                                      if (_search.isEmpty && _budgetSummary != null)
                                        _PlanBudgetBar(summary: _budgetSummary!),
                                      if (_search.isEmpty && _totalItemCount > 0)
                                        _PlanProgressBar(
                                          done: _completedCount,
                                          total: _totalItemCount,
                                        ),
                                      Expanded(
                                        child: _search.isNotEmpty
                                            ? _buildDesktopSearchResults()
                                            : ListView.builder(
                                                padding: const EdgeInsets.all(kSpace4),
                                                itemCount: _days.length +
                                                    (_unplannedSpots.isNotEmpty ? 1 : 0),
                                                itemBuilder: (ctx, i) {
                                                  if (_unplannedSpots.isNotEmpty && i == 0) {
                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: kSpace3),
                                                      child: _UnplannedSpotsSection(
                                                        spots: _unplannedSpots,
                                                        expanded: _unplannedExpanded,
                                                        onToggle: () => setState(() =>
                                                            _unplannedExpanded = !_unplannedExpanded),
                                                        onSpotTap: (spot) =>
                                                            _addItemForSpot(context, spot),
                                                      ),
                                                    );
                                                  }
                                                  final di = i - (_unplannedSpots.isNotEmpty ? 1 : 0);
                                                  return Padding(
                                                    padding: EdgeInsets.only(
                                                        bottom: di < _days.length - 1 ? kSpace3 : 0),
                                                    child: TripDayCard(
                                                      day: _days[di],
                                                      displayNumber: di + 1,
                                                      selectedItemId: _selectedItemId,
                                                      onItemTap: _selectItem,
                                                      onAddItem: () =>
                                                          _addItem(context, _days[di].id),
                                                      isDesktop: true,
                                                      onDayTap: () => _selectDay(_days[di].id),
                                                      daySelected: _selectedDayId == _days[di].id,
                                                      onEditDay: () => _onEditDay(_days[di]),
                                                      onDeleteDay: () => _deleteDay(_days[di]),
                                                      onCopyDay: () => _copyDay(_days[di]),
                                                      onReorder: (newOrder) =>
                                                          _onReorderItems(_days[di].id, newOrder),
                                                      onToggleDone: _toggleItemDone,
                                                      hideCompleted: _hideCompleted,
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    ],
                                  ),
                          ),
                          const VerticalDivider(
                              width: 1, thickness: 1, color: kColorBorder),
                          Expanded(child: _buildDesktopDetail()),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopDetail() {
    final item = _selectedItem;
    final day  = _selectedDay;

    if (item != null && day != null) {
      return SingleChildScrollView(
        child: ItemDetailContent(
          key: ValueKey(item.id),
          item: item,
          day: day,
          spots: _spots,
          docs: _docs,
          days: _days,
          onDelete: () => _deleteItem(item.id),
          onUpdated: _updateItem,
          onMove: (newDayId) => _onMoveItem(item, newDayId),
          onDuplicate: () => _onDuplicateItem(item),
        ),
      );
    }

    if (_selectedDayId != null) {
      final selectedDay =
          _days.where((d) => d.id == _selectedDayId).firstOrNull;
      if (selectedDay != null) {
        return SingleChildScrollView(
          child: _DayDetailPanel(
            key: ValueKey(selectedDay.id),
            day: selectedDay,
            displayNumber: _dayDisplayNumber(selectedDay),
            onAddItem: () => _addItem(context, selectedDay.id),
          ),
        );
      }
    }

    return const Center(
      child: WabwayEmptyState(
        icon: Icons.event_note_rounded,
        title: 'Select an item',
        description:
            'Click a day header to see its details, or tap an item for more info.',
      ),
    );
  }

  Widget _buildEmptyTimeline(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WabwayEmptyState(
            icon: Icons.calendar_today_rounded,
            title: 'No days yet',
            description: 'Add your first trip day to get started.',
          ),
          const SizedBox(height: kSpace4),
          WabwayButton(
            label: 'Add Day',
            icon: Icons.add_rounded,
            onPressed: () => _addDay(context),
          ),
        ],
      ),
    );
  }

  // ─── Mobile ───────────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Plan', style: kStyleTitle),
        actions: [
          IconButton(
            icon: Icon(
              _showCalendar ? Icons.list_rounded : Icons.calendar_view_month_rounded,
              size: 20,
            ),
            tooltip: _showCalendar ? 'List view' : 'Calendar view',
            color: _showCalendar ? kColorPrimary : kColorInkSoft,
            onPressed: () => setState(() => _showCalendar = !_showCalendar),
          ),
          if (_todayDayIndex >= 0 && _search.isEmpty && !_showCalendar)
            IconButton(
              icon: const Icon(Icons.today_rounded, size: 20),
              tooltip: 'Jump to today',
              color: kColorPrimary,
              onPressed: _scrollToToday,
            ),
          if (!_showCalendar) ...[
            if ((_hideCompleted || _completedCount > 0) && _search.isEmpty)
              IconButton(
                icon: Icon(
                  _hideCompleted
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                tooltip: _hideCompleted ? 'Show completed' : 'Hide completed',
                color: _hideCompleted ? kColorPrimary : kColorInkSoft,
                onPressed: () => setState(() => _hideCompleted = !_hideCompleted),
              ),
            if (_days.length >= 2 && _search.isEmpty)
              IconButton(
                icon: Icon(
                  _forceCollapsed == true
                      ? Icons.unfold_more_rounded
                      : Icons.unfold_less_rounded,
                  size: 20,
                ),
                tooltip: _forceCollapsed == true ? 'Expand all days' : 'Collapse all days',
                color: _forceCollapsed == true ? kColorPrimary : kColorInkSoft,
                onPressed: () => setState(() =>
                    _forceCollapsed = _forceCollapsed == true ? false : true),
              ),
            if (_days.isNotEmpty) ...[
              IconButton(
                icon: const Icon(Icons.ios_share_rounded, size: 20),
                tooltip: 'Export plan',
                color: kColorInkSoft,
                onPressed: _exportPlan,
              ),
              if (!kIsWeb)
                IconButton(
                  icon: const Icon(Icons.calendar_month_rounded, size: 20),
                  tooltip: 'Export to calendar (.ics)',
                  color: kColorInkSoft,
                  onPressed: _exportToCalendar,
                ),
            ],
          ],
          if (() { final t = TripState.maybeOf(context)?.trip; return t?.startDate != null && t?.endDate != null; }())
            TextButton.icon(
              onPressed: () => _addAllTripDays(context),
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: Text('All days', style: kStyleCaptionMedium),
              style: TextButton.styleFrom(foregroundColor: kColorInkSoft),
            ),
          TextButton.icon(
            onPressed: () => _addDay(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Day', style: kStyleCaptionMedium),
            style: TextButton.styleFrom(foregroundColor: kColorInkSoft),
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: _loading
          ? const WabwayLoadingIndicator()
          : _error != null
              ? Center(
                  child: WabwayEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load plan',
                    description: _error!,
                  ),
                )
              : _showCalendar
                  ? _buildMobileCalendar(context)
              : (_days.isEmpty && _unplannedSpots.isEmpty)
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const WabwayEmptyState(
                            icon: Icons.calendar_today_rounded,
                            title: 'No days yet',
                            description:
                                'Add your first trip day to start planning.',
                          ),
                          const SizedBox(height: kSpace4),
                          WabwayButton(
                            label: 'Add Day',
                            icon: Icons.add_rounded,
                            onPressed: () => _addDay(context),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        WabwaySearchBar(
                          controller: _searchCtrl,
                          hint: 'Search plan items…',
                          onChanged: (v) => setState(() => _search = v),
                        ),
                        if (_search.isEmpty && _budgetSummary != null)
                          _PlanBudgetBar(summary: _budgetSummary!),
                        if (_search.isEmpty && _totalItemCount > 0)
                          _PlanProgressBar(
                            done: _completedCount,
                            total: _totalItemCount,
                          ),
                        Expanded(
                          child: _search.isNotEmpty
                              ? _buildMobileSearchResults(context)
                              : ListView.builder(
                                  controller: _mobileListCtrl,
                                  padding: const EdgeInsets.all(kSpace4),
                                  itemCount: _days.length +
                                      (_unplannedSpots.isNotEmpty ? 1 : 0),
                                  itemBuilder: (ctx, i) {
                                    if (_unplannedSpots.isNotEmpty && i == 0) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: kSpace3),
                                        child: _UnplannedSpotsSection(
                                          spots: _unplannedSpots,
                                          expanded: _unplannedExpanded,
                                          onToggle: () => setState(
                                              () => _unplannedExpanded = !_unplannedExpanded),
                                          onSpotTap: (spot) =>
                                              _addItemForSpot(context, spot),
                                        ),
                                      );
                                    }
                                    final di = i - (_unplannedSpots.isNotEmpty ? 1 : 0);
                                    return Padding(
                                      padding: EdgeInsets.only(
                                          bottom: di < _days.length - 1 ? kSpace3 : 0),
                                      child: TripDayCard(
                                        day: _days[di],
                                        displayNumber: di + 1,
                                        onItemTap: (id) {
                                          final item = itemById(_days, id);
                                          final day  = dayForItem(_days, id);
                                          if (item != null && day != null) {
                                            final spots = _spots;
                                            final docs  = _docs;
                                            final days  = List<TripDay>.from(_days);
                                            Navigator.push(
                                              ctx,
                                              MaterialPageRoute(
                                                builder: (_) => ItemDetailScreen(
                                                  item: item,
                                                  day: day,
                                                  spots: spots,
                                                  docs: docs,
                                                  days: days,
                                                  onDelete: () => _deleteItem(id),
                                                  onUpdated: _updateItem,
                                                  onMove: (newDayId) =>
                                                      _onMoveItem(item, newDayId),
                                                  onDuplicate: () => _onDuplicateItem(item),
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        onAddItem: () => _addItem(context, _days[di].id),
                                        onEditDay: () => _onEditDay(_days[di]),
                                        onDeleteDay: () => _deleteDay(_days[di]),
                                        onCopyDay: () => _copyDay(_days[di]),
                                        onReorder: (newOrder) =>
                                            _onReorderItems(_days[di].id, newOrder),
                                        onToggleDone: _toggleItemDone,
                                        hideCompleted: _hideCompleted,
                                        forceCollapsed: _forceCollapsed,
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'plan_fab',
        onPressed: () async {
          if (_days.isEmpty) {
            _addDay(context);
          } else if (_days.length == 1) {
            _addItem(context, _days.first.id);
          } else {
            final result = await showDayPickerSheet(context, days: _days);
            if (result == null || !mounted) return;
            final (dayId, _) = result;
            _addItem(context, dayId);
          }
        },
        icon: const Icon(Icons.event_note_rounded),
        label: Text(
          'Add item',
          style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
        ),
      ),
    );
  }

  // ─── Calendar view (mobile) ───────────────────────────────────────────────────

  Widget _buildMobileCalendar(BuildContext context) {
    if (_days.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WabwayEmptyState(
              icon: Icons.calendar_today_rounded,
              title: 'No days yet',
              description: 'Add your first trip day to start planning.',
            ),
            const SizedBox(height: kSpace4),
            WabwayButton(
              label: 'Add Day',
              icon: Icons.add_rounded,
              onPressed: () => _addDay(context),
            ),
          ],
        ),
      );
    }

    final daysMap   = _daysByDate;
    final selKey    = _calSelected == null
        ? null
        : '${_calSelected!.year}-'
          '${_calSelected!.month.toString().padLeft(2, '0')}-'
          '${_calSelected!.day.toString().padLeft(2, '0')}';
    final selDay    = selKey != null ? daysMap[selKey] : null;
    final today     = DateTime.now();

    return Column(
      children: [
        // Month navigator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                color: kColorInkSoft,
                onPressed: () => setState(() => _calFocus = DateTime(
                    _calFocus.year, _calFocus.month - 1, 1)),
              ),
              Expanded(
                child: Text(
                  _monthLabel(_calFocus),
                  style: kStyleBodyBold,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                color: kColorInkSoft,
                onPressed: () => setState(() => _calFocus = DateTime(
                    _calFocus.year, _calFocus.month + 1, 1)),
              ),
            ],
          ),
        ),
        // Calendar grid
        _CalendarGrid(
          focus: _calFocus,
          daysMap: daysMap,
          selected: _calSelected,
          today: today,
          onSelect: (d) => setState(() => _calSelected = d),
        ),
        const Divider(height: 1, color: kColorBorder),
        // Selected day items
        Expanded(
          child: selDay != null
              ? _buildCalendarDayItems(context, selDay)
              : selKey != null
                  ? _buildCalendarDayEmpty(context)
                  : const Center(
                      child: WabwayEmptyState(
                        icon: Icons.touch_app_rounded,
                        title: 'Tap a date',
                        description: 'Select a date to see its planned items.',
                      ),
                    ),
        ),
      ],
    );
  }

  String _monthLabel(DateTime d) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  Widget _buildCalendarDayItems(BuildContext context, TripDay day) {
    final items = day.sortedItems
        .where((i) => !(_hideCompleted && i.isDone))
        .toList();

    return RefreshIndicator(
      onRefresh: () => _loadAll(silent: true),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          kSpace4, kSpace3, kSpace4,
          kSpace6 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Row(
            children: [
              Text(
                'Day ${_dayDisplayNumber(day)} · ${day.city}',
                style: kStyleBodyBold,
              ),
              const SizedBox(width: kSpace2),
              Text(fmtDate(day.date),
                  style: kStyleCaption.copyWith(color: kColorInkSoft)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _addItem(context, day.id),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text('Add', style: kStyleCaptionMedium),
                style: TextButton.styleFrom(
                  foregroundColor: kColorPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: kSpace2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          if (day.notes != null && day.notes!.isNotEmpty) ...[
            const SizedBox(height: kSpace2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
              decoration: BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusMd,
                border: Border.all(color: kColorBorder),
              ),
              child: Text(day.notes!,
                  style: kStyleCaption.copyWith(color: kColorInkSoft)),
            ),
          ],
          const SizedBox(height: kSpace3),
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: kSpace6),
                child: Text(
                  'No items for this day yet',
                  style: kStyleCaption.copyWith(color: kColorInkSoft),
                ),
              ),
            )
          else
            ...items.map((item) => _CalendarItemTile(
                  item: item,
                  onTap: () {
                    final days  = List<TripDay>.from(_days);
                    final spots = _spots;
                    final docs  = _docs;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ItemDetailScreen(
                          item: item,
                          day: day,
                          spots: spots,
                          docs: docs,
                          days: days,
                          onDelete: () => _deleteItem(item.id),
                          onUpdated: _updateItem,
                          onMove: (newDayId) => _onMoveItem(item, newDayId),
                          onDuplicate: () => _onDuplicateItem(item),
                        ),
                      ),
                    );
                  },
                  onToggleDone: () => _toggleItemDone(item.id),
                )),
        ],
      ),
    );
  }

  Widget _buildCalendarDayEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WabwayEmptyState(
            icon: Icons.event_available_rounded,
            title: 'No plan for this date',
            description: 'Add a day for ${_calSelected == null ? 'this date' : fmtDate(_calSelected!)} to start planning.',
          ),
          const SizedBox(height: kSpace4),
          WabwayButton(
            label: 'Add Day',
            icon: Icons.add_rounded,
            variant: WabwayButtonVariant.ghost,
            onPressed: () => _addDay(context),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSearchResults() {
    final results = _planSearchResults;
    if (results.isEmpty) {
      return Center(
        child: WabwayEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results for "$_search"',
          description: 'Try a different keyword.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(kSpace4),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
      itemBuilder: (_, i) {
        final r = results[i];
        return _PlanSearchResultTile(
          item: r.item,
          day:  r.day,
          displayNumber: _dayDisplayNumber(r.day),
          onTap: () => _selectItem(r.item.id),
        );
      },
    );
  }

  Widget _buildMobileSearchResults(BuildContext context) {
    final results = _planSearchResults;
    if (results.isEmpty) {
      return Center(
        child: WabwayEmptyState(
          icon: Icons.search_off_rounded,
          title: 'No results for "$_search"',
          description: 'Try a different keyword.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(kSpace4),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
      itemBuilder: (ctx, i) {
        final r = results[i];
        final spots = _spots;
        final docs  = _docs;
        final days  = List<TripDay>.from(_days);
        return _PlanSearchResultTile(
          item: r.item,
          day:  r.day,
          displayNumber: _dayDisplayNumber(r.day),
          onTap: () => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => ItemDetailScreen(
                item:      r.item,
                day:       r.day,
                spots:     spots,
                docs:      docs,
                days:      days,
                onDelete:  () => _deleteItem(r.item.id),
                onUpdated: _updateItem,
                onMove:    (newDayId) => _onMoveItem(r.item, newDayId),
                onDuplicate: () => _onDuplicateItem(r.item),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Budget bar ───────────────────────────────────────────────────────────────

class _PlanBudgetBar extends StatelessWidget {
  const _PlanBudgetBar({required this.summary});
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
      decoration: BoxDecoration(
        color: kColorPrimary.withValues(alpha: 0.08),
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorPrimary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(Icons.account_balance_wallet_rounded, size: 16, color: kColorPrimary),
          const SizedBox(width: kSpace2),
          Text('Planned · $summary',
              style: kStyleCaption.copyWith(color: kColorPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

class _PlanProgressBar extends StatelessWidget {
  const _PlanProgressBar({required this.done, required this.total});
  final int done;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? done / total : 0.0;
    final allDone = done == total && total > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allDone ? Icons.check_circle_rounded : Icons.checklist_rounded,
                size: 14,
                color: allDone ? kColorSuccess : kColorInkSoft,
              ),
              const SizedBox(width: kSpace2),
              Text(
                allDone ? 'All done!' : '$done of $total items done',
                style: kStyleCaption.copyWith(
                  color: allDone ? kColorSuccess : kColorInkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).round()}%',
                style: kStyleCaption.copyWith(
                  color: allDone ? kColorSuccess : kColorInkSoft,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: kRadiusPill,
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: kColorSurfaceSunken,
              color: allDone ? kColorSuccess : kColorPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Plan search result tile ──────────────────────────────────────────────────

class _PlanSearchResultTile extends StatelessWidget {
  const _PlanSearchResultTile({
    required this.item,
    required this.day,
    required this.displayNumber,
    required this.onTap,
  });
  final ItineraryItem item;
  final TripDay day;
  final int displayNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      hoverable: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kColorPrimary.withValues(alpha: 0.1),
              borderRadius: kRadiusMd,
            ),
            child: Icon(item.type.icon, size: 18, color: kColorPrimary),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: kStyleBodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  'Day $displayNumber · ${day.city}',
                  style: kStyleCaption.copyWith(color: kColorInkSoft),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, size: 18, color: kColorInkSoft),
        ],
      ),
    );
  }
}

// ─── Desktop day detail panel ─────────────────────────────────────────────────

class _DayDetailPanel extends StatelessWidget {
  const _DayDetailPanel({
    super.key,
    required this.day,
    this.displayNumber,
    required this.onAddItem,
  });

  final TripDay day;
  final int? displayNumber;
  final VoidCallback onAddItem;

  @override
  Widget build(BuildContext context) {
    final itemsByType = <ItineraryItemType, int>{};
    for (final item in day.items) {
      itemsByType[item.type] = (itemsByType[item.type] ?? 0) + 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(kSpace5),
          color: kColorPrimarySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: kColorPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${displayNumber ?? day.dayNumber}',
                        style: kStyleBodySemibold.copyWith(
                          color: kColorTextOnPrimary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpace3),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Day ${displayNumber ?? day.dayNumber}',
                          style: kStyleTitle.copyWith(fontSize: 20)),
                      Text(
                        fmtDate(day.date),
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: kTextSm,
                          color: kColorInkSoft,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: kSpace3),
              Row(
                children: [
                  const Icon(Icons.location_city_rounded,
                      size: 14, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Text(day.city,
                      style: kStyleBodyMedium.copyWith(color: kColorInk)),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(kSpace5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (day.notes != null && day.notes!.isNotEmpty) ...[
                Text('Notes',
                    style:
                        kStyleCaptionMedium.copyWith(color: kColorInkSoft)),
                const SizedBox(height: kSpace2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(kSpace3),
                  decoration: BoxDecoration(
                    color: kColorSurfaceSunken,
                    borderRadius: kRadiusMd,
                    border: Border.all(color: kColorBorder),
                  ),
                  child: Text(
                    day.notes!,
                    style: kStyleBody.copyWith(height: 1.6),
                  ),
                ),
                const SizedBox(height: kSpace5),
              ],
              if (day.items.isNotEmpty) ...[
                Text(
                  '${day.items.length} item${day.items.length == 1 ? '' : 's'}',
                  style: kStyleCaptionMedium.copyWith(color: kColorInkSoft),
                ),
                const SizedBox(height: kSpace2),
                Wrap(
                  spacing: kSpace2,
                  runSpacing: kSpace2,
                  children: [
                    for (final entry in itemsByType.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: entry.key.softColor,
                          borderRadius: kRadiusPill,
                          border: Border.all(
                              color: entry.key.color.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(entry.key.icon,
                                size: 12, color: entry.key.color),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.value} ${entry.key.label}',
                              style: kStyleCaption.copyWith(
                                color: entry.key.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: kSpace5),
              ],
              WabwayButton(
                label: 'Add item to this day',
                icon: Icons.add_rounded,
                variant: WabwayButtonVariant.ghost,
                onPressed: onAddItem,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Edit day sheet ───────────────────────────────────────────────────────────

typedef _EditDaySaved = void Function(
  String? city, DateTime? date, String? notes, bool clearNotes);

void _showEditDaySheet(
  BuildContext context, {
  required TripDay day,
  int? displayNumber,
  required _EditDaySaved onSaved,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditDaySheet(day: day, displayNumber: displayNumber, onSaved: onSaved),
  );
}

class _EditDaySheet extends StatefulWidget {
  const _EditDaySheet({required this.day, this.displayNumber, required this.onSaved});
  final TripDay day;
  final int? displayNumber;
  final _EditDaySaved onSaved;

  @override
  State<_EditDaySheet> createState() => _EditDaySheetState();
}

class _EditDaySheetState extends State<_EditDaySheet> {
  late final TextEditingController _cityCtrl;
  late final TextEditingController _notesCtrl;
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _cityCtrl  = TextEditingController(text: widget.day.city);
    _notesCtrl = TextEditingController(text: widget.day.notes ?? '');
    _date      = widget.day.date;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final city  = _cityCtrl.text.trim();
    final notes = _notesCtrl.text.trim();
    final origNotes = widget.day.notes ?? '';
    widget.onSaved(
      city.isNotEmpty && city != widget.day.city ? city : null,
      _date != widget.day.date ? _date : null,
      notes.isNotEmpty ? notes : null,
      notes.isEmpty && origNotes.isNotEmpty,
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: ListView(
          controller: ctrl,
          padding: EdgeInsets.fromLTRB(
            kSpace4, kSpace2, kSpace4,
            kSpace4 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const WabwayDragHandle(),
            const SizedBox(height: kSpace3),
            Text('Edit Day ${widget.displayNumber ?? widget.day.dayNumber}', style: kStyleTitle),
            const SizedBox(height: kSpace5),

            Text('Date', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const SizedBox(height: kSpace2),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: kSpace3),
                decoration: BoxDecoration(
                  color: kColorSurfaceSunken,
                  borderRadius: kRadiusMd,
                  border: Border.all(color: kColorBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: kColorInkSoft),
                    const SizedBox(width: kSpace2),
                    Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                      style: kStyleBody,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: kSpace4),
            WabwayTextField(
              label: 'City',
              hint: 'e.g. Tokyo',
              controller: _cityCtrl,
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: kSpace4),
            WabwayTextField(
              label: 'Notes (optional)',
              hint: 'Any notes for this day',
              controller: _notesCtrl,
              maxLines: 3,
            ),

            const SizedBox(height: kSpace5),
            WabwayButton(
              label: 'Save changes',
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Desktop top bar ──────────────────────────────────────────────────────────

class _DesktopPlanBar extends StatelessWidget {
  const _DesktopPlanBar({
    required this.dayCount,
    required this.onAddDay,
    required this.onAddAllDays,
    this.showAddAllDays = false,
    this.onExport,
    this.onExportCalendar,
    this.hideCompleted = false,
    this.onToggleHideCompleted,
  });

  final int dayCount;
  final VoidCallback onAddDay;
  final VoidCallback onAddAllDays;
  final bool showAddAllDays;
  final VoidCallback? onExport;
  final VoidCallback? onExportCalendar;
  final bool hideCompleted;
  final VoidCallback? onToggleHideCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kTopBarHeight,
      decoration: const BoxDecoration(
        color: kColorBgRaised,
        border: Border(bottom: BorderSide(color: kColorBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      child: Row(
        children: [
          Text('Plan', style: kStyleTitle),
          const SizedBox(width: kSpace3),
          if (dayCount > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusPill,
              ),
              child: Text(
                '$dayCount days',
                style: GoogleFonts.ibmPlexMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kColorInkSoft,
                ),
              ),
            ),
          const Spacer(),
          if (onExport != null) ...[
            WabwayButton(
              label: 'Export',
              icon: Icons.ios_share_rounded,
              size: WabwayButtonSize.sm,
              variant: WabwayButtonVariant.ghost,
              onPressed: onExport,
            ),
            const SizedBox(width: kSpace2),
          ],
          if (onExportCalendar != null) ...[
            WabwayButton(
              label: 'Calendar',
              icon: Icons.calendar_month_rounded,
              size: WabwayButtonSize.sm,
              variant: WabwayButtonVariant.ghost,
              onPressed: onExportCalendar,
            ),
            const SizedBox(width: kSpace2),
          ],
          if (onToggleHideCompleted != null) ...[
            WabwayButton(
              label: hideCompleted ? 'Show done' : 'Hide done',
              icon: hideCompleted
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: WabwayButtonSize.sm,
              variant: hideCompleted
                  ? WabwayButtonVariant.primary
                  : WabwayButtonVariant.ghost,
              onPressed: onToggleHideCompleted,
            ),
            const SizedBox(width: kSpace2),
          ],
          if (showAddAllDays) ...[
            WabwayButton(
              label: 'Add all days',
              icon: Icons.date_range_rounded,
              size: WabwayButtonSize.sm,
              variant: WabwayButtonVariant.ghost,
              onPressed: onAddAllDays,
            ),
            const SizedBox(width: kSpace2),
          ],
          WabwayButton(
            label: 'Add Day',
            icon: Icons.calendar_today_rounded,
            size: WabwayButtonSize.sm,
            variant: WabwayButtonVariant.ghost,
            onPressed: onAddDay,
          ),
        ],
      ),
    );
  }
}

// ─── Add day dialog ───────────────────────────────────────────────────────────

// ─── Unplanned spots section ──────────────────────────────────────────────────

class _UnplannedSpotsSection extends StatelessWidget {
  const _UnplannedSpotsSection({
    required this.spots,
    required this.expanded,
    required this.onToggle,
    required this.onSpotTap,
  });

  final List<Spot> spots;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Spot> onSpotTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: expanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : kRadiusLg,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: kSpace4, vertical: kSpace3),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: kColorSuccessSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.place_rounded,
                        size: 14, color: kColorSuccess),
                  ),
                  const SizedBox(width: kSpace3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Unplanned Spots',
                            style: kStyleBodyMedium),
                        Text(
                          '${spots.length} confirmed/planned spot${spots.length == 1 ? '' : 's'} not yet on a day',
                          style: kStyleCaption.copyWith(color: kColorInkSoft),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: kColorInkSoft,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: kColorBorder),
            ...spots.map((spot) => _UnplannedSpotRow(
                  spot: spot,
                  onTap: () => onSpotTap(spot),
                  isLast: spot == spots.last,
                )),
          ],
        ],
      ),
    );
  }
}

class _UnplannedSpotRow extends StatelessWidget {
  const _UnplannedSpotRow({
    required this.spot,
    required this.onTap,
    required this.isLast,
  });

  final Spot spot;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: kSpace4, vertical: kSpace3),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(spot.name, style: kStyleBodyMedium),
                      const SizedBox(height: 2),
                      Text(
                        '${spot.city}${spot.area.isNotEmpty ? ' · ${spot.area}' : ''}',
                        style: kStyleCaption.copyWith(color: kColorInkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: kSpace2),
                WabwayBadge(
                  label: spot.status.label,
                  tone: spot.status.tone,
                ),
                const SizedBox(width: kSpace2),
                const Icon(Icons.add_circle_outline_rounded,
                    size: 18, color: kColorPrimary),
              ],
            ),
          ),
        ),
        if (!isLast) const Divider(height: 1, indent: kSpace4, color: kColorBorder),
      ],
    );
  }
}

// ─── Calendar grid ────────────────────────────────────────────────────────────

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.focus,
    required this.daysMap,
    required this.selected,
    required this.today,
    required this.onSelect,
  });

  final DateTime focus;
  final Map<String, TripDay> daysMap;
  final DateTime? selected;
  final DateTime today;
  final ValueChanged<DateTime> onSelect;

  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(focus.year, focus.month, 1);
    // weekday: 1=Mon … 7=Sun; offset to Sunday-start grid
    final startOffset = firstOfMonth.weekday % 7;
    final gridStart = firstOfMonth.subtract(Duration(days: startOffset));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      child: Column(
        children: [
          // Weekday header
          Row(
            children: _weekdays.map((d) => Expanded(
              child: Center(
                child: Text(
                  d,
                  style: kStyleCaption.copyWith(
                    color: kColorInkSoft,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 4),
          // Grid rows
          ...List.generate(6, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: List.generate(7, (col) {
                  final cellDate =
                      gridStart.add(Duration(days: row * 7 + col));
                  final inMonth = cellDate.month == focus.month;
                  final isToday = _sameDay(cellDate, today);
                  final isSel   = selected != null && _sameDay(cellDate, selected!);
                  final key     = _key(cellDate);
                  final hasDay  = daysMap.containsKey(key);
                  final tripDay = daysMap[key];

                  // Dot colors from item types
                  final dots = tripDay != null
                      ? tripDay.items
                          .map((i) => i.type.color)
                          .toSet()
                          .take(3)
                          .toList()
                      : <Color>[];

                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onSelect(cellDate),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSel
                              ? kColorPrimary
                              : isToday
                                  ? kColorPrimary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${cellDate.day}',
                              style: kStyleCaption.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSel
                                    ? Colors.white
                                    : !inMonth
                                        ? kColorBorder
                                        : isToday
                                            ? kColorPrimary
                                            : hasDay
                                                ? kColorInk
                                                : kColorInkSoft,
                              ),
                            ),
                            if (dots.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: dots.map((c) => Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  decoration: BoxDecoration(
                                    color: isSel ? Colors.white70 : c,
                                    shape: BoxShape.circle,
                                  ),
                                )).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
          const SizedBox(height: kSpace2),
        ],
      ),
    );
  }
}

// ─── Calendar item tile ───────────────────────────────────────────────────────

class _CalendarItemTile extends StatelessWidget {
  const _CalendarItemTile({
    required this.item,
    required this.onTap,
    required this.onToggleDone,
  });

  final ItineraryItem item;
  final VoidCallback  onTap;
  final VoidCallback  onToggleDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: WabwayCard(
        hoverable: true,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 10),
        child: Row(
          children: [
            GestureDetector(
              onTap: onToggleDone,
              child: AnimatedContainer(
                duration: kDurationFast,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.isDone
                      ? kColorSuccess
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.isDone ? kColorSuccess : kColorBorder,
                    width: 1.5,
                  ),
                ),
                child: item.isDone
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: kSpace3),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: item.type.softColor,
                borderRadius: kRadiusSm,
              ),
              child: Icon(item.type.icon, size: 14, color: item.type.color),
            ),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: kStyleBodyMedium.copyWith(
                      decoration: item.isDone ? TextDecoration.lineThrough : null,
                      color: item.isDone ? kColorInkSoft : kColorInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.hasTime || item.location != null)
                    Text(
                      [
                        if (item.hasTime) item.time!,
                        if (item.location != null && item.location!.isNotEmpty)
                          item.location,
                      ].join(' · '),
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const SizedBox(width: kSpace2),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: kColorInkSoft),
          ],
        ),
      ),
    );
  }
}

// ─── Add day dialog ───────────────────────────────────────────────────────────

Future<TripDay?> _showAddDayDialog(BuildContext context, {required DateTime defaultDate}) {
  return showDialog<TripDay>(
    context: context,
    builder: (ctx) => _AddDayDialog(defaultDate: defaultDate),
  );
}

class _AddDayDialog extends StatefulWidget {
  const _AddDayDialog({required this.defaultDate});

  final DateTime defaultDate;

  @override
  State<_AddDayDialog> createState() => _AddDayDialogState();
}

class _AddDayDialogState extends State<_AddDayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = widget.defaultDate;
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      TripDay(
        id: '',
        dayNumber: 0,
        date: _date,
        city: _cityCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
      title: Text('Add day', style: kStyleBodySemibold),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Date',
                  style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              const SizedBox(height: kSpace2),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  height: 48,
                  padding:
                      const EdgeInsets.symmetric(horizontal: kSpace3),
                  decoration: BoxDecoration(
                    color: kColorSurfaceSunken,
                    borderRadius: kRadiusMd,
                    border: Border.all(color: kColorBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 16, color: kColorInkSoft),
                      const SizedBox(width: kSpace2),
                      Text(
                        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                        style: kStyleBody,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: kSpace3),
              WabwayTextField(
                label: 'City',
                hint: 'e.g. Tokyo',
                controller: _cityCtrl,
                textInputAction: TextInputAction.next,
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                        ? 'City is required'
                        : null,
              ),
              const SizedBox(height: kSpace3),
              WabwayTextField(
                label: 'Notes (optional)',
                hint: 'Any notes for this day',
                controller: _notesCtrl,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: kStyleBody.copyWith(color: kColorInkSoft)),
        ),
        TextButton(
          onPressed: _submit,
          child: Text('Add day',
              style: kStyleBodyMedium.copyWith(color: kColorPrimary)),
        ),
      ],
    );
  }
}
