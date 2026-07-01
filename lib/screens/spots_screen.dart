import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
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
  final List<Spot> _spots = List.from(kMockSpots);
  final Map<String, VoteType> _myVotes = {};
  String? _selectedId;
  SpotCategory? _filterCategory;
  String _searchQuery = '';
  bool _showSearch = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  void _addSpot(BuildContext context) async {
    final spot = await showAddSpotSheet(context);
    if (spot != null) {
      setState(() {
        _spots.insert(0, spot);
        _selectedId = spot.id;
      });
    }
  }

  void _onVote(String spotId, VoteType? type) {
    setState(() {
      if (type == null) {
        _myVotes.remove(spotId);
      } else {
        _myVotes[spotId] = type;
      }
    });
  }

  // ─── Mobile: push detail screen ───────────────────────────────────────────

  void _openDetailMobile(BuildContext context, Spot spot) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SpotDetailScreen(
          spot: spot,
          myVote: _myVotes[spot.id],
          onVote: (v) => _onVote(spot.id, v),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop =
        MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    return isDesktop
        ? _DesktopLayout(
            spots: _filtered,
            allSpots: _spots,
            selected: _selected,
            myVotes: _myVotes,
            filterCategory: _filterCategory,
            searchQuery: _searchQuery,
            searchCtrl: _searchCtrl,
            showSearch: _showSearch,
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

// ─── Mobile layout ─────────────────────────────────────────────────────────

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

// ─── Desktop layout ────────────────────────────────────────────────────────

class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.spots,
    required this.allSpots,
    required this.selected,
    required this.myVotes,
    required this.filterCategory,
    required this.searchQuery,
    required this.searchCtrl,
    required this.showSearch,
    required this.onSelectSpot,
    required this.onFilterCategory,
    required this.onSearch,
    required this.onToggleSearch,
    required this.onVote,
    required this.onAdd,
  });

  final List<Spot> spots;
  final List<Spot> allSpots;
  final Spot? selected;
  final Map<String, VoteType> myVotes;
  final SpotCategory? filterCategory;
  final String searchQuery;
  final TextEditingController searchCtrl;
  final bool showSearch;
  final ValueChanged<Spot?> onSelectSpot;
  final ValueChanged<SpotCategory?> onFilterCategory;
  final ValueChanged<String> onSearch;
  final VoidCallback onToggleSearch;
  final void Function(String, VoteType?) onVote;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Column(
        children: [
          // ── Top bar
          _DesktopTopBar(
            showSearch: showSearch,
            searchCtrl: searchCtrl,
            onSearch: onSearch,
            onToggleSearch: onToggleSearch,
            onAdd: onAdd,
          ),

          // ── Main split
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: list
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

                // Divider
                const VerticalDivider(width: 1, thickness: 1),

                // Right: detail or empty state
                Expanded(
                  child: selected == null
                      ? _DesktopEmptyDetail(onAdd: onAdd)
                      : SingleChildScrollView(
                          child: SpotDetailContent(
                            key: ValueKey(selected!.id),
                            spot: selected!,
                            myVote: myVotes[selected!.id],
                            onVote: (v) => onVote(selected!.id, v),
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
        description: 'Pick a spot from the list to see details, vote, and leave a comment.',
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

// ─── Shared sub-widgets ────────────────────────────────────────────────────

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
    final atEnd = pos.maxScrollExtent <= 0 ||
        pos.pixels >= pos.maxScrollExtent - 1;
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

          // Right-edge fade hint
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
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kColorInkSoft),
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
