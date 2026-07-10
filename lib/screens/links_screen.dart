import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/auth/profile_state.dart';
import '../core/supabase/client.dart';
import '../core/supabase/links_service.dart';
import '../core/trip/trip_state.dart';
import '../data/links_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'links/add_link_sheet.dart';

class LinksScreen extends StatefulWidget {
  const LinksScreen({super.key});

  @override
  State<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends State<LinksScreen> {
  List<TripLink> _links = [];
  bool _loading = true;
  bool _error   = false;
  bool _offline = false;
  String? _activeTripId;
  RealtimeChannel? _channel;
  Timer? _debounce;
  LinkCategory? _filterCategory;
  String _search = '';

  final _searchCtrl = TextEditingController();

  List<TripLink> get _filteredLinks {
    var list = _filterCategory == null
        ? _links
        : _links.where((l) => l.category == _filterCategory).toList();
    final q = _search.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((l) =>
        l.title.toLowerCase().contains(q) ||
        l.domain.toLowerCase().contains(q) ||
        (l.notes?.toLowerCase().contains(q) ?? false),
      ).toList();
    }
    return list;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tripId = TripState.tripOf(context).id;
    if (tripId != _activeTripId) {
      _activeTripId = tripId;
      _load();
      _subscribe(tripId);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribe(String tripId) {
    _channel?.unsubscribe();
    _channel = supabase
        .channel('trip_links-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trip_links',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400), () => _load(silent: true));
          },
        )
        .subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = false; });
    try {
      final links = await LinksService.loadLinks(_activeTripId!);
      if (mounted) setState(() { _links = links; _loading = false; _error = false; _offline = false; });
    } catch (_) {
      if (!mounted) return;
      if (silent) { setState(() => _offline = true); return; }
      setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _addLink() async {
    final userId = ProfileState.of(context).id;
    final link = await showAddLinkSheet(
      context,
      tripId: _activeTripId!,
      userId: userId,
    );
    if (link != null && mounted) {
      setState(() => _links = [link, ..._links]);
    }
  }

  Future<void> _deleteLink(TripLink link) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Remove link?', style: kStyleBodySemibold),
        content: Text(
          '"${link.title}" will be removed for everyone.',
          style: kStyleBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: kStyleBody.copyWith(color: kColorInkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove', style: kStyleBodyMedium.copyWith(color: kColorDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _links = _links.where((l) => l.id != link.id).toList());
    try {
      await LinksService.deleteLink(link.id);
    } catch (_) {
      if (mounted) _load(); // revert on failure
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Links', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: kColorPrimary,
            tooltip: 'Save a link',
            onPressed: _addLink,
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? Center(
                  child: WabwayEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Failed to load',
                    description: 'Could not load links.',
                    action: WabwayButton(
                      label: 'Retry',
                      onPressed: _load,
                    ),
                  ),
                )
              : _links.isEmpty
                  ? Center(
                      child: WabwayEmptyState(
                        icon: Icons.bookmark_border_rounded,
                        title: 'No links saved yet',
                        description:
                            'Save Instagram posts, articles, Maps links, and anything else the group wants to remember.',
                        action: WabwayButton(
                          label: 'Save a link',
                          icon: Icons.add_rounded,
                          onPressed: _addLink,
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: CustomScrollView(
                        slivers: [
                          // Search bar — always visible when links are loaded
                          SliverToBoxAdapter(
                            child: WabwaySearchBar(
                              controller: _searchCtrl,
                              hint: 'Search links…',
                              onChanged: (v) => setState(() => _search = v),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: _LinkFilterStrip(
                              selected: _filterCategory,
                              links: _links,
                              onChanged: (cat) => setState(() => _filterCategory = cat),
                            ),
                          ),
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              kSpace4,
                              kSpace3,
                              kSpace4,
                              kSpace8 + MediaQuery.paddingOf(context).bottom,
                            ),
                            sliver: _filteredLinks.isEmpty
                                ? SliverToBoxAdapter(
                                    child: Center(
                                      child: WabwayEmptyState(
                                        icon: _filterCategory != null
                                            ? _filterCategory!.icon
                                            : Icons.search_off_rounded,
                                        title: _search.isNotEmpty
                                            ? 'No links match "$_search"'
                                            : 'No ${_filterCategory!.label} links',
                                        description: _search.isNotEmpty
                                            ? 'Try a different search term.'
                                            : 'Add some to see them here.',
                                      ),
                                    ),
                                  )
                                : SliverList.separated(
                                    itemCount: _filteredLinks.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
                                    itemBuilder: (_, i) => _LinkCard(
                                      link: _filteredLinks[i],
                                      onDelete: () => _deleteLink(_filteredLinks[i]),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
      floatingActionButton: _links.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addLink,
              backgroundColor: kColorPrimary,
              child: const Icon(Icons.add_rounded, color: Colors.white),
            )
          : null,
    );
    if (!_offline) return scaffold;
    return Stack(
      children: [
        scaffold,
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: OfflineBanner(onRetry: _load),
        ),
      ],
    );
  }
}

// ─── Category filter strip ────────────────────────────────────────────────────

class _LinkFilterStrip extends StatelessWidget {
  const _LinkFilterStrip({
    required this.selected,
    required this.links,
    required this.onChanged,
  });

  final LinkCategory? selected;
  final List<TripLink> links;
  final ValueChanged<LinkCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Only show when at least 2 different categories are present.
    final present = LinkCategory.values
        .where((c) => links.any((l) => l.category == c))
        .toList();
    if (present.length < 2) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: kSpace2),
            child: WabwayTag(
              label: 'All (${links.length})',
              selected: selected == null,
              onTap: () => onChanged(null),
            ),
          ),
          for (final cat in present)
            Padding(
              padding: const EdgeInsets.only(right: kSpace2),
              child: WabwayTag(
                label: '${cat.label} (${links.where((l) => l.category == cat).length})',
                selected: selected == cat,
                onTap: () => onChanged(selected == cat ? null : cat),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Link card ────────────────────────────────────────────────────────────────

class _LinkCard extends StatelessWidget {
  const _LinkCard({required this.link, required this.onDelete});
  final TripLink link;
  final VoidCallback onDelete;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(link.url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      hoverable: true,
      onTap: () => _open(context),
      padding: const EdgeInsets.all(kSpace3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: link.category.softColor,
              borderRadius: kRadiusMd,
            ),
            child: Icon(link.category.icon, size: 20, color: link.category.color),
          ),
          const SizedBox(width: kSpace3),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(link.title,
                    style: kStyleBodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(link.domain,
                    style: kStyleCaption.copyWith(color: kColorInkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (link.notes != null) ...[
                  const SizedBox(height: kSpace2),
                  Text(link.notes!,
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          const SizedBox(width: kSpace2),

          // Actions
          Column(
            children: [
              const Icon(Icons.open_in_new_rounded,
                  size: 16, color: kColorInkSoft),
              const SizedBox(height: kSpace3),
              GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline_rounded,
                    size: 16, color: kColorDanger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
