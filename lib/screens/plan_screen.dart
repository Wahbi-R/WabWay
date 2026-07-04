import 'dart:async';
import 'package:flutter/material.dart';
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

  ItineraryItem? get _selectedItem => itemById(_days, _selectedItemId ?? '');
  TripDay? get _selectedDay =>
      _selectedItem == null ? null : dayForItem(_days, _selectedItemId ?? '');

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
                            child: _days.isEmpty
                                ? _buildEmptyTimeline(context)
                                : ListView.separated(
                                    padding: const EdgeInsets.all(kSpace4),
                                    itemCount: _days.length,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: kSpace3),
                                    itemBuilder: (ctx, i) => TripDayCard(
                                      day: _days[i],
                                      selectedItemId: _selectedItemId,
                                      onItemTap: _selectItem,
                                      onAddItem: () =>
                                          _addItem(context, _days[i].id),
                                      isDesktop: true,
                                      onDayTap: () =>
                                          _selectDay(_days[i].id),
                                      daySelected:
                                          _selectedDayId == _days[i].id,
                                      onEditDay: () => _onEditDay(_days[i]),
                                    ),
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
              : _days.isEmpty
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
                  : ListView.separated(
                      padding: const EdgeInsets.all(kSpace4),
                      itemCount: _days.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: kSpace3),
                      itemBuilder: (ctx, i) => TripDayCard(
                        day: _days[i],
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
                                  onMove: (newDayId) => _onMoveItem(item, newDayId),
                                  onDuplicate: () => _onDuplicateItem(item),
                                ),
                              ),
                            );
                          }
                        },
                        onAddItem: () => _addItem(context, _days[i].id),
                        onEditDay: () => _onEditDay(_days[i]),
                      ),
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
  });

  final int dayCount;
  final VoidCallback onAddDay;

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
