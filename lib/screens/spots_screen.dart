import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/accommodation_service.dart';
import '../core/supabase/client.dart';
import '../core/supabase/doc_service.dart';
import '../core/supabase/spot_service.dart';
import '../data/accommodation_data.dart';
import '../data/docs_data.dart';
import '../data/spot_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'package:latlong2/latlong.dart';
import 'spots/spot_list_tile.dart';
import 'spots/spot_detail.dart';
import 'spots/add_spot_sheet.dart';
import 'map_screen.dart';

// Sort modes available on the spots list. Applied after filters and search.
enum _SpotSort {
  newest,      // DB insertion order — default
  alphabetical, // A→Z by spot name
  mostVoted,   // highest must-do vote count first, then total votes
  byCity,      // grouped by city name A→Z, then spot name within city
}

class SpotsScreen extends ConsumerStatefulWidget {
  const SpotsScreen({super.key});

  @override
  ConsumerState<SpotsScreen> createState() => _SpotsScreenState();
}

class _SpotsScreenState extends ConsumerState<SpotsScreen> {
  List<Spot> _spots = [];
  List<TripDocument> _docs = [];
  List<Accommodation> _stays = [];
  Map<String, VoteType> _myVotes = {};
  bool _loading = true;
  bool _error = false;
  bool _offline = false;

  String? _activeTripId;
  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;
  int _loadGen = 0;
  // Tracks spots for which we've already kicked off a thumbnail fetch this session.
  // Without this, every silent reload would re-request images that already failed.

  String? _selectedId;
  SpotCategory? _filterCategory;
  Set<SpotStatus> _filterStatuses = {};
  String? _filterCity;
  String _searchQuery = '';
  bool _showSearch = false;
  _SpotSort _sortBy = _SpotSort.newest;
  final _searchCtrl = TextEditingController();

  // Multi-select / bulk-delete
  bool _selectionMode = false;
  Set<String> _selectedIds = {};

  int get _advancedFilterCount =>
      _filterStatuses.length + (_filterCity != null ? 1 : 0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeTripId = ref.read(activeTripIdProvider);
      _loadSpots();
      _subscribeRealtime(_activeTripId!);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _realtimeChannel?.unsubscribe();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _subscribeRealtime(String tripId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supabase
        .channel('spots-all-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'spots',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => _scheduleReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'spot_votes',
          callback: (_) => _scheduleReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'spot_comments',
          callback: (_) => _scheduleReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accommodations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => _scheduleReload(),
        )
        .subscribe();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadSpots(silent: true);
    });
  }

  Future<void> _loadSpots({bool silent = false}) async {
    final tripId = _activeTripId;
    if (tripId == null) return;
    final gen = ++_loadGen;
    if (!silent) setState(() { _loading = true; _error = false; _offline = false; });

    if (!silent) {
      final cachedSpots = await SpotService.loadSpotsFromCache(tripId);
      final cachedDocs  = await DocService.loadDocumentsFromCache(tripId);
      if (!mounted || gen != _loadGen) return;
      if (cachedSpots != null) {
        setState(() {
          _spots   = cachedSpots;
          _docs    = cachedDocs ?? [];
          _stays   = [];
          _myVotes = {};
          _loading = false;
        });
      }
    }

    try {
      final spotsFuture = SpotService.loadSpots(tripId);
      final docsFuture  = DocService.loadDocuments(tripId);
      // Accommodations fetched concurrently but caught separately so a transient
      // failure doesn't prevent spots from loading.
      final staysFuture = AccommodationService.loadAll(tripId)
          .catchError((_) => <Accommodation>[]);
      final spots = await spotsFuture;
      final docs  = await docsFuture;
      final stays = await staysFuture;
      if (!mounted || gen != _loadGen) return;

      final myId = supabase.auth.currentUser?.id;
      final myVotes = <String, VoteType>{};
      if (myId != null) {
        for (final spot in spots) {
          for (final type in VoteType.values) {
            if (spot.votes.voters(type).contains(myId)) {
              myVotes[spot.id] = type;
              break;
            }
          }
        }
      }

      setState(() {
        _spots = spots;
        _docs = docs;
        _stays = stays;
        _myVotes = myVotes;
        _loading = false;
        _offline = false;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      if (silent) { setState(() => _offline = true); return; }
      if (_spots.isEmpty) {
        setState(() { _loading = false; _error = true; });
      } else {
        setState(() { _loading = false; _offline = true; });
      }
    }
  }

  // Fired after every successful load. Kicks off background Wikipedia lookups
  // for spots that have no image yet. Each lookup is fire-and-forget — results
  // stream in over ~1-2 seconds and update the list row by row.
  List<Spot> get _filtered {
    final list = _spots.where((s) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.area.toLowerCase().contains(q);
      final matchesCat    = _filterCategory == null || s.category == _filterCategory;
      final matchesStatus = _filterStatuses.isEmpty || _filterStatuses.contains(s.status);
      final matchesCity   = _filterCity == null ||
          s.city.toLowerCase() == _filterCity!.toLowerCase();
      return matchesSearch && matchesCat && matchesStatus && matchesCity;
    }).toList();

    switch (_sortBy) {
      case _SpotSort.alphabetical:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _SpotSort.mostVoted:
        // Sort by must-do votes first, then total votes as tiebreaker
        list.sort((a, b) {
          final aMust = a.votes.voters(VoteType.mustDo).length;
          final bMust = b.votes.voters(VoteType.mustDo).length;
          if (bMust != aMust) return bMust.compareTo(aMust);
          final aTotal = VoteType.values.fold(0, (sum, v) => sum + a.votes.voters(v).length);
          final bTotal = VoteType.values.fold(0, (sum, v) => sum + b.votes.voters(v).length);
          return bTotal.compareTo(aTotal);
        });
      case _SpotSort.byCity:
        list.sort((a, b) {
          final cmp = a.city.toLowerCase().compareTo(b.city.toLowerCase());
          if (cmp != 0) return cmp;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      case _SpotSort.newest:
        break; // _spots is already in newest-first order (insert at index 0)
    }

    return list;
  }

  Set<String> get _availableCities {
    final seen = <String>{};
    for (final s in _spots) {
      if (s.city.isNotEmpty) seen.add(s.city);
    }
    return seen;
  }

  Spot? get _selected =>
      _selectedId == null ? null : _spots.where((s) => s.id == _selectedId).firstOrNull;

  bool _canDelete(Spot spot) {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return false;
    if (spot.addedById == myId) return true;
    return ref.read(tripMembersProvider).any((m) => m.userId == myId && m.isOwner);
  }

  // ─── Mutations ───────────────────────────────────────────────────────────────

  Future<void> _addSpot(BuildContext context) async {
    final tripId = _activeTripId!;
    final userId = ref.read(profileProvider)?.id ?? '';
    final spot = await showAddSpotSheet(context, tripId: tripId, userId: userId);
    if (spot != null && mounted) {
      setState(() {
        _spots.insert(0, spot);
        _selectedId = spot.id;
      });
    }
  }

  Future<void> _onVote(String spotId, VoteType? type) async {
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    // Optimistic update
    setState(() {
      if (type == null) {
        _myVotes.remove(spotId);
      } else {
        _myVotes[spotId] = type;
      }
      final idx = _spots.indexWhere((s) => s.id == spotId);
      if (idx != -1) {
        _spots[idx] = _spots[idx].copyWith(
          votes: _spots[idx].votes.copyWithVote(myId, type),
        );
      }
    });

    try {
      if (type == null) {
        await SpotService.deleteVote(spotId: spotId, userId: myId);
      } else {
        await SpotService.upsertVote(spotId: spotId, userId: myId, vote: type);
      }
    } catch (_) {
      // Revert on failure
      await _loadSpots();
    }
  }

  void _onEditSpot(Spot updated) {
    setState(() {
      final idx = _spots.indexWhere((s) => s.id == updated.id);
      if (idx != -1) _spots[idx] = updated;
    });
  }

  Future<void> _deleteSpot(String spotId) async {
    try {
      await SpotService.deleteSpot(spotId);
      if (!mounted) return;
      setState(() {
        _spots.removeWhere((s) => s.id == spotId);
        if (_selectedId == spotId) _selectedId = null;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not delete spot.', style: kStyleBody.copyWith(color: Colors.white)),
            backgroundColor: kColorDanger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── Multi-select ────────────────────────────────────────────────────────────

  void _enterSelectionMode(String spotId) {
    setState(() {
      _selectionMode = true;
      _selectedIds = {spotId};
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedIds = {};
    });
  }

  void _toggleSelection(String spotId) {
    setState(() {
      if (_selectedIds.contains(spotId)) {
        _selectedIds = {..._selectedIds}..remove(spotId);
      } else {
        _selectedIds = {..._selectedIds, spotId};
      }
      if (_selectedIds.isEmpty) {
        _selectionMode = false;
      }
    });
  }

  Future<void> _deleteSelected() async {
    final ids = List<String>.from(_selectedIds);
    final deletable = ids.where((id) {
      final spot = _spots.where((s) => s.id == id).firstOrNull;
      return spot != null && _canDelete(spot);
    }).toList();

    final count = deletable.length;
    final skipped = ids.length - count;
    if (count == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("You don't have permission to delete the selected spots.",
              style: kStyleBody.copyWith(color: Colors.white)),
          backgroundColor: kColorDanger,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $count ${count == 1 ? 'spot' : 'spots'}?',
            style: kStyleBodyBold),
        content: Text(
          skipped > 0
              ? 'This will permanently delete $count ${count == 1 ? 'spot' : 'spots'}. ($skipped skipped — you don\'t have permission to delete those.)'
              : 'This will permanently delete $count ${count == 1 ? 'spot' : 'spots'}. This can\'t be undone.',
          style: kStyleBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: kColorDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    int failed = 0;
    for (final id in deletable) {
      try {
        await SpotService.deleteSpot(id);
        if (mounted) {
          setState(() {
            _spots.removeWhere((s) => s.id == id);
            if (_selectedId == id) _selectedId = null;
          });
        }
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    _exitSelectionMode();
    if (failed > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$failed ${failed == 1 ? 'spot' : 'spots'} could not be deleted.',
            style: kStyleBody.copyWith(color: Colors.white)),
        backgroundColor: kColorDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  // ─── Export ──────────────────────────────────────────────────────────────────

  // Shares the currently visible spots (after filter + sort) as a CSV.
  // Each row: Name, City, Area, Country, Category, Status, Address, Maps URL, Notes.
  void _exportSpots() {
    final visible = _filtered;
    if (visible.isEmpty) return;

    final tripName = ref.read(activeTripProvider)?.name ?? 'Trip';

    final buf = StringBuffer();
    buf.writeln('Name,City,Area,Country,Category,Status,Address,Maps URL,Notes');
    for (final s in visible) {
      buf.writeln([
        _csvCell(s.name),
        _csvCell(s.city),
        _csvCell(s.area),
        _csvCell(s.country ?? ''),
        _csvCell(s.category.label),
        _csvCell(s.status.label),
        _csvCell(s.address ?? ''),
        _csvCell(s.mapsUrl ?? ''),
        _csvCell(s.notes ?? ''),
      ].join(','));
    }

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export is not supported on web.',
            style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    unawaited(Share.share(buf.toString(), subject: '$tripName — Spots'));
  }

  // Wraps a CSV cell value in quotes, escaping any internal quotes.
  static String _csvCell(String v) => '"${v.replaceAll('"', '""')}"';

  // ─── Advanced filter ─────────────────────────────────────────────────────────

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<_SpotFilterResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SpotFilterSheet(
        statuses:       _filterStatuses,
        city:           _filterCity,
        availableCities: _availableCities,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _filterStatuses = result.statuses;
        _filterCity     = result.city;
      });
    }
  }

  // ─── Stay detail ─────────────────────────────────────────────────────────────

  void _openStayDetailMobile(BuildContext context, Accommodation stay) {
    final linkedSpot = stay.spotId != null
        ? _spots.where((s) => s.id == stay.spotId).firstOrNull
        : null;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StayMiniSheet(stay: stay, linkedSpot: linkedSpot),
    );
  }

  // ─── Mobile detail ────────────────────────────────────────────────────────────

  void _openDetailMobile(BuildContext context, Spot spot) {
    final docs = _docs;
    final linkedStay = _stays.where((s) => s.spotId == spot.id).firstOrNull;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpotDetailScreen(
          spot: spot,
          myVote: _myVotes[spot.id],
          onVote: (v) => _onVote(spot.id, v),
          canDelete: _canDelete(spot),
          docs: docs,
          onEdit: _onEditSpot,
          onDelete: () {
            _deleteSpot(spot.id);
            Navigator.pop(context);
          },
          linkedStay: linkedStay,
          onOpenStay: linkedStay != null
              ? () => _openStayDetailMobile(context, linkedStay)
              : null,
          onShowOnMap: spot.isMapReady
              ? () {
                  Navigator.pop(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MapScreen(
                        initialFocus: LatLng(spot.latitude!, spot.longitude!),
                      ),
                    ),
                  );
                }
              : null,
        ),
      ),
    );
  }

  // ─── Quick status from long-press ─────────────────────────────────────────────

  void _quickStatusSheet(BuildContext context, Spot spot) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WabwayDragHandle(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpace4),
              child: Text(
                spot.name,
                style: kStyleBodyBold,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: kSpace2),
            if (spot.status != SpotStatus.visited)
              WabwayActionTile(
                icon: Icons.check_circle_rounded,
                label: 'Mark as visited',
                color: kColorSuccess,
                onTap: () { Navigator.pop(ctx); _setSpotStatus(spot, SpotStatus.visited); },
              ),
            if (spot.status != SpotStatus.skipped)
              WabwayActionTile(
                icon: Icons.cancel_rounded,
                label: 'Skip this spot',
                onTap: () { Navigator.pop(ctx); _setSpotStatus(spot, SpotStatus.skipped); },
              ),
            if (spot.status == SpotStatus.visited || spot.status == SpotStatus.skipped)
              WabwayActionTile(
                icon: Icons.restart_alt_rounded,
                label: 'Reset to saved',
                onTap: () { Navigator.pop(ctx); _setSpotStatus(spot, SpotStatus.idea); },
              ),
            const SizedBox(height: kSpace4),
          ],
        ),
      ),
    );
  }

  Future<void> _setSpotStatus(Spot spot, SpotStatus status) async {
    try {
      final updated = await SpotService.updateSpot(
        spotId: spot.id,
        name: spot.name,
        city: spot.city,
        area: spot.area,
        category: spot.category,
        status: status,
        notes: spot.notes,
        mapsUrl: spot.mapsUrl,
        sourceUrl: spot.sourceUrl,
        address: spot.address,
      );
      if (mounted) _onEditSpot(updated);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _activeTripId) {
        _activeTripId = next;
        _loadSpots();
        _subscribeRealtime(next);
      }
    });
    if (_loading) return const WabwayLoadingScaffold();

    if (_error) {
      return Scaffold(
        backgroundColor: kColorCream,
        body: Center(
          child: WabwayEmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load spots',
            description: 'Check your connection and try again.',
            action: WabwayButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _loadSpots,
            ),
          ),
        ),
      );
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    Widget body = isDesktop
        ? _DesktopLayout(
            spots: _filtered,
            allSpots: _spots,
            stays: _stays,
            docs: _docs,
            selected: _selected,
            myVotes: _myVotes,
            filterCategory: _filterCategory,
            filterStatuses: _filterStatuses,
            searchQuery: _searchQuery,
            searchCtrl: _searchCtrl,
            showSearch: _showSearch,
            sortBy: _sortBy,
            canDelete: _canDelete,
            selectionMode: _selectionMode,
            selectedIds: _selectedIds,
            onSelectSpot: (s) => setState(() => _selectedId = s?.id),
            onFilterCategory: (c) => setState(() => _filterCategory = c),
            onToggleStatus: (s) => setState(() {
              if (_filterStatuses.contains(s)) {
                _filterStatuses = {..._filterStatuses}..remove(s);
              } else {
                _filterStatuses = {..._filterStatuses, s};
              }
            }),
            onSearch: (q) => setState(() => _searchQuery = q),
            onToggleSearch: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchQuery = '';
                _searchCtrl.clear();
              }
            }),
            onSortChange: (s) => setState(() => _sortBy = s),
            onExport: _exportSpots,
            onVote: _onVote,
            onDelete: _deleteSpot,
            onEdit: _onEditSpot,
            onAdd: () => _addSpot(context),
            onOpenStay: (a) => _openStayDetailMobile(context, a),
            onLongPressSpot: _enterSelectionMode,
            onToggleSelection: _toggleSelection,
            onExitSelectionMode: _exitSelectionMode,
            onDeleteSelected: _deleteSelected,
          )
        : _MobileLayout(
            spots: _filtered,
            allSpots: _spots,
            stays: _stays,
            myVotes: _myVotes,
            filterCategory: _filterCategory,
            filterStatuses: _filterStatuses,
            advancedFilterCount: _advancedFilterCount,
            searchQuery: _searchQuery,
            searchCtrl: _searchCtrl,
            showSearch: _showSearch,
            sortBy: _sortBy,
            selectionMode: _selectionMode,
            selectedIds: _selectedIds,
            onOpenSpot: (s) => _openDetailMobile(context, s),
            onOpenStay: (a) => _openStayDetailMobile(context, a),
            onLongPress: _enterSelectionMode,
            onToggleSelection: _toggleSelection,
            onExitSelectionMode: _exitSelectionMode,
            onDeleteSelected: _deleteSelected,
            onFilterCategory: (c) => setState(() => _filterCategory = c),
            onToggleStatus: (s) => setState(() {
              if (_filterStatuses.contains(s)) {
                _filterStatuses = {..._filterStatuses}..remove(s);
              } else {
                _filterStatuses = {..._filterStatuses, s};
              }
            }),
            onSearch: (q) => setState(() => _searchQuery = q),
            onToggleSearch: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchQuery = '';
                _searchCtrl.clear();
              }
            }),
            onSortChange: (s) => setState(() => _sortBy = s),
            onFilter: _openFilterSheet,
            onExport: _exportSpots,
            onAdd: () => _addSpot(context),
          );
    if (!_offline) return body;
    return Stack(
      children: [
        body,
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: OfflineBanner(onRetry: _loadSpots),
        ),
      ],
    );
  }
}

// Helper that builds a checked PopupMenuItem for the sort menu.
PopupMenuItem<_SpotSort> _sortMenuItem(
    _SpotSort value, String label, _SpotSort current) {
  return PopupMenuItem(
    value: value,
    child: Row(
      children: [
        SizedBox(
          width: 20,
          child: current == value
              ? const Icon(Icons.check_rounded, size: 16, color: kColorPrimary)
              : null,
        ),
        const SizedBox(width: kSpace2),
        Text(label),
      ],
    ),
  );
}

// ─── Mobile layout ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.spots,
    required this.allSpots,
    required this.stays,
    required this.myVotes,
    required this.filterCategory,
    required this.filterStatuses,
    required this.advancedFilterCount,
    required this.searchQuery,
    required this.searchCtrl,
    required this.showSearch,
    required this.sortBy,
    required this.selectionMode,
    required this.selectedIds,
    required this.onOpenSpot,
    required this.onOpenStay,
    required this.onLongPress,
    required this.onToggleSelection,
    required this.onExitSelectionMode,
    required this.onDeleteSelected,
    required this.onFilterCategory,
    required this.onToggleStatus,
    required this.onSearch,
    required this.onToggleSearch,
    required this.onSortChange,
    required this.onFilter,
    required this.onExport,
    required this.onAdd,
  });

  final List<Spot> spots;
  final List<Spot> allSpots;
  final List<Accommodation> stays;
  final Map<String, VoteType> myVotes;
  final SpotCategory? filterCategory;
  final Set<SpotStatus> filterStatuses;
  final int advancedFilterCount;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final bool showSearch;
  final _SpotSort sortBy;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<Spot> onOpenSpot;
  final ValueChanged<Accommodation> onOpenStay;
  final ValueChanged<String> onLongPress;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onExitSelectionMode;
  final Future<void> Function() onDeleteSelected;
  final ValueChanged<SpotCategory?> onFilterCategory;
  final ValueChanged<SpotStatus> onToggleStatus;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleSearch;
  final ValueChanged<_SpotSort> onSortChange;
  final VoidCallback onFilter;
  final VoidCallback onExport;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            leading: selectionMode
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    color: kColorInkSoft,
                    onPressed: onExitSelectionMode,
                  )
                : null,
            title: selectionMode
                ? Text(
                    '${selectedIds.length} selected',
                    style: kStyleTitle,
                  )
                : showSearch
                    ? _SearchField(controller: searchCtrl, onChanged: onSearch)
                    : Text('Spots', style: kStyleTitle),
            pinned: true,
            actions: selectionMode
                ? [
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      color: kColorDanger,
                      tooltip: 'Delete selected',
                      onPressed: selectedIds.isEmpty ? null : onDeleteSelected,
                    ),
                    const SizedBox(width: kSpace2),
                  ]
                : [
                    IconButton(
                      icon: Icon(
                        showSearch ? Icons.close_rounded : Icons.search_rounded,
                      ),
                      color: kColorInkSoft,
                      onPressed: onToggleSearch,
                    ),
                    // Share the filtered list as a CSV
                    if (!showSearch && spots.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.ios_share_rounded),
                        color: kColorInkSoft,
                        tooltip: 'Export spots as CSV',
                        onPressed: onExport,
                      ),
                    // Sort popup — icon is highlighted when a non-default sort is active
                    PopupMenuButton<_SpotSort>(
                      icon: Icon(
                        Icons.sort_rounded,
                        color: sortBy != _SpotSort.newest ? kColorPrimary : kColorInkSoft,
                      ),
                      tooltip: 'Sort',
                      onSelected: onSortChange,
                      itemBuilder: (_) => [
                        _sortMenuItem(_SpotSort.newest,       'Newest first', sortBy),
                        _sortMenuItem(_SpotSort.alphabetical, 'A – Z',        sortBy),
                        _sortMenuItem(_SpotSort.mostVoted,    'Most voted',   sortBy),
                        _sortMenuItem(_SpotSort.byCity,       'By city',      sortBy),
                      ],
                    ),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.tune_rounded),
                          color: advancedFilterCount > 0 ? kColorPrimary : kColorInkSoft,
                          onPressed: onFilter,
                        ),
                        if (advancedFilterCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: const BoxDecoration(
                                color: kColorPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '$advancedFilterCount',
                                  style: kStyleCaption.copyWith(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: kSpace2),
                  ],
          ),
          SliverToBoxAdapter(
            child: _CategoryFilterStrip(
              selected: filterCategory,
              onChanged: onFilterCategory,
              spots: allSpots,
            ),
          ),
          SliverToBoxAdapter(
            child: _StatusFilterStrip(
              allSpots: allSpots,
              filterStatuses: filterStatuses,
              onToggle: onToggleStatus,
            ),
          ),
          SliverToBoxAdapter(
            child: Builder(builder: (context) {
              final visited = spots.where((s) => s.status == SpotStatus.visited).length;
              if (visited == 0) return const SizedBox.shrink();
              return _SpotsProgressBar(visited: visited, total: spots.length);
            }),
          ),
          if (spots.isEmpty && stays.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: WabwayEmptyState(
                  icon: Icons.place_rounded,
                  title: 'No spots yet',
                  description: searchQuery.isNotEmpty
                      ? 'No spots match "$searchQuery".'
                      : 'Add the first place worth visiting.',
                  action: searchQuery.isEmpty
                      ? WabwayButton(
                          label: 'Add a spot',
                          icon: Icons.add_rounded,
                          onPressed: onAdd,
                        )
                      : null,
                ),
              ),
            )
          else if (spots.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpace4, vertical: kSpace5),
                child: Center(
                  child: Text(
                    searchQuery.isNotEmpty
                        ? 'No spots match "$searchQuery".'
                        : 'No spots yet.',
                    style: kStyleCaption.copyWith(color: kColorInkSoft),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  kSpace4, kSpace2, kSpace4, kSpace2),
              sliver: SliverList.separated(
                itemCount: spots.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: kSpace3),
                itemBuilder: (_, i) {
                  final s = spots[i];
                  return SpotListTile(
                    spot: s,
                    myVote: myVotes[s.id],
                    inSelectionMode: selectionMode,
                    checkedForDelete: selectedIds.contains(s.id),
                    onTap: selectionMode
                        ? () => onToggleSelection(s.id)
                        : () => onOpenSpot(s),
                    onLongPress: selectionMode
                        ? () => onToggleSelection(s.id)
                        : () => onLongPress(s.id),
                  );
                },
              ),
            ),
          if (stays.isNotEmpty)
            SliverToBoxAdapter(
              child: _StaysSection(stays: stays, onTap: onOpenStay),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: kSpace16)),
        ],
      ),
      floatingActionButton: selectionMode
          ? null
          : FloatingActionButton.extended(
              heroTag: 'spots_fab',
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: Text(
                'Add a spot',
                style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
              ),
            ),
    );
  }
}

// ─── Desktop layout ────────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.spots,
    required this.allSpots,
    required this.stays,
    required this.docs,
    required this.selected,
    required this.myVotes,
    required this.filterCategory,
    required this.filterStatuses,
    required this.searchQuery,
    required this.searchCtrl,
    required this.showSearch,
    required this.sortBy,
    required this.canDelete,
    required this.selectionMode,
    required this.selectedIds,
    required this.onSelectSpot,
    required this.onFilterCategory,
    required this.onToggleStatus,
    required this.onSearch,
    required this.onToggleSearch,
    required this.onSortChange,
    required this.onExport,
    required this.onVote,
    required this.onDelete,
    required this.onEdit,
    required this.onAdd,
    required this.onOpenStay,
    required this.onLongPressSpot,
    required this.onToggleSelection,
    required this.onExitSelectionMode,
    required this.onDeleteSelected,
  });

  final List<Spot> spots;
  final List<Spot> allSpots;
  final List<Accommodation> stays;
  final List<TripDocument> docs;
  final Spot? selected;
  final Map<String, VoteType> myVotes;
  final SpotCategory? filterCategory;
  final Set<SpotStatus> filterStatuses;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final bool showSearch;
  final _SpotSort sortBy;
  final bool Function(Spot) canDelete;
  final bool selectionMode;
  final Set<String> selectedIds;
  final ValueChanged<Spot?> onSelectSpot;
  final ValueChanged<SpotCategory?> onFilterCategory;
  final ValueChanged<SpotStatus> onToggleStatus;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleSearch;
  final ValueChanged<_SpotSort> onSortChange;
  final VoidCallback onExport;
  final void Function(String, VoteType?) onVote;
  final Future<void> Function(String) onDelete;
  final ValueChanged<Spot> onEdit;
  final VoidCallback onAdd;
  final ValueChanged<Accommodation> onOpenStay;
  final ValueChanged<String> onLongPressSpot;
  final ValueChanged<String> onToggleSelection;
  final VoidCallback onExitSelectionMode;
  final Future<void> Function() onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Column(
        children: [
          _DesktopTopBar(
            showSearch: showSearch,
            searchCtrl: searchCtrl,
            sortBy: sortBy,
            hasSpots: spots.isNotEmpty,
            selectionMode: selectionMode,
            selectedCount: selectedIds.length,
            onSearch: onSearch,
            onToggleSearch: onToggleSearch,
            onSortChange: onSortChange,
            onExport: onExport,
            onAdd: onAdd,
            onExitSelectionMode: onExitSelectionMode,
            onDeleteSelected: onDeleteSelected,
          ),

          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 380,
                  child: Column(
                    children: [
                      _CategoryFilterStrip(
                        selected: filterCategory,
                        onChanged: onFilterCategory,
                        spots: allSpots,
                      ),
                      _StatusFilterStrip(
                        allSpots: allSpots,
                        filterStatuses: filterStatuses,
                        onToggle: onToggleStatus,
                      ),
                      Builder(builder: (_) {
                        final visited = spots.where((s) => s.status == SpotStatus.visited).length;
                        if (visited == 0) return const SizedBox.shrink();
                        return _SpotsProgressBar(visited: visited, total: spots.length);
                      }),
                      Expanded(
                        child: (spots.isEmpty && stays.isEmpty)
                            ? Center(
                                child: WabwayEmptyState(
                                  icon: Icons.place_rounded,
                                  title: 'No spots yet',
                                  description: searchQuery.isNotEmpty
                                      ? 'No spots match "$searchQuery".'
                                      : 'Add the first place worth visiting.',
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.fromLTRB(
                                    kSpace4, kSpace2, kSpace4, kSpace4),
                                children: [
                                  if (spots.isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: kSpace4),
                                      child: Text(
                                        searchQuery.isNotEmpty
                                            ? 'No spots match "$searchQuery".'
                                            : 'No spots yet.',
                                        style: kStyleCaption.copyWith(
                                            color: kColorInkSoft),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    ...List.generate(spots.length, (i) {
                                      final s = spots[i];
                                      return Padding(
                                        padding: EdgeInsets.only(
                                            bottom: i < spots.length - 1
                                                ? kSpace3
                                                : 0),
                                        child: SpotListTile(
                                          spot: s,
                                          selected: !selectionMode && selected?.id == s.id,
                                          myVote: myVotes[s.id],
                                          inSelectionMode: selectionMode,
                                          checkedForDelete: selectedIds.contains(s.id),
                                          onTap: selectionMode
                                              ? () => onToggleSelection(s.id)
                                              : () => onSelectSpot(
                                                  selected?.id == s.id ? null : s,
                                                ),
                                          onLongPress: selectionMode
                                              ? () => onToggleSelection(s.id)
                                              : () => onLongPressSpot(s.id),
                                        ),
                                      );
                                    }),
                                  if (stays.isNotEmpty)
                                    _StaysSection(
                                        stays: stays, onTap: onOpenStay),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),

                const VerticalDivider(width: 1, thickness: 1),

                Expanded(
                  child: selected == null
                      ? _DesktopEmptyDetail(onAdd: onAdd)
                      : Builder(builder: (ctx) {
                          final linkedStay = stays
                              .where((s) => s.spotId == selected!.id)
                              .firstOrNull;
                          return SingleChildScrollView(
                            child: SpotDetailContent(
                              key: ValueKey(selected!.id),
                              spot: selected!,
                              myVote: myVotes[selected!.id],
                              onVote: (v) => onVote(selected!.id, v),
                              canDelete: canDelete(selected!),
                              docs: docs,
                              onEdit: onEdit,
                              onDelete: () => onDelete(selected!.id),
                              linkedStay: linkedStay,
                              onOpenStay: linkedStay != null
                                  ? () => onOpenStay(linkedStay)
                                  : null,
                            ),
                          );
                        }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.showSearch,
    required this.searchCtrl,
    required this.sortBy,
    required this.hasSpots,
    required this.selectionMode,
    required this.selectedCount,
    required this.onSearch,
    required this.onToggleSearch,
    required this.onSortChange,
    required this.onExport,
    required this.onAdd,
    required this.onExitSelectionMode,
    required this.onDeleteSelected,
  });

  final bool showSearch;
  final TextEditingController searchCtrl;
  final _SpotSort sortBy;
  final bool hasSpots;
  final bool selectionMode;
  final int selectedCount;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleSearch;
  final ValueChanged<_SpotSort> onSortChange;
  final VoidCallback onExport;
  final VoidCallback onAdd;
  final VoidCallback onExitSelectionMode;
  final Future<void> Function() onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kTopBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      decoration: const BoxDecoration(
        color: kColorPaper,
        border: Border(bottom: BorderSide(color: kColorBorder)),
      ),
      child: selectionMode
          ? Row(
              children: [
                WabwayIconButton(
                  icon: Icons.close_rounded,
                  label: 'Cancel',
                  onPressed: onExitSelectionMode,
                ),
                const SizedBox(width: kSpace3),
                Text('$selectedCount selected', style: kStyleTitle),
                const Spacer(),
                WabwayButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  size: WabwayButtonSize.sm,
                  variant: WabwayButtonVariant.danger,
                  onPressed: selectedCount == 0 ? null : onDeleteSelected,
                ),
              ],
            )
          : Row(
              children: [
                Text('Spots', style: kStyleTitle),
                const SizedBox(width: kSpace4),
                if (showSearch)
                  Expanded(
                    child: _SearchField(controller: searchCtrl, onChanged: onSearch),
                  )
                else
                  const Spacer(),
                WabwayIconButton(
                  icon: showSearch ? Icons.close_rounded : Icons.search_rounded,
                  label: showSearch ? 'Close search' : 'Search',
                  onPressed: onToggleSearch,
                ),
                const SizedBox(width: kSpace2),
                if (hasSpots)
                  WabwayIconButton(
                    icon: Icons.ios_share_rounded,
                    label: 'Export CSV',
                    onPressed: onExport,
                  ),
                const SizedBox(width: kSpace2),
                // Sort popup for desktop
                PopupMenuButton<_SpotSort>(
                  icon: Icon(
                    Icons.sort_rounded,
                    color: sortBy != _SpotSort.newest ? kColorPrimary : kColorInkSoft,
                    size: 20,
                  ),
                  tooltip: 'Sort',
                  onSelected: onSortChange,
                  itemBuilder: (_) => [
                    _sortMenuItem(_SpotSort.newest,       'Newest first', sortBy),
                    _sortMenuItem(_SpotSort.alphabetical, 'A – Z',        sortBy),
                    _sortMenuItem(_SpotSort.mostVoted,    'Most voted',   sortBy),
                    _sortMenuItem(_SpotSort.byCity,       'By city',      sortBy),
                  ],
                ),
                const SizedBox(width: kSpace2),
                WabwayButton(
                  label: 'Add a spot',
                  icon: Icons.add_rounded,
                  size: WabwayButtonSize.sm,
                  onPressed: onAdd,
                ),
              ],
            ),
    );
  }
}

class _DesktopEmptyDetail extends StatelessWidget {
  const _DesktopEmptyDetail({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: WabwayEmptyState(
        icon: Icons.place_rounded,
        title: 'Select a spot',
        description:
            'Pick a spot from the list to see details, vote, and leave a comment.',
        action: WabwayButton(
          label: 'Add a spot',
          icon: Icons.add_rounded,
          size: WabwayButtonSize.sm,
          variant: WabwayButtonVariant.ghost,
          onPressed: onAdd,
        ),
      ),
    );
  }
}

// ─── Shared sub-widgets ────────────────────────────────────────────────────────

class _CategoryFilterStrip extends StatefulWidget {
  const _CategoryFilterStrip({
    required this.selected,
    required this.onChanged,
    required this.spots,
  });

  final SpotCategory? selected;
  final ValueChanged<SpotCategory?> onChanged;
  // Full (unfiltered) spot list — used to show counts per category.
  final List<Spot> spots;

  @override
  State<_CategoryFilterStrip> createState() => _CategoryFilterStripState();
}

class _CategoryFilterStripState extends State<_CategoryFilterStrip> {
  final _scrollCtrl = ScrollController();
  bool _showFade = true;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final atEnd =
        pos.maxScrollExtent <= 0 || pos.pixels >= pos.maxScrollExtent - 1;
    if (atEnd == _showFade) setState(() => _showFade = !atEnd);
  }

  @override
  void dispose() {
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Stack(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView(
              controller: _scrollCtrl,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: kSpace4,
                vertical: kSpace3,
              ),
              children: [
                WabwayTag(
                  label: 'All (${widget.spots.length})',
                  selected: widget.selected == null,
                  onTap: () => widget.onChanged(null),
                ),
                ...SpotCategory.values
                    .where((c) => widget.spots.any((s) => s.category == c))
                    .map((c) {
                  final count = widget.spots.where((s) => s.category == c).length;
                  return Padding(
                    padding: const EdgeInsets.only(left: kSpace2),
                    child: WabwayTag(
                      label: '${c.label} ($count)',
                      selected: widget.selected == c,
                      onTap: () => widget.onChanged(
                        widget.selected == c ? null : c,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          if (_showFade)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: Container(
                  width: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        kColorCream.withValues(alpha: 0),
                        kColorCream,
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Status filter strip ─────────────────────────────────────────────────────

class _StatusFilterStrip extends StatelessWidget {
  const _StatusFilterStrip({
    required this.allSpots,
    required this.filterStatuses,
    required this.onToggle,
  });

  final List<Spot> allSpots;
  final Set<SpotStatus> filterStatuses;
  final ValueChanged<SpotStatus> onToggle;

  @override
  Widget build(BuildContext context) {
    final presentStatuses = SpotStatus.values
        .where((s) => allSpots.any((sp) => sp.status == s))
        .toList();
    if (presentStatuses.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
        children: presentStatuses.map((s) {
          final count = allSpots.where((sp) => sp.status == s).length;
          final selected = filterStatuses.contains(s);
          return Padding(
            padding: const EdgeInsets.only(right: kSpace2),
            child: FilterChip(
              label: Text('${s.label} ($count)'),
              selected: selected,
              onSelected: (_) => onToggle(s),
              selectedColor: kColorPrimarySoft,
              checkmarkColor: kColorPrimary,
              side: BorderSide(
                color: selected ? kColorPrimarySoftBorder : kColorBorder,
              ),
              shape: const RoundedRectangleBorder(borderRadius: kRadiusPill),
              labelStyle: kStyleCaption.copyWith(
                color: selected ? kColorPrimary : kColorInk,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Advanced filter sheet ────────────────────────────────────────────────────

class _SpotFilterResult {
  const _SpotFilterResult({required this.statuses, this.city});
  final Set<SpotStatus> statuses;
  final String? city;
}

class _SpotFilterSheet extends StatefulWidget {
  const _SpotFilterSheet({
    required this.statuses,
    required this.availableCities,
    this.city,
  });

  final Set<SpotStatus> statuses;
  final String? city;
  final Set<String> availableCities;

  @override
  State<_SpotFilterSheet> createState() => _SpotFilterSheetState();
}

class _SpotFilterSheetState extends State<_SpotFilterSheet> {
  late Set<SpotStatus> _statuses;
  String? _city;

  @override
  void initState() {
    super.initState();
    _statuses = Set.from(widget.statuses);
    _city     = widget.city;
  }

  void _toggleStatus(SpotStatus s) {
    setState(() {
      if (_statuses.contains(s)) {
        _statuses.remove(s);
      } else {
        _statuses.add(s);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _statuses.isNotEmpty || _city != null;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusSheet,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kSpace4,
          kSpace3,
          kSpace4,
          kSpace6 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WabwayDragHandle(),
            const SizedBox(height: kSpace3),
            Row(
              children: [
                Text('Filter spots', style: kStyleTitle),
                const Spacer(),
                if (hasFilters)
                  TextButton(
                    onPressed: () => setState(() {
                      _statuses = {};
                      _city     = null;
                    }),
                    child: Text('Clear all',
                        style: kStyleBodyMedium.copyWith(color: kColorDanger)),
                  ),
                WabwayIconButton(
                  icon: Icons.close_rounded,
                  label: 'Close',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: kSpace4),

            // Status
            Text('Status', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const SizedBox(height: kSpace2),
            Wrap(
              spacing: kSpace2,
              runSpacing: kSpace2,
              children: SpotStatus.values.map((s) {
                final sel = _statuses.contains(s);
                return GestureDetector(
                  onTap: () => _toggleStatus(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpace3, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? kColorPrimary : kColorSurfaceSunken,
                      borderRadius: kRadiusPill,
                      border: Border.all(
                        color: sel ? kColorPrimary : kColorBorder,
                      ),
                    ),
                    child: Text(
                      s.label,
                      style: kStyleCaption.copyWith(
                        color: sel ? Colors.white : kColorInk,
                        fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            // City
            if (widget.availableCities.isNotEmpty) ...[
              const SizedBox(height: kSpace4),
              Text('City', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              const SizedBox(height: kSpace2),
              Wrap(
                spacing: kSpace2,
                runSpacing: kSpace2,
                children: widget.availableCities.map((city) {
                  final sel = _city == city;
                  return GestureDetector(
                    onTap: () => setState(() => _city = sel ? null : city),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(
                          horizontal: kSpace3, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? kColorAccent : kColorSurfaceSunken,
                        borderRadius: kRadiusPill,
                        border: Border.all(
                          color: sel ? kColorAccent : kColorBorder,
                        ),
                      ),
                      child: Text(
                        city,
                        style: kStyleCaption.copyWith(
                          color: sel ? Colors.white : kColorInk,
                          fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: kSpace5),
            WabwayButton(
              label: 'Apply filters',
              icon: Icons.check_rounded,
              fullWidth: true,
              size: WabwayButtonSize.lg,
              onPressed: () => Navigator.pop(
                context,
                _SpotFilterResult(statuses: _statuses, city: _city),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Visited progress bar ─────────────────────────────────────────────────────

class _SpotsProgressBar extends StatelessWidget {
  const _SpotsProgressBar({required this.visited, required this.total});

  final int visited;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? visited / total : 0.0;
    final allVisited = visited == total && total > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                allVisited ? Icons.check_circle_rounded : Icons.place_rounded,
                size: 14,
                color: allVisited ? kColorSuccess : kColorInkSoft,
              ),
              const SizedBox(width: kSpace2),
              Text(
                allVisited ? 'All spots visited!' : '$visited of $total visited',
                style: kStyleCaption.copyWith(
                  color: allVisited ? kColorSuccess : kColorInkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).round()}%',
                style: kStyleCaption.copyWith(
                  color: allVisited ? kColorSuccess : kColorInkSoft,
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
              color: allVisited ? kColorSuccess : kColorPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: true,
      onChanged: onChanged,
      style: kStyleBody,
      decoration: InputDecoration(
        hintText: 'Search spots…',
        hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
        prefixIcon:
            const Icon(Icons.search_rounded, size: 18, color: kColorInkSoft),
        isDense: true,
        filled: true,
        fillColor: kColorSurfaceSunken,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: kSpace4,
          vertical: kSpace2,
        ),
        border: const OutlineInputBorder(
          borderRadius: kRadiusSm,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: kRadiusSm,
          borderSide: BorderSide.none,
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: kRadiusSm,
          borderSide: BorderSide(color: kColorPrimary),
        ),
      ),
    );
  }
}

// ── Stays section ─────────────────────────────────────────────────────────────

class _StaysSection extends StatelessWidget {
  const _StaysSection({required this.stays, required this.onTap});

  final List<Accommodation> stays;
  final ValueChanged<Accommodation> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: kSpace5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpace1),
          child: Row(
            children: [
              const Icon(Icons.hotel_rounded, size: 14, color: kColorInkSoft),
              const SizedBox(width: kSpace2),
              Text('Stays', style: kStyleCaption.copyWith(color: kColorInkSoft)),
            ],
          ),
        ),
        const SizedBox(height: kSpace2),
        ...List.generate(stays.length, (i) {
          final stay = stays[i];
          return Padding(
            padding: EdgeInsets.only(bottom: i < stays.length - 1 ? kSpace3 : 0),
            child: _StayRow(stay: stay, onTap: () => onTap(stay)),
          );
        }),
      ],
    );
  }
}

class _StayRow extends StatelessWidget {
  const _StayRow({required this.stay, required this.onTap});

  final Accommodation stay;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(kSpace3),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: stay.status.color.withValues(alpha: 0.12),
                borderRadius: kRadiusSm,
              ),
              child: Icon(Icons.hotel_rounded,
                  size: 18, color: stay.status.color),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stay.name,
                      style: kStyleBodyBold,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(stay.city,
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: kSpace2),
            WabwayBadge(
              label: stay.status.label,
              tone: stay.status.tone,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stay mini sheet ───────────────────────────────────────────────────────────

class _StayMiniSheet extends StatelessWidget {
  const _StayMiniSheet({required this.stay, this.linkedSpot});

  final Accommodation stay;
  final Spot? linkedSpot;

  String _fmt(DateTime dt) =>
      '${dt.month}/${dt.day}/${dt.year}';

  @override
  Widget build(BuildContext context) {
    final nights = stay.nights;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kSpace5, kSpace4, kSpace5, kSpace5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(stay.name,
                      style: kStyleBodyBold,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ),
                const SizedBox(width: kSpace3),
                WabwayBadge(
                  label: stay.status.label,
                  tone: stay.status.tone,
                ),
              ],
            ),
            const SizedBox(height: kSpace2),
            Text(stay.city,
                style: kStyleCaption.copyWith(color: kColorInkSoft)),
            if (stay.address != null) ...[
              const SizedBox(height: kSpace1),
              Text(stay.address!,
                  style: kStyleCaption.copyWith(color: kColorInkSoft)),
            ],
            if (linkedSpot != null) ...[
              const SizedBox(height: kSpace3),
              Row(
                children: [
                  Icon(linkedSpot!.category.icon,
                      size: 14, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(
                      linkedSpot!.name,
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  WabwayBadge(
                    label: linkedSpot!.status.label,
                    tone: linkedSpot!.status.tone,
                  ),
                ],
              ),
            ],
            if (stay.checkIn != null || stay.checkOut != null) ...[
              const SizedBox(height: kSpace4),
              const Divider(height: 1),
              const SizedBox(height: kSpace4),
              Row(
                children: [
                  if (stay.checkIn != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Check-in',
                              style:
                                  kStyleCaption.copyWith(color: kColorInkSoft)),
                          const SizedBox(height: 2),
                          Text(_fmt(stay.checkIn!), style: kStyleBodyMedium),
                        ],
                      ),
                    ),
                  if (stay.checkOut != null)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Check-out',
                              style:
                                  kStyleCaption.copyWith(color: kColorInkSoft)),
                          const SizedBox(height: 2),
                          Text(_fmt(stay.checkOut!), style: kStyleBodyMedium),
                        ],
                      ),
                    ),
                  if (nights != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Nights',
                            style:
                                kStyleCaption.copyWith(color: kColorInkSoft)),
                        const SizedBox(height: 2),
                        Text('$nights', style: kStyleBodyMedium),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: kSpace4),
          ],
        ),
      ),
    );
  }
}
