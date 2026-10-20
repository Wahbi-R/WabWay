import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../data/connection_data.dart' show EntityType;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/async_screen_mixin.dart';
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
import '../core/text_utils.dart';
import 'accommodations/add_accommodation_sheet.dart';
import '../core/places/listing_parser.dart';
import '../data/accommodation_data.dart' show AccommodationSource;
import '../core/supabase/connection_service.dart';
import '../data/connection_data.dart';

class TravelScreen extends ConsumerStatefulWidget {
  const TravelScreen({super.key});

  @override
  ConsumerState<TravelScreen> createState() => _TravelScreenState();
}

class _TravelScreenState extends ConsumerState<TravelScreen> with AsyncScreenMixin {
  final List<TravelItem> _items = [];
  final List<TripDocument> _docs = [];
  final List<TripDay> _days = [];

  String _activeTripId = '';
  String _userId = '';

  RealtimeChannel? _channel;
  Timer? _debounce;

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
    final q = foldForSearch(_search.trim());
    if (q.isNotEmpty) {
      bool m(String? s) => searchMatches(s, q);
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
    // Saved elsewhere (Read booking, Import) while this tab stayed alive.
    reloadOnChanges(const [EntityType.travel, EntityType.doc], () => _loadAll(silent: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _userId = supabase.auth.currentUser?.id ?? '';
      _activeTripId = ref.read(activeTripIdProvider);
      _loadAll();
      if (_activeTripId.isNotEmpty) _subscribeRealtime(_activeTripId);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reloadWhenShown(() => _loadAll(silent: true));
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

  // ─── Data loading ─────────────────────────────────────────────────────────────

  // silent=false shows a full loading spinner (first load / retry);
  // silent=true silently refreshes in the background after a realtime event.
  Future<void> _loadAll({bool silent = false}) async {
    if (_activeTripId.isEmpty) return;
    final gen = beginLoad(silent: silent);
    if (!silent) setState(() { _items.clear(); _docs.clear(); _days.clear(); });

    if (!silent) {
      final cached = await Future.wait([
        TravelService.loadFromCache(_activeTripId),
        DocService.loadDocumentsFromCache(_activeTripId),
        PlanService.loadFromCache(_activeTripId),
      ]);
      final cachedItems = cached[0] as List<TravelItem>?;
      final cachedDocs  = cached[1] as List<TripDocument>?;
      final cachedDays  = cached[2] as List<TripDay>?;
      if (isStale(gen)) return;
      if (cachedItems != null) {
        commitLoad(gen, () {
          _items..clear()..addAll(withoutPendingDeletes(cachedItems, (i) => i.id));
          _docs..clear()..addAll(cachedDocs ?? []);
          _days..clear()..addAll(cachedDays ?? []);
        });
        if (isStale(gen)) return;
        unawaited(_loadAll(silent: true));
        return;
      }
    }

    try {
      final results = await Future.wait([
        TravelService.loadItems(_activeTripId),
        DocService.loadDocuments(_activeTripId),
        PlanService.loadAll(_activeTripId),
      ]);
      final items = results[0] as List<TravelItem>;
      final docs  = results[1] as List<TripDocument>;
      final days  = results[2] as List<TripDay>;
      commitLoad(gen, () {
        _items..clear()..addAll(withoutPendingDeletes(items, (i) => i.id));
        _docs..clear()..addAll(docs);
        _days..clear()..addAll(days);
      });
    } catch (e) {
      if (silent || _items.isNotEmpty) {
        failLoad(gen, silent: true);
      } else {
        failLoad(gen, message: e.toString());
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
    setState(() {
      final idx = _items.indexWhere((i) => i.id == updated.id);
      if (idx != -1) _items[idx] = updated;
      _selectedId = updated.id;
    });
    // Attached documents are saved by the item's Documents section itself.
    TravelService.updateItem(updated).catchError((_) => _loadAll(silent: true));
  }

  Future<void> _addItem(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final formItem = await showAddTravelSheet(context, docs: _docs);
    if (formItem == null || !mounted) return;
    if (_activeTripId.isEmpty || _userId.isEmpty) return;

    try {
      final created = await TravelService.createFromDraft(
        formItem, tripId: _activeTripId, createdBy: _userId);
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
      _offerStayAfter(created);
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

  /// After a flight/train/bus/ferry, offer the stay at the other end —
  /// check-in pre-filled from the arrival date, and the new stay linked to
  /// this travel item through the shared trip_connections ("Connected").
  void _offerStayAfter(TravelItem t) {
    const legs = {TravelItemType.flight, TravelItemType.train, TravelItemType.bus, TravelItemType.ferry};
    final arrival = t.endDate ?? t.date;
    if (!legs.contains(t.type) || arrival == null || !mounted) return;
    showWabwaySnack(
      context,
      'Where are you staying after ${t.title}?',
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Add stay',
        textColor: Colors.white,
        onPressed: () async {
          final r = await showAddStaySheet(
            context,
            tripId: _activeTripId,
            userId: _userId,
            prefilled: ListingResult(
              name: '',
              source: AccommodationSource.other,
              checkIn: arrival,
            ),
          );
          final stay = r?.accommodation;
          if (stay == null) return;
          try {
            await ConnectionService.add(
              tripId: _activeTripId,
              userId: _userId,
              typeA: EntityType.travel,
              idA: t.id,
              typeB: EntityType.stay,
              idB: stay.id,
            );
            if (mounted) showWabwaySnack(context, 'Stay added and linked to ${t.title}');
          } catch (_) {}
        },
      ),
    );
  }

  void _exportCsv() {
    final items = _filtered;
    if (items.isEmpty) return;
    if (kIsWeb) {
      showWabwaySnack(context, 'Export is not supported on web.');
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
        if (next.isNotEmpty) _subscribeRealtime(next);
      }
    });
    if (loading) return const WabwayLoadingScaffold();

    if (error) {
      return Scaffold(
        backgroundColor: kColorCream,
        body: Center(
          child: WabwayEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Could not load travel',
            description: errorMessage,
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final base = isDesktop ? _buildDesktop(context) : _buildMobile(context);
    if (!offline) return base;
    return Stack(
      children: [
        base,
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: OfflineBanner(onRetry: _loadAll),
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
                      _typeFilterStrip(),
                      _statusFilterStrip(),
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
    return Center(
      child: WabwayEmptyState(
        icon: Icons.flight_rounded,
        title: 'Select a travel item',
        description: 'Pick a flight, train or other booking from the list to see details.',
        action: WabwayButton(
          label: 'Add travel item',
          icon: Icons.add_rounded,
          size: WabwayButtonSize.sm,
          variant: WabwayButtonVariant.ghost,
          onPressed: () => _addItem(context),
        ),
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
          _typeFilterStrip(),
          _statusFilterStrip(),
          Expanded(child: _buildList(desktop: false)),
        ],
      ),
      floatingActionButton: WabwayAddFab(heroTag: 'travel_fab', label: 'Add travel', onPressed: () => _addItem(context)),
    );
  }

  // Filters use the shared WabwayFilterStrip (counts, hidden when < 2 kinds).
  Widget _typeFilterStrip() => WabwayFilterStrip<TravelItemType>(
        selected: _filter,
        allLabel: null,
        options: [
          for (final t in TravelItemType.values)
            if (_items.any((i) => i.type == t))
              (value: t, label: t.label, count: _items.where((i) => i.type == t).length),
        ],
        onChanged: (t) => setState(() { _filter = t; _selectedId = null; }),
      );

  Widget _statusFilterStrip() => WabwayFilterStrip<TravelBookingStatus>(
        selected: _statusFilter,
        allLabel: null,
        options: [
          for (final st in TravelBookingStatus.values)
            if (_items.any((i) => i.status == st))
              (value: st, label: st.label, count: _items.where((i) => i.status == st).length),
        ],
        onChanged: (st) => setState(() { _statusFilter = st; _selectedId = null; }),
      );

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
                  WabwayEmptyState(
                    icon: Icons.flight_rounded,
                    title: 'No travel items yet',
                    description:
                        'Add flights, trains, buses, ferries and car hire here.',
                    action: WabwayButton(
                      label: 'Add travel item',
                      icon: Icons.add_rounded,
                      onPressed: () => _addItem(context),
                    ),
                  ),
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
            final at = _items.indexWhere((x) => x.id == item.id);
            unawaited(deleteWithUndo(
              ctx,
              id: item.id,
              message: '"${item.title}" removed.',
              hide: () => setState(() {
                _items.removeWhere((x) => x.id == item.id);
                if (_selectedId == item.id) _selectedId = null;
              }),
              restore: () {
                if (mounted) setState(() => _items.insert(at.clamp(0, _items.length), item));
              },
              commit: () => TravelService.deleteItem(item.id),
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
