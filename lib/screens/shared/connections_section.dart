import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/accommodation_service.dart';
import '../../core/supabase/connection_service.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/links_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../core/supabase/travel_service.dart';
import '../../data/accommodation_data.dart';
import '../../data/connection_data.dart';
import '../../data/docs_data.dart';
import '../../data/links_data.dart';
import '../../data/plan_data.dart';
import '../../data/spot_data.dart';
import '../../data/travel_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// ─── Public widget ─────────────────────────────────────────────────────────────
//
// Drop this into any detail screen. Pass:
//   entityType  — what kind of entity this screen is showing
//   entityId    — the entity's UUID
//   tripId      — active trip id
//   days        — trip days (needed for plan-item name lookup)
//
// The widget loads its own connections and handles add/remove.

class ConnectionsSection extends ConsumerStatefulWidget {
  const ConnectionsSection({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.tripId,
    this.days = const [],
  });

  final EntityType    entityType;
  final String        entityId;
  final String        tripId;
  final List<TripDay> days;

  @override
  ConsumerState<ConnectionsSection> createState() =>
      _ConnectionsSectionState();
}

class _ConnectionsSectionState extends ConsumerState<ConnectionsSection> {
  List<TripConnection> _connections = [];
  bool _loading = true;

  // Cache of entity names keyed by id — populated lazily as we resolve.
  final Map<String, String> _nameCache = {};

  // Cached stays list to avoid re-fetching on every chip tap.
  List<Accommodation>? _staysCache;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final conns =
        await ConnectionService.fetchForEntity(widget.entityId);
    if (!mounted) return;
    await _resolveNames(conns);
    if (!mounted) return;
    setState(() {
      _connections = conns;
      _loading     = false;
    });
  }

  // Resolve display names for all peer entities not yet in cache.
  Future<void> _resolveNames(List<TripConnection> conns) async {
    final toResolve = <MapEntry<EntityType, String>>[];
    for (final c in conns) {
      final type = c.peerType(widget.entityId);
      final id   = c.peerId(widget.entityId);
      if (!_nameCache.containsKey(id)) {
        toResolve.add(MapEntry(type, id));
      }
    }
    if (toResolve.isEmpty) return;

    // Batch by type.
    final byType = <EntityType, List<String>>{};
    for (final e in toResolve) {
      byType.putIfAbsent(e.key, () => []).add(e.value);
    }

    final tripId = widget.tripId;

    await Future.wait(byType.entries.map((entry) async {
      final type = entry.key;
      final ids  = entry.value.toSet();
      switch (type) {
        case EntityType.spot:
          final spots = await SpotService.loadSpots(tripId)
              .catchError((_) => <Spot>[]);
          for (final s in spots) {
            if (ids.contains(s.id)) _nameCache[s.id] = s.name;
          }
          break;
        case EntityType.travel:
          final items = await TravelService.loadItems(tripId)
              .catchError((_) => <TravelItem>[]);
          for (final i in items) {
            if (ids.contains(i.id)) _nameCache[i.id] = i.title;
          }
          break;
        case EntityType.stay:
          final stays = _staysCache ??
              await AccommodationService.loadAll(tripId)
                  .catchError((_) => <Accommodation>[]);
          if (stays.isNotEmpty) _staysCache = stays;
          for (final s in stays) {
            if (ids.contains(s.id)) _nameCache[s.id] = s.name;
          }
          break;
        case EntityType.doc:
          final docs = await DocService.loadDocuments(tripId)
              .catchError((_) => <TripDocument>[]);
          for (final d in docs) {
            if (ids.contains(d.id)) _nameCache[d.id] = d.title;
          }
          break;
        case EntityType.link:
          final links = await LinksService.loadLinks(tripId)
              .catchError((_) => <TripLink>[]);
          for (final l in links) {
            if (ids.contains(l.id)) _nameCache[l.id] = l.title;
          }
          break;
        case EntityType.planItem:
          for (final day in widget.days) {
            for (final item in day.items) {
              if (ids.contains(item.id)) _nameCache[item.id] = item.title;
            }
          }
          break;
      }
    }));
  }

  bool _canNavigate(EntityType type) => type == EntityType.stay;

  Future<void> _navigate(BuildContext context, ResolvedConnection r) async {
    final tripId = widget.tripId;
    if (r.peerType == EntityType.stay) {
      final cached = _staysCache ?? await AccommodationService.loadFromCache(tripId);
      final allStays = (cached != null && cached.isNotEmpty)
          ? cached
          : await AccommodationService.loadAll(tripId).catchError((_) => <Accommodation>[]);
      if (allStays.isNotEmpty) _staysCache = allStays;
      final stay = allStays.where((s) => s.id == r.peerId).firstOrNull;
      if (!mounted || stay == null) return;
      _showStayDetailSheet(context, stay);
    }
  }

  void _showStayDetailSheet(BuildContext context, Accommodation stay) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StayDetailSheet(stay: stay),
    );
  }

  Future<void> _remove(TripConnection c) async {
    setState(() => _connections.remove(c));
    await ConnectionService.remove(c.id);
  }

  Future<void> _addConnection() async {
    final tripId = widget.tripId;
    final userId = ref.read(profileProvider)?.id ?? '';

    // Load all entities for the picker (excluding the current entity type
    // only if it makes no sense to link to itself — allow same-type links).
    final result = await showModalBottomSheet<_PickResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ConnectionPickerSheet(
        tripId:         tripId,
        myEntityType:   widget.entityType,
        myEntityId:     widget.entityId,
        days:           widget.days,
        alreadyLinked:  _connections.map((c) => c.peerId(widget.entityId)).toSet(),
      ),
    );
    if (result == null || !mounted) return;

    final conn = await ConnectionService.add(
      tripId: tripId,
      userId: userId,
      typeA:  widget.entityType,
      idA:    widget.entityId,
      typeB:  result.type,
      idB:    result.id,
    );
    _nameCache[result.id] = result.name;
    setState(() => _connections.add(conn));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: kSpace4),
        child: Center(
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2))),
      );
    }

    final resolved = _connections.map((c) {
      final peerId   = c.peerId(widget.entityId);
      final peerType = c.peerType(widget.entityId);
      final name     = _nameCache[peerId] ?? '…';
      return ResolvedConnection(
          connection: c,
          peerType:   peerType,
          peerId:     peerId,
          peerName:   name);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Connected', style: kStyleOverline),
            const Spacer(),
            GestureDetector(
              onTap: _addConnection,
              child: Row(
                children: [
                  Icon(Icons.add_rounded,
                      size: 14, color: kColorPrimary),
                  const SizedBox(width: 2),
                  Text('Add',
                      style: kStyleCaption.copyWith(
                          color: kColorPrimary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpace2),
        if (resolved.isEmpty)
          Text(
            'No connections yet. Tap Add to link this to a spot, document, travel item, or more.',
            style: kStyleCaption.copyWith(color: kColorInkSoft),
          )
        else
          Wrap(
            spacing: kSpace2,
            runSpacing: kSpace2,
            children: resolved
                .map((r) => _ConnectionChip(
                      resolved: r,
                      onRemove: () => _remove(r.connection),
                      onTap: _canNavigate(r.peerType)
                          ? () => _navigate(context, r)
                          : null,
                    ))
                .toList(),
          ),
      ],
    );
  }
}

// ─── Connection chip ──────────────────────────────────────────────────────────

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip(
      {required this.resolved, required this.onRemove, this.onTap});
  final ResolvedConnection resolved;
  final VoidCallback        onRemove;
  final VoidCallback?       onTap;

  @override
  Widget build(BuildContext context) {
    final type = resolved.peerType;
    final labelArea = GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 8, top: 5, bottom: 5, right: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(type.icon, size: 12, color: onTap != null ? kColorPrimary : kColorInkSoft),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                resolved.peerName,
                style: kStyleCaption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: onTap != null ? kColorPrimary : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusPill,
        border: Border.all(color: onTap != null ? kColorPrimary.withValues(alpha: 0.35) : kColorBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          labelArea,
          GestureDetector(
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.only(right: 6, top: 5, bottom: 5),
              child: Icon(Icons.close_rounded, size: 14, color: kColorInkSoft),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Picker sheet ─────────────────────────────────────────────────────────────

class _PickResult {
  const _PickResult(
      {required this.type, required this.id, required this.name});
  final EntityType type;
  final String     id;
  final String     name;
}

class _ConnectionPickerSheet extends StatefulWidget {
  const _ConnectionPickerSheet({
    required this.tripId,
    required this.myEntityType,
    required this.myEntityId,
    required this.days,
    required this.alreadyLinked,
  });

  final String        tripId;
  final EntityType    myEntityType;
  final String        myEntityId;
  final List<TripDay> days;
  final Set<String>   alreadyLinked;

  @override
  State<_ConnectionPickerSheet> createState() =>
      _ConnectionPickerSheetState();
}

class _ConnectionPickerSheetState
    extends State<_ConnectionPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _loading = true;

  List<Spot>          _spots  = [];
  List<TravelItem>    _travel = [];
  List<Accommodation> _stays  = [];
  List<TripDocument>  _docs   = [];
  List<TripLink>      _links  = [];

  // Tab order — exclude self-type to reduce noise.
  List<EntityType> get _tabTypes => EntityType.values
      .where((t) => t != widget.myEntityType)
      .toList();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabTypes.length, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final tid = widget.tripId;
    try {
      final results = await Future.wait([
        SpotService.loadSpots(tid),
        TravelService.loadItems(tid),
        AccommodationService.loadAll(tid).catchError((_) => <Accommodation>[]),
        DocService.loadDocuments(tid),
        LinksService.loadLinks(tid),
      ]);
      if (!mounted) return;
      setState(() {
        _spots  = results[0] as List<Spot>;
        _travel = results[1] as List<TravelItem>;
        _stays  = results[2] as List<Accommodation>;
        _docs   = results[3] as List<TripDocument>;
        _links  = results[4] as List<TripLink>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<({String id, String name})> _itemsFor(EntityType t) {
    switch (t) {
      case EntityType.spot:
        return _spots
            .where((s) => s.id != widget.myEntityId)
            .map((s) => (id: s.id, name: s.name))
            .toList();
      case EntityType.travel:
        return _travel
            .where((i) => i.id != widget.myEntityId)
            .map((i) => (id: i.id, name: i.title))
            .toList();
      case EntityType.stay:
        return _stays
            .where((s) => s.id != widget.myEntityId)
            .map((s) => (id: s.id, name: s.name))
            .toList();
      case EntityType.doc:
        return _docs
            .where((d) => d.id != widget.myEntityId)
            .map((d) => (id: d.id, name: d.title))
            .toList();
      case EntityType.link:
        return _links
            .where((l) => l.id != widget.myEntityId)
            .map((l) => (id: l.id, name: l.title))
            .toList();
      case EntityType.planItem:
        return [
          for (final day in widget.days)
            for (final item in day.sortedItems)
              if (item.id != widget.myEntityId)
                (id: item.id, name: '${item.title} (Day ${day.dayNumber})')
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final types = _tabTypes;

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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  kSpace4, kSpace2, kSpace4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WabwayDragHandle(),
                  const SizedBox(height: kSpace2),
                  Text('Link to…', style: kStyleTitle),
                  const SizedBox(height: kSpace3),
                  TabBar(
                    controller: _tabs,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelStyle: kStyleCaptionMedium,
                    unselectedLabelStyle: kStyleCaption,
                    labelColor: kColorPrimary,
                    unselectedLabelColor: kColorInkSoft,
                    indicatorColor: kColorPrimary,
                    dividerColor: kColorBorder,
                    tabs: types
                        .map((t) => Tab(text: t.pluralLabel))
                        .toList(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabs,
                      children: types.map((type) {
                        final items = _itemsFor(type);
                        if (items.isEmpty) {
                          return Center(
                            child: Text(
                              'No ${type.pluralLabel.toLowerCase()} in this trip.',
                              style: kStyleCaption.copyWith(
                                  color: kColorInkSoft),
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: ctrl,
                          padding: const EdgeInsets.symmetric(
                              vertical: kSpace2),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: kSpace4),
                          itemBuilder: (_, i) {
                            final item    = items[i];
                            final linked  = widget.alreadyLinked
                                .contains(item.id);
                            return ListTile(
                              leading: Icon(type.icon,
                                  size: 18,
                                  color: linked
                                      ? kColorSuccess
                                      : kColorInkSoft),
                              title: Text(item.name,
                                  style: kStyleBody.copyWith(
                                      color: linked
                                          ? kColorInkSoft
                                          : kColorInk)),
                              trailing: linked
                                  ? Icon(Icons.check_circle_rounded,
                                      size: 16,
                                      color: kColorSuccess)
                                  : null,
                              onTap: linked
                                  ? null
                                  : () => Navigator.pop(
                                        context,
                                        _PickResult(
                                          type: type,
                                          id:   item.id,
                                          name: item.name,
                                        ),
                                      ),
                            );
                          },
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stay detail sheet ────────────────────────────────────────────────────────

class _StayDetailSheet extends StatelessWidget {
  const _StayDetailSheet({required this.stay});
  final Accommodation stay;

  @override
  Widget build(BuildContext context) {
    String? dateRange;
    if (stay.checkIn != null && stay.checkOut != null) {
      dateRange = '${fmtDate(stay.checkIn!)} – ${fmtDate(stay.checkOut!)}';
    }
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.35,
      maxChildSize: 0.85,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: kColorBorder, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: ItineraryItemType.stay.softColor, borderRadius: kRadiusMd),
                child: Icon(stay.source?.icon ?? Icons.hotel_rounded, size: 20, color: ItineraryItemType.stay.color),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stay.name, style: kStyleTitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (stay.source != null)
                    Text(stay.source!.label, style: kStyleCaption.copyWith(color: kColorInkSoft)),
                ],
              )),
            ]),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            if (stay.city.isNotEmpty) _row(Icons.location_city_rounded, stay.city),
            if (stay.address != null) _row(Icons.place_rounded, stay.address!),
            if (dateRange != null) _row(Icons.calendar_today_rounded, dateRange),
            _row(Icons.info_outline_rounded, stay.status.label),
            if (stay.notes != null && stay.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(stay.notes!, style: kStyleBody.copyWith(color: kColorInkSoft)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Icon(icon, size: 16, color: kColorInkSoft),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: kStyleBody)),
    ]),
  );
}
