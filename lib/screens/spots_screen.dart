import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/auth/profile_state.dart';
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

  String? _activeTripId;
  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  String? _selectedId;
  SpotCategory? _filterCategory;
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

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

      setState(() { _spots = spots; _docs = docs; _myVotes = myVotes; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      if (silent) return; // keep existing list visible, don't replace with error screen
      setState(() { _loading = false; _error = true; });
    }
  }

  List<Spot> get _filtered {
    return _spots.where((s) {
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.area.toLowerCase().contains(q);
      final matchesCat =
          _filterCategory == null || s.category == _filterCategory;
      return matchesSearch && matchesCat;
    }).toList();
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

    return isDesktop
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
            onAdd: () => _addSpot(context),
          )
        : _MobileLayout(
            spots: _filtered,
            myVotes: _myVotes,
            filterCategory: _filterCategory,
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
            onAdd: () => _addSpot(context),
          );
  }
}

// ─── Mobile layout ─────────────────────────────────────────────────────────────

class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.spots,
    required this.myVotes,
    required this.filterCategory,
    required this.searchQuery,
    required this.searchCtrl,
    required this.showSearch,
    required this.onOpenSpot,
    required this.onFilterCategory,
    required this.onSearch,
    required this.onToggleSearch,
    required this.onAdd,
  });

  final List<Spot> spots;
  final Map<String, VoteType> myVotes;
  final SpotCategory? filterCategory;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final bool showSearch;
  final ValueChanged<Spot> onOpenSpot;
  final ValueChanged<SpotCategory?> onFilterCategory;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleSearch;
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
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                color: kColorInkSoft,
                // TODO: Spots filter panel — show bottom sheet with multi-select chips
                // for category, city, and maybe tags. Replace _CategoryFilterStrip or
                // augment it. State lives in _SpotsScreenState._filterCategory.
                onPressed: () {},
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
