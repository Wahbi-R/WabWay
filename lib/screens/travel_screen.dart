import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/notifications/push_notifier.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/client.dart';
import '../core/supabase/travel_service.dart';
import '../core/supabase/doc_service.dart';
import '../core/supabase/plan_service.dart';
import 'notification_settings_screen.dart';
import '../data/date_utils.dart';
import '../data/travel_data.dart';
import '../data/docs_data.dart';
import '../data/plan_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'travel/travel_item_card.dart';
import 'travel/travel_item_detail.dart';
import 'travel/add_travel_sheet.dart';

class TravelScreen extends ConsumerStatefulWidget {
  const TravelScreen({super.key});

  @override
  ConsumerState<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends ConsumerState<TravelScreen> {
  final List<TravelItem> _items = [];
  final List<TripDocument> _docs = [];
  final List<TripDay> _days = [];

  bool _loading = true;
  String? _error;
  String _activeTripId = '';
  String _userId = '';

  RealtimeChannel? _channel;
  Timer? _debounce;
  int _loadGen = 0;

  TravelItemType? _filter;
  TravelBookingStatus? _statusFilter;
  String _search = '';
  String? _selectedId;

  final _searchCtrl = TextEditingController();
  final _listCtrl = ScrollController();

  TravelItem? get _selectedItem =>
      _selectedId == null ? null : _items.where((i) => i.id == _selectedId).firstOrNull;

  // Sorted chronologically so the list reads like the trip timeline.
  // Items without a date (draft bookings) fall to the end.
  List<TravelItem> get _filtered {
    var items = _filter == null
        ? List<TravelItem>.from(_items)
        : _items.where((i) => i.type == _filter).toList();
    if (_statusFilter != null) {
      items = items.where((i) => i.status == _statusFilter).toList();
    }
    final q = _search.toLowerCase().trim();
    if (q.isNotEmpty) {
      bool m(String? s) => s != null && s.toLowerCase().contains(q);
      items = items
          .where((i) => m(i.title) || m(i.location) || m(i.destination) ||
              m(i.confirmationNumber) || m(i.notes))
          .toList();
    }
    items.sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return a.date!.compareTo(b.date!);
    });
    return items;
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
    _channel?.unsubscribe();
    _debounce?.cancel();
    _searchCtrl.dispose();
    _listCtrl.dispose();
    super.dispose();
  }

  bool get _hasTodayItem {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    return _filtered.any((i) {
      if (i.date == null) return false;
      final k = DateTime(i.date!.year, i.date!.month, i.date!.day);
      return k == todayKey;
    });
  }

  void _scrollToToday() {
    final now = DateTime.now();
    final todayKey = DateTime(now.year, now.month, now.day);
    final mixed = _buildMixedList(_filtered);
    final idx = mixed.indexWhere((e) => e is DateTime && e == todayKey);
    if (idx < 0 || !_listCtrl.hasClients) return;
    double offset = kSpace3;
    for (int i = 0; i < idx; i++) {
      final e = mixed[i];
      offset += (e is DateTime || e is String) ? 32.0 : 88.0;
    }
    _listCtrl.animateTo(
      offset.clamp(0.0, _listCtrl.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  bool _offline = false;

  // ─── Data loading ─────────────────────────────────────────────────────────────

  // silent=false shows a full loading spinner (first load / retry);
  // silent=true silently refreshes in the background after a realtime event.
  Future<void> _loadAll({bool silent = false}) async {
    if (_activeTripId.isEmpty) return;
    final gen = ++_loadGen;
    if (!silent) setState(() { _loading = true; _error = null; _offline = false; _items.clear(); _docs.clear(); _days.clear(); });

    if (!silent) {
      final cachedItemsFuture = TravelService.loadFromCache(_activeTripId);
      final cachedDocsFuture  = DocService.loadDocumentsFromCache(_activeTripId);
      final cachedDaysFuture  = PlanService.loadFromCache(_activeTripId);
      final cachedItems = await cachedItemsFuture;
      final cachedDocs  = await cachedDocsFuture;
      final cachedDays  = await cachedDaysFuture;
      if (!mounted || gen != _loadGen) return;
      if (cachedItems != null) {
        setState(() {
          _items..clear()..addAll(cachedItems);
          _docs..clear()..addAll(cachedDocs ?? []);
          _days..clear()..addAll(cachedDays ?? []);
          _loading = false;
        });
      }
    }

    try {
      final itemsFuture = TravelService.loadItems(_activeTripId);
      final docsFuture  = DocService.loadDocuments(_activeTripId);
      final daysFuture  = PlanService.loadAll(_activeTripId);
      final items = await itemsFuture;
      final docs  = await docsFuture;
      final days  = await daysFuture;
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _items..clear()..addAll(items);
        _docs..clear()..addAll(docs);
        _days..clear()..addAll(days);
        if (!silent) _loading = false;
        _offline = false;
      });
    } catch (e) {
      if (!mounted || gen != _loadGen) return;
      if (silent) { setState(() => _offline = true); return; }
      if (_items.isEmpty) {
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
        .channel('travel-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'travel_items',
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

  void _select(String id) => setState(() => _selectedId = id);

  void _delete(String id) {
    setState(() {
      _items.removeWhere((i) => i.id == id);
      if (_selectedId == id) _selectedId = null;
    });
    TravelService.deleteItem(id).catchError((_) => _loadAll(silent: true));
  }

  void _updateItem(TravelItem updated) {
    final old = _items.where((i) => i.id == updated.id).firstOrNull;
    setState(() {
      final idx = _items.indexWhere((i) => i.id == updated.id);
      if (idx != -1) _items[idx] = updated;
      _selectedId = updated.id;
    });
    TravelService.updateItem(updated).catchError((_) => _loadAll(silent: true));
    if (old != null && _userId.isNotEmpty) {
      TravelService.syncDocLinks(
        updated.id, old.linkedDocIds, updated.linkedDocIds, _userId,
      ).catchError((_) => _loadAll(silent: true));
    }
  }

  Future<void> _addItem(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final formItem = await showAddTravelSheet(context, docs: _docs);
    if (formItem == null || !mounted) return;
    if (_activeTripId.isEmpty || _userId.isEmpty) return;

    try {
      final created = await TravelService.createItem(
        tripId:             _activeTripId,
        title:              formItem.title,
        type:               formItem.type,
        status:             formItem.status,
        createdBy:          _userId,
        date:               formItem.date,
        endDate:            formItem.endDate,
        time:               formItem.time,
        endTime:            formItem.endTime,
        location:           formItem.location,
        destination:        formItem.destination,
        confirmationNumber: formItem.confirmationNumber,
        address:            formItem.address,
        notes:              formItem.notes,
        departureTerminal:  formItem.departureTerminal,
        arrivalTerminal:    formItem.arrivalTerminal,
        gate:               formItem.gate,
        seat:               formItem.seat,
        boardingTime:       formItem.boardingTime,
        linkedDocIds:       formItem.linkedDocIds,
      );
      if (!mounted) return;
      setState(() {
        _items.add(created);
        _selectedId = created.id;
      });

      pushNotify(
        tripId: _activeTripId,
        title: 'New travel item added',
        body: created.title,
        excludeUserId: _userId,
        data: {'screen': 'travel', 'trip_id': _activeTripId},
        prefKey: kPrefNotifItinerary,
      );

    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        content: Text(
          'Failed to add travel item: $e',
          style: kStyleBody.copyWith(color: Colors.white),
        ),
        backgroundColor: kColorDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _exportCsv() {
    final items = _filtered;
    if (items.isEmpty) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export is not supported on web.',
            style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final tripName = ref.read(activeTripProvider)?.name ?? 'Trip';
    final buf = StringBuffer();
    buf.writeln('Type,Status,Title,Date,End Date,Time,End Time,From,To,Confirmation,Address,Notes');
    for (final i in items) {
      buf.writeln([
        _csvCell(i.type.label),
        _csvCell(i.status.label),
        _csvCell(i.title),
        _csvCell(i.date?.toIso8601String().substring(0, 10) ?? ''),
        _csvCell(i.endDate?.toIso8601String().substring(0, 10) ?? ''),
        _csvCell(i.time ?? ''),
        _csvCell(i.endTime ?? ''),
        _csvCell(i.location ?? ''),
        _csvCell(i.destination ?? ''),
        _csvCell(i.confirmationNumber ?? ''),
        _csvCell(i.address ?? ''),
        _csvCell(i.notes ?? ''),
      ].join(','));
    }
    Share.share(buf.toString(), subject: '$tripName — Travel');
  }

  static String _csvCell(String v) => '"${v.replaceAll('"', '""')}"';

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _activeTripId) {
        _activeTripId = next;
        _loadAll();
        _subscribeRealtime(next);
      }
    });
    if (_loading) return const WabwayLoadingScaffold();

    if (_error != null) {
      return Scaffold(
        backgroundColor: kColorCream,
        body: Center(
          child: WabwayEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load travel',
            description: _error!,
          ),
        ),
      );
    }

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
          _DesktopTravelBar(
            itemCount: _items.length,
            onAdd: () => _addItem(context),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 420,
                  child: Column(
                    children: [
                      WabwaySearchBar(
                        controller: _searchCtrl,
                        hint: 'Search travel…',
                        onChanged: (v) => setState(() => _search = v),
                      ),
                      _FilterChips(
                        selected: _filter,
                        onSelect: (t) => setState(() {
                          _filter = _filter == t ? null : t;
                          _selectedId = null;
                        }),
                        items: _items,
                      ),
                      _StatusFilterChips(
                        selected: _statusFilter,
                        onSelect: (s) => setState(() {
                          _statusFilter = _statusFilter == s ? null : s;
                          _selectedId = null;
                        }),
                        items: _items,
                      ),
                      Expanded(child: _buildList(desktop: true)),
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
    if (item != null) {
      return SingleChildScrollView(
        child: TravelItemDetailContent(
          key: ValueKey(item.id),
          item: item,
          docs: _docs,
          days: _days,
          onDelete: () => _delete(item.id),
          onUpdated: _updateItem,
        ),
      );
    }
    return const Center(
      child: WabwayEmptyState(
        icon: Icons.flight_rounded,
        title: 'Select a travel item',
        description: 'Pick a flight, hotel, or booking from the list to see details.',
      ),
    );
  }

  // ─── Mobile ───────────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Travel', style: kStyleTitle),
        actions: [
          if (_hasTodayItem && _filter == null && _search.isEmpty)
            IconButton(
              icon: const Icon(Icons.today_rounded, size: 20),
              tooltip: 'Jump to today',
              color: kColorPrimary,
              onPressed: _scrollToToday,
            ),
          if (_items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded, size: 20),
              tooltip: 'Export as CSV',
              onPressed: _exportCsv,
            ),
        ],
      ),
      body: Column(
        children: [
          WabwaySearchBar(
            controller: _searchCtrl,
            hint: 'Search travel…',
            onChanged: (v) => setState(() => _search = v),
          ),
          _FilterChips(
            selected: _filter,
            onSelect: (t) => setState(() => _filter = _filter == t ? null : t),
            items: _items,
          ),
          _StatusFilterChips(
            selected: _statusFilter,
            onSelect: (s) => setState(() => _statusFilter = _statusFilter == s ? null : s),
            items: _items,
          ),
          Expanded(child: _buildList(desktop: false)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'travel_fab',
        onPressed: () => _addItem(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add travel',
          style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
        ),
      ),
    );
  }

  // ─── Shared list ──────────────────────────────────────────────────────────────

  // Builds a mixed list of date-label strings and TravelItem objects so the
  // ListView can insert sticky date separators between date groups.
  List<Object> _buildMixedList(List<TravelItem> items) {
    final result = <Object>[];
    DateTime? lastDate;
    for (final item in items) {
      final d = item.date;
      if (d != null) {
        final key = DateTime(d.year, d.month, d.day);
        if (lastDate == null || key != lastDate) {
          lastDate = key;
          result.add(key);
        }
      } else if (lastDate != null || result.isEmpty) {
        if (!result.any((e) => e is String && e == 'No date')) {
          result.add('No date');
        }
      }
      result.add(item);
    }
    return result;
  }

  Widget _buildList({required bool desktop}) {
    final items = _filtered;

    if (items.isEmpty) {
      return Center(
        child: _filter == null && _statusFilter == null && _search.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const WabwayEmptyState(
                    icon: Icons.flight_rounded,
                    title: 'No travel items yet',
                    description:
                        'Add flights, hotels, trains, tickets, and reservations here.',
                  ),
                  if (!desktop) ...[
                    const SizedBox(height: kSpace4),
                    WabwayButton(
                      label: 'Add travel item',
                      icon: Icons.add_rounded,
                      onPressed: () => _addItem(context),
                    ),
                  ],
                ],
              )
            : _search.isNotEmpty
                ? WabwayEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No results for "$_search"',
                    description: 'Try a different search term.',
                  )
                : _statusFilter != null
                    ? WabwayEmptyState(
                        icon: _statusFilter!.icon,
                        title: 'No ${_statusFilter!.label.toLowerCase()} bookings',
                        description: 'No items with that status.',
                      )
                    : WabwayEmptyState(
                        icon: _filter!.icon,
                        title: 'No ${_filter!.label.toLowerCase()}s',
                        description: 'No ${_filter!.label.toLowerCase()} items added yet.',
                      ),
      );
    }

    final mixed = _buildMixedList(items);

    return ListView.builder(
      controller: desktop ? null : _listCtrl,
      padding: EdgeInsets.fromLTRB(
        kSpace4,
        kSpace3,
        kSpace4,
        desktop ? kSpace4 : kSpace20,
      ),
      itemCount: mixed.length,
      itemBuilder: (ctx, i) {
        final entry = mixed[i];

        // Date separator
        if (entry is DateTime) {
          final label = _travelDateLabel(entry);
          return Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : kSpace4,
              bottom: kSpace2,
            ),
            child: Text(label, style: kStyleOverline),
          );
        }
        if (entry is String) {
          return Padding(
            padding: EdgeInsets.only(
              top: i == 0 ? 0 : kSpace4,
              bottom: kSpace2,
            ),
            child: Text(entry, style: kStyleOverline),
          );
        }

        // Travel item card
        final item = entry as TravelItem;
        final docsSnapshot = List<TripDocument>.unmodifiable(_docs);
        final daysSnapshot = List<TripDay>.unmodifiable(_days);
        final isLast = i == mixed.length - 1 || mixed[i + 1] is! TravelItem;
        return Dismissible(
          key: ValueKey('travel_${item.id}'),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            _delete(item.id);
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
              content: Text('"${item.title}" removed.',
                  style: kStyleBody.copyWith(color: Colors.white)),
              behavior: SnackBarBehavior.floating,
            ));
            return false;
          },
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: kSpace5),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: kRadiusMd,
            ),
            child: const Icon(Icons.delete_rounded, color: Colors.red, size: 22),
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : kSpace3),
            child: TravelItemCard(
              item: item,
              isSelected: desktop && _selectedId == item.id,
              onTap: desktop
                  ? () => _select(item.id)
                  : () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => TravelItemDetailScreen(
                            item: item,
                            docs: docsSnapshot,
                            days: daysSnapshot,
                            onDelete: () => _delete(item.id),
                            onUpdated: _updateItem,
                          ),
                        ),
                      ),
            ),
          ),
        );
      },
    );
  }
}

String _travelDateLabel(DateTime d) {
  final today = DateTime.now();
  final todayKey = DateTime(today.year, today.month, today.day);
  final tomorrow = todayKey.add(const Duration(days: 1));
  final yesterday = todayKey.subtract(const Duration(days: 1));
  if (d == todayKey)   return 'Today · ${fmtDate(d)}';
  if (d == tomorrow)   return 'Tomorrow · ${fmtDate(d)}';
  if (d == yesterday)  return 'Yesterday · ${fmtDate(d)}';
  return fmtDate(d);
}

// ─── Desktop top bar ──────────────────────────────────────────────────────────

class _DesktopTravelBar extends StatelessWidget {
  const _DesktopTravelBar({
    required this.itemCount,
    required this.onAdd,
  });

  final int itemCount;
  final VoidCallback onAdd;

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
          Text('Travel', style: kStyleTitle),
          const SizedBox(width: kSpace3),
          if (itemCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: const BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusPill,
              ),
              child: Text(
                '$itemCount items',
                style: kStyleCaption.copyWith(
                  color: kColorInkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const Spacer(),
          WabwayButton(
            label: 'Add item',
            icon: Icons.add_rounded,
            size: WabwayButtonSize.sm,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ─── Booking status filter chips ──────────────────────────────────────────────

class _StatusFilterChips extends StatelessWidget {
  const _StatusFilterChips({
    required this.selected,
    required this.onSelect,
    required this.items,
  });

  final TravelBookingStatus? selected;
  final ValueChanged<TravelBookingStatus> onSelect;
  final List<TravelItem> items;

  @override
  Widget build(BuildContext context) {
    final presentStatuses = TravelBookingStatus.values
        .where((s) => items.any((i) => i.status == s))
        .toList();
    // Only show if more than one status is present
    if (presentStatuses.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace1),
        children: presentStatuses.map((status) {
          final isActive = selected == status;
          final count = items.where((i) => i.status == status).length;
          return Padding(
            padding: const EdgeInsets.only(right: kSpace2),
            child: GestureDetector(
              onTap: () => onSelect(status),
              child: AnimatedContainer(
                duration: kDurationFast,
                padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 5),
                decoration: BoxDecoration(
                  color: isActive ? status.color : kColorSurfaceSunken,
                  borderRadius: kRadiusPill,
                  border: Border.all(
                    color: isActive ? status.color : kColorBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      status.icon,
                      size: 12,
                      color: isActive ? Colors.white : status.color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${status.label} ($count)',
                      style: kStyleCaption.copyWith(
                        color: isActive ? Colors.white : kColorInk,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Filter chips ─────────────────────────────────────────────────────────────

class _FilterChips extends StatelessWidget {
  const _FilterChips({
    required this.selected,
    required this.onSelect,
    required this.items,
  });

  final TravelItemType? selected;
  final ValueChanged<TravelItemType> onSelect;
  // Full unfiltered list — used to compute per-type counts and hide empty types.
  final List<TravelItem> items;

  @override
  Widget build(BuildContext context) {
    final presentTypes = TravelItemType.values
        .where((t) => items.any((i) => i.type == t))
        .toList();
    if (presentTypes.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
        children: presentTypes.map((type) {
          final isActive = selected == type;
          final count = items.where((i) => i.type == type).length;
          return Padding(
            padding: const EdgeInsets.only(right: kSpace2),
            child: _FilterChip(
              type: type,
              isActive: isActive,
              count: count,
              onTap: () => onSelect(type),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.type,
    required this.isActive,
    required this.count,
    required this.onTap,
  });
  final TravelItemType type;
  final bool isActive;
  final int count;
  final VoidCallback onTap;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.type.color;
    final softColor = widget.type.softColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kDurationFast,
          curve: kEaseStandard,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isActive ? color : _hovered ? softColor : kColorPaper,
            borderRadius: kRadiusPill,
            border: Border.all(
              color: widget.isActive ? color : kColorBorder,
              width: widget.isActive ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.type.icon,
                size: 14,
                color: widget.isActive ? Colors.white : color,
              ),
              const SizedBox(width: 5),
              Text(
                '${widget.type.label} (${widget.count})',
                style: kStyleCaption.copyWith(
                  color: widget.isActive ? Colors.white : kColorInk,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
