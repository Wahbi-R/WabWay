import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/supabase/client.dart';
import '../core/supabase/plan_service.dart';
import '../core/supabase/spot_service.dart';
import '../core/supabase/doc_service.dart';
import '../core/trip/trip_state.dart';
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

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  final List<TripDay> _days = [];
  final List<Spot> _spots = [];
  final List<TripDocument> _docs = [];

  bool _loading = false;
  String? _error;
  String _activeTripId = '';
  String _userId = '';

  RealtimeChannel? _channel;
  Timer? _debounce;

  String? _selectedItemId;
  String? _selectedDayId;
  bool _unplannedExpanded = true;

  ItineraryItem? get _selectedItem => itemById(_days, _selectedItemId ?? '');
  TripDay? get _selectedDay =>
      _selectedItem == null ? null : dayForItem(_days, _selectedItemId ?? '');

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _userId = supabase.auth.currentUser?.id ?? '';
    final tripId = TripState.tripOf(context).id;
    if (tripId != _activeTripId) {
      _activeTripId = tripId;
      _loadAll();
      _subscribeRealtime(tripId);
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _debounce?.cancel();
    super.dispose();
  }

  // ─── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadAll() async {
    if (_activeTripId.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final daysFuture  = PlanService.loadAll(_activeTripId);
      final spotsFuture = SpotService.loadSpots(_activeTripId);
      final docsFuture  = DocService.loadDocuments(_activeTripId);
      final days  = await daysFuture;
      final spots = await spotsFuture;
      final docs  = await docsFuture;
      if (!mounted) return;
      setState(() {
        _days
          ..clear()
          ..addAll(days);
        _spots
          ..clear()
          ..addAll(spots);
        _docs
          ..clear()
          ..addAll(docs);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  Future<void> _silentReload() async {
    if (!mounted || _activeTripId.isEmpty) return;
    try {
      final daysFuture  = PlanService.loadAll(_activeTripId);
      final spotsFuture = SpotService.loadSpots(_activeTripId);
      final docsFuture  = DocService.loadDocuments(_activeTripId);
      final days  = await daysFuture;
      final spots = await spotsFuture;
      final docs  = await docsFuture;
      if (!mounted) return;
      setState(() {
        _days
          ..clear()
          ..addAll(days);
        _spots
          ..clear()
          ..addAll(spots);
        _docs
          ..clear()
          ..addAll(docs);
      });
    } catch (_) {}
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
    _debounce = Timer(const Duration(milliseconds: 400), _silentReload);
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
    PlanService.deleteItem(itemId).catchError((_) => _silentReload());
  }

  void _updateItem(ItineraryItem updated) {
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
    PlanService.updateItem(updated).catchError((_) => _silentReload());
  }

  Future<void> _addItem(BuildContext context, String dayId) async {
    final messenger = ScaffoldMessenger.of(context);
    final draft = await showAddItemSheet(
      context,
      dayId: dayId,
      spots: _spots,
      docs: _docs,
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
        location:        draft.location,
        mapsUrl:         draft.mapsUrl,
        confirmationUrl: draft.confirmationUrl,
        notes:           draft.notes,
        linkedSpotId:    draft.linkedSpotId,
        linkedDocIds:    draft.linkedDocIds,
        sortOrder:       day.items.length,
      );
      if (!mounted) return;
      setState(() {
        day.items.add(item);
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
    final result = await _showDayPickerSheet(context, days: _days);
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
        location:     (spot.address?.isNotEmpty == true) ? spot.address : spot.name,
        mapsUrl:      spot.mapsUrl,
        linkedSpotId: spot.id,
        sortOrder:    day.items.length,
      );
      if (!mounted) return;
      setState(() {
        day.items.add(item);
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

  void _onEditDay(TripDay day) {
    _showEditDaySheet(context, day: day, onSaved: (city, date, notes, clearNotes) {
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
      ).catchError((_) => _silentReload());
    });
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
    PlanService.moveItem(item.id, newDayId).catchError((_) => _silentReload());
  }

  void _onReorderItems(String dayId, List<ItineraryItem> newOrder) {
    final day = _days.where((d) => d.id == dayId).firstOrNull;
    if (day == null) return;
    setState(() {
      day.items
        ..clear()
        ..addAll(newOrder);
    });
    PlanService.reorderItemsInDay(newOrder).catchError((_) => _silentReload());
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
    final draft = await _showAddDayDialog(context);
    if (draft == null || !mounted) return;
    if (_activeTripId.isEmpty || _userId.isEmpty) return;

    try {
      final day = await PlanService.createDay(
        tripId:    _activeTripId,
        dayNumber: _days.length + 1,
        date:      draft.date,
        city:      draft.city,
        createdBy: _userId,
        notes:     draft.notes,
      );
      if (!mounted) return;
      setState(() => _days.add(day));
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

  void _exportPlan() {
    if (_days.isEmpty) return;
    final buf = StringBuffer();
    final tripState = TripState.maybeOf(context);
    final tripName = tripState?.trip.name ?? 'Trip';
    buf.writeln('$tripName — Itinerary');
    buf.writeln('=' * 40);
    for (final day in _days) {
      buf.writeln('\nDay ${day.dayNumber} · ${day.city} · ${fmtDayDate(day.date)}');
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
    SharePlus.instance.share(ShareParams(
      text: text,
      subject: '$tripName — Itinerary',
    ));
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
    final tripState = TripState.maybeOf(context);
    final tripName = tripState?.trip.name ?? 'Trip';

    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//WabWay//EN');
    buf.writeln('CALSCALE:GREGORIAN');
    buf.writeln('METHOD:PUBLISH');

    String _icsDate(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

    String _icsDateTime(DateTime d, String? timeStr) {
      if (timeStr == null) return '${_icsDate(d)}';
      final parts = timeStr.split(':');
      if (parts.length < 2) return '${_icsDate(d)}';
      return '${_icsDate(d)}T${parts[0].padLeft(2, '0')}${parts[1].padLeft(2, '0')}00';
    }

    for (final day in _days) {
      for (final item in day.sortedItems) {
        buf.writeln('BEGIN:VEVENT');
        buf.writeln('UID:wabway-${item.id}@wabway.app');
        buf.writeln('SUMMARY:${item.title.replaceAll(',', '\\,')}');
        if (item.time != null) {
          buf.writeln('DTSTART:${_icsDateTime(day.date, item.time)}');
          buf.writeln('DTEND:${_icsDateTime(day.date, item.time)}');
        } else {
          buf.writeln('DTSTART;VALUE=DATE:${_icsDate(day.date)}');
          buf.writeln('DTEND;VALUE=DATE:${_icsDate(day.date)}');
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
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'text/calendar')],
        subject: '$tripName — Calendar',
      ));
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
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    return isDesktop ? _buildDesktop(context) : _buildMobile(context);
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
            onExport: _days.isNotEmpty ? _exportPlan : null,
            onExportCalendar: (_days.isNotEmpty && !kIsWeb) ? _exportToCalendar : null,
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
                                          selectedItemId: _selectedItemId,
                                          onItemTap: _selectItem,
                                          onAddItem: () =>
                                              _addItem(context, _days[di].id),
                                          isDesktop: true,
                                          onDayTap: () => _selectDay(_days[di].id),
                                          daySelected: _selectedDayId == _days[di].id,
                                          onEditDay: () => _onEditDay(_days[di]),
                                          onReorder: (newOrder) =>
                                              _onReorderItems(_days[di].id, newOrder),
                                        ),
                                      );
                                    },
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
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: WabwayEmptyState(
                    icon: Icons.error_outline_rounded,
                    title: 'Could not load plan',
                    description: _error!,
                  ),
                )
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
                            onReorder: (newOrder) =>
                                _onReorderItems(_days[di].id, newOrder),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'plan_fab',
        onPressed: () {
          if (_days.isEmpty) {
            _addDay(context);
          } else {
            _addItem(context, _days.last.id);
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
}

// ─── Desktop day detail panel ─────────────────────────────────────────────────

class _DayDetailPanel extends StatelessWidget {
  const _DayDetailPanel({
    super.key,
    required this.day,
    required this.onAddItem,
  });

  final TripDay day;
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
                        '${day.dayNumber}',
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
                      Text('Day ${day.dayNumber}',
                          style: kStyleTitle.copyWith(fontSize: 20)),
                      Text(
                        fmtDayDate(day.date),
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
  required _EditDaySaved onSaved,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditDaySheet(day: day, onSaved: onSaved),
  );
}

class _EditDaySheet extends StatefulWidget {
  const _EditDaySheet({required this.day, required this.onSaved});
  final TripDay day;
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
            Text('Edit Day ${widget.day.dayNumber}', style: kStyleTitle),
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
    this.onExport,
    this.onExportCalendar,
  });

  final int dayCount;
  final VoidCallback onAddDay;
  final VoidCallback? onExport;
  final VoidCallback? onExportCalendar;

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

// ─── Day picker sheet (for unplanned spots) ───────────────────────────────────

Future<(String dayId, TimeOfDay? time)?> _showDayPickerSheet(
  BuildContext context, {
  required List<TripDay> days,
}) {
  return showModalBottomSheet<(String, TimeOfDay?)>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DayPickerSheet(days: days),
  );
}

class _DayPickerSheet extends StatefulWidget {
  const _DayPickerSheet({required this.days});
  final List<TripDay> days;

  @override
  State<_DayPickerSheet> createState() => _DayPickerSheetState();
}

class _DayPickerSheetState extends State<_DayPickerSheet> {
  String? _selectedDayId;
  TimeOfDay? _time;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WabwayDragHandle(),
                  const SizedBox(height: kSpace3),
                  Text('Add to which day?', style: kStyleTitle),
                  const SizedBox(height: kSpace2),
                  Text('Pick a day for this spot.',
                      style: kStyleBody.copyWith(color: kColorInkSoft)),
                  const SizedBox(height: kSpace3),
                  const Divider(height: 1, color: kColorBorder),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpace4, vertical: kSpace3),
                itemCount: widget.days.length,
                separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
                itemBuilder: (_, i) {
                  final day = widget.days[i];
                  final selected = _selectedDayId == day.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedDayId = day.id),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.all(kSpace3),
                      decoration: BoxDecoration(
                        color: selected ? kColorPrimarySoft : kColorSurfaceSunken,
                        borderRadius: kRadiusMd,
                        border: Border.all(
                          color: selected ? kColorPrimary : kColorBorder,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: selected ? kColorPrimary : kColorBorder,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${day.dayNumber}',
                                style: kStyleCaptionMedium.copyWith(
                                  color: selected
                                      ? kColorTextOnPrimary
                                      : kColorInkSoft,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: kSpace3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(day.city, style: kStyleBodyMedium),
                                Text(fmtDayDate(day.date),
                                    style: kStyleCaption.copyWith(
                                        color: kColorInkSoft)),
                              ],
                            ),
                          ),
                          if (selected)
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: kColorPrimary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  kSpace4, 0, kSpace4,
                  kSpace4 + MediaQuery.paddingOf(context).bottom),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickTime,
                    child: Container(
                      height: 44,
                      padding:
                          const EdgeInsets.symmetric(horizontal: kSpace3),
                      decoration: BoxDecoration(
                        color: kColorSurfaceSunken,
                        borderRadius: kRadiusMd,
                        border: Border.all(color: kColorBorder),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded,
                              size: 16, color: kColorInkSoft),
                          const SizedBox(width: kSpace2),
                          Text(
                            _time != null
                                ? _time!.format(context)
                                : 'Set time (optional)',
                            style: kStyleBody.copyWith(
                              color: _time != null
                                  ? kColorInk
                                  : kColorInkSoft,
                            ),
                          ),
                          if (_time != null) ...[
                            const Spacer(),
                            GestureDetector(
                              onTap: () => setState(() => _time = null),
                              child: const Icon(Icons.close_rounded,
                                  size: 16, color: kColorInkSoft),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: kSpace3),
                  WabwayButton(
                    label: 'Add to plan',
                    icon: Icons.add_rounded,
                    onPressed: _selectedDayId == null
                        ? null
                        : () => Navigator.pop(
                            context, (_selectedDayId!, _time)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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

// ─── Add day dialog ───────────────────────────────────────────────────────────

Future<TripDay?> _showAddDayDialog(BuildContext context) {
  return showDialog<TripDay>(
    context: context,
    builder: (ctx) => const _AddDayDialog(),
  );
}

class _AddDayDialog extends StatefulWidget {
  const _AddDayDialog();

  @override
  State<_AddDayDialog> createState() => _AddDayDialogState();
}

class _AddDayDialogState extends State<_AddDayDialog> {
  final _formKey = GlobalKey<FormState>();
  final _cityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now();

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
