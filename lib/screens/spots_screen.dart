import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/auth/profile_state.dart';
import '../core/images/wikipedia_image_service.dart';
import '../core/supabase/client.dart';
import '../core/supabase/doc_service.dart';
import '../core/supabase/spot_service.dart';
import '../core/trip/trip_state.dart';
import '../data/docs_data.dart';
import '../data/spot_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'spots/spot_list_tile.dart';
import 'spots/spot_detail.dart';
import 'spots/add_spot_sheet.dart';

class SpotsScreen extends StatefulWidget {
  const SpotsScreen({super.key});

  @override
  State<SpotsScreen> createState() => _SpotsScreenState();
}

class _SpotsScreenState extends State<SpotsScreen> {
  List<Spot> _spots = [];
  List<TripDocument> _docs = [];
  Map<String, VoteType> _myVotes = {};
  bool _loading = true;
  bool _error = false;
  bool _offline = false;

  String? _activeTripId;
  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;
  final _thumbnailAttempted = <String>{};

  String? _selectedId;
  SpotCategory? _filterCategory;
  Set<SpotStatus> _filterStatuses = {};
  String? _filterCity;
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  int get _advancedFilterCount =>
      _filterStatuses.length + (_filterCity != null ? 1 : 0);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tripId = TripState.tripOf(context).id;
    if (tripId != _activeTripId) {
      _activeTripId = tripId;
      _loadSpots();
      _subscribeRealtime(tripId);
    }
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
        .channel('spots-$tripId')
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
        .subscribe();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadSpots(silent: true);
    });
  }

  Future<void> _loadSpots({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = false; });
    try {
      final tripId = TripState.tripOf(context).id;
      final results = await Future.wait([
        SpotService.loadSpots(tripId),
        DocService.loadDocuments(tripId),
      ]);
      final spots = results[0] as List<Spot>;
      final docs = results[1] as List<TripDocument>;
      if (!mounted) return;

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

      setState(() { _spots = spots; _docs = docs; _myVotes = myVotes; _loading = false; _offline = false; });
      _fetchMissingThumbnails(spots);
    } catch (_) {
      if (!mounted) return;
      if (silent) { setState(() => _offline = true); return; }
      // Try to show cached data on cold-start failure
      final tripId = TripState.maybeOf(context)?.trip.id ?? '';
      final cachedSpots = tripId.isNotEmpty
          ? await SpotService.loadSpotsFromCache(tripId)
          : null;
      final cachedDocs = tripId.isNotEmpty
          ? await DocService.loadDocumentsFromCache(tripId)
          : null;
      if (!mounted) return;
      if (cachedSpots != null) {
        setState(() {
          _spots = cachedSpots;
          _docs = cachedDocs ?? _docs;
          _loading = false;
          _offline = true;
        });
      } else {
        setState(() { _loading = false; _error = true; });
      }
    }
  }

  void _fetchMissingThumbnails(List<Spot> spots) {
    final missing = spots
        .where((s) => s.imageUrl == null && !_thumbnailAttempted.contains(s.id))
        .toList();
    if (missing.isEmpty) return;
    for (final s in missing) {
      _thumbnailAttempted.add(s.id);
      WikipediaImageService.fetchThumbnailUrl(s.name).then((url) async {
        if (url == null || !mounted) return;
        try {
          await SpotService.updateSpotImageUrl(s.id, url);
          if (!mounted) return;
          setState(() {
            final idx = _spots.indexWhere((sp) => sp.id == s.id);
            if (idx != -1) _spots[idx] = _spots[idx].copyWith(imageUrl: url);
          });
        } catch (_) {}
      });
    }
  }

  List<Spot> get _filtered {
    return _spots.where((s) {
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
    return TripState.membersOf(context).any((m) => m.userId == myId && m.isOwner);
  }

  // ─── Mutations ───────────────────────────────────────────────────────────────

  Future<void> _addSpot(BuildContext context) async {
    final tripId = TripState.tripOf(context).id;
    final userId = ProfileState.of(context).id;
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

  // ─── Mobile detail ────────────────────────────────────────────────────────────

  void _openDetailMobile(BuildContext context, Spot spot) {
    final docs = _docs;
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: kColorCream,
        body: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(kColorPrimary),
            ),
          ),
        ),
      );
    }

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
            docs: _docs,
            selected: _selected,
            myVotes: _myVotes,
            filterCategory: _filterCategory,
            searchQuery: _searchQuery,
            searchCtrl: _searchCtrl,
            showSearch: _showSearch,
            canDelete: _canDelete,
            onSelectSpot: (s) => setState(() => _selectedId = s?.id),
            onFilterCategory: (c) => setState(() => _filterCategory = c),
            onSearch: (q) => setState(() => _searchQuery = q),
            onToggleSearch: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchQuery = '';
                _searchCtrl.clear();
              }
            }),
            onVote: _onVote,
            onDelete: _deleteSpot,
            onEdit: _onEditSpot,
            onAdd: () => _addSpot(context),
          )
        : _MobileLayout(
            spots: _filtered,
            myVotes: _myVotes,
            filterCategory: _filterCategory,
            advancedFilterCount: _advancedFilterCount,
            searchQuery: _searchQuery,
            searchCtrl: _searchCtrl,
            showSearch: _showSearch,
            onOpenSpot: (s) => _openDetailMobile(context, s),
            onFilterCategory: (c) => setState(() => _filterCategory = c),
            onSearch: (q) => setState(() => _searchQuery = q),
            onToggleSearch: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchQuery = '';
                _searchCtrl.clear();
              }
            }),
            onFilter: _openFilterSheet,
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

// ─── Mobile layout ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.spots,
    required this.myVotes,
    required this.filterCategory,
    required this.advancedFilterCount,
    required this.searchQuery,
    required this.searchCtrl,
    required this.showSearch,
    required this.onOpenSpot,
    required this.onFilterCategory,
    required this.onSearch,
    required this.onToggleSearch,
    required this.onFilter,
    required this.onAdd,
  });

  final List<Spot> spots;
  final Map<String, VoteType> myVotes;
  final SpotCategory? filterCategory;
  final int advancedFilterCount;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final bool showSearch;
  final ValueChanged<Spot> onOpenSpot;
  final ValueChanged<SpotCategory?> onFilterCategory;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleSearch;
  final VoidCallback onFilter;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: showSearch
                ? _SearchField(controller: searchCtrl, onChanged: onSearch)
                : Text('Spots', style: kStyleTitle),
            pinned: true,
            actions: [
              IconButton(
                icon: Icon(
                  showSearch ? Icons.close_rounded : Icons.search_rounded,
                ),
                color: kColorInkSoft,
                onPressed: onToggleSearch,
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
            ),
          ),
          spots.isEmpty
              ? SliverFillRemaining(
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
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                      kSpace4, kSpace2, kSpace4, kSpace4),
                  sliver: SliverList.separated(
                    itemCount: spots.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: kSpace3),
                    itemBuilder: (_, i) => SpotListTile(
                      spot: spots[i],
                      myVote: myVotes[spots[i].id],
                      onTap: () => onOpenSpot(spots[i]),
                    ),
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: kSpace16)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
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
    required this.docs,
    required this.selected,
    required this.myVotes,
    required this.filterCategory,
    required this.searchQuery,
    required this.searchCtrl,
    required this.showSearch,
    required this.canDelete,
    required this.onSelectSpot,
    required this.onFilterCategory,
    required this.onSearch,
    required this.onToggleSearch,
    required this.onVote,
    required this.onDelete,
    required this.onEdit,
    required this.onAdd,
  });

  final List<Spot> spots;
  final List<Spot> allSpots;
  final List<TripDocument> docs;
  final Spot? selected;
  final Map<String, VoteType> myVotes;
  final SpotCategory? filterCategory;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final bool showSearch;
  final bool Function(Spot) canDelete;
  final ValueChanged<Spot?> onSelectSpot;
  final ValueChanged<SpotCategory?> onFilterCategory;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleSearch;
  final void Function(String, VoteType?) onVote;
  final Future<void> Function(String) onDelete;
  final ValueChanged<Spot> onEdit;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Column(
        children: [
          _DesktopTopBar(
            showSearch: showSearch,
            searchCtrl: searchCtrl,
            onSearch: onSearch,
            onToggleSearch: onToggleSearch,
            onAdd: onAdd,
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
                      ),
                      Expanded(
                        child: spots.isEmpty
                            ? Center(
                                child: WabwayEmptyState(
                                  icon: Icons.place_rounded,
                                  title: 'No spots yet',
                                  description: searchQuery.isNotEmpty
                                      ? 'No spots match "$searchQuery".'
                                      : 'Add the first place worth visiting.',
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                    kSpace4, kSpace2, kSpace4, kSpace4),
                                itemCount: spots.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: kSpace3),
                                itemBuilder: (_, i) => SpotListTile(
                                  spot: spots[i],
                                  selected: selected?.id == spots[i].id,
                                  myVote: myVotes[spots[i].id],
                                  onTap: () => onSelectSpot(
                                    selected?.id == spots[i].id
                                        ? null
                                        : spots[i],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),

                const VerticalDivider(width: 1, thickness: 1),

                Expanded(
                  child: selected == null
                      ? _DesktopEmptyDetail(onAdd: onAdd)
                      : SingleChildScrollView(
                          child: SpotDetailContent(
                            key: ValueKey(selected!.id),
                            spot: selected!,
                            myVote: myVotes[selected!.id],
                            onVote: (v) => onVote(selected!.id, v),
                            canDelete: canDelete(selected!),
                            docs: docs,
                            onEdit: onEdit,
                            onDelete: () => onDelete(selected!.id),
                          ),
                        ),
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
    required this.onSearch,
    required this.onToggleSearch,
    required this.onAdd,
  });

  final bool showSearch;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kTopBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      decoration: const BoxDecoration(
        color: kColorPaper,
        border: Border(bottom: BorderSide(color: kColorBorder)),
      ),
      child: Row(
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
  });

  final SpotCategory? selected;
  final ValueChanged<SpotCategory?> onChanged;

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
                  label: 'All',
                  selected: widget.selected == null,
                  onTap: () => widget.onChanged(null),
                ),
                ...SpotCategory.values.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: kSpace2),
                    child: WabwayTag(
                      label: c.label,
                      selected: widget.selected == c,
                      onTap: () => widget.onChanged(
                        widget.selected == c ? null : c,
                      ),
                    ),
                  ),
                ),
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
