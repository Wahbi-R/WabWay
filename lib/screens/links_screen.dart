import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/client.dart';
import '../core/supabase/links_service.dart';
import '../data/links_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'links/add_link_sheet.dart';

enum _LinkSort { newest, oldest, alphabetical }

class LinksScreen extends ConsumerStatefulWidget {
  const LinksScreen({super.key});

  @override
  ConsumerState<LinksScreen> createState() => _LinksScreenState();
}

class _LinksScreenState extends ConsumerState<LinksScreen> {
  List<TripLink> _links = [];
  bool _loading = true;
  bool _error   = false;
  bool _offline = false;
  String? _activeTripId;
  RealtimeChannel? _channel;
  Timer? _debounce;
  LinkCategory? _filterCategory;
  _LinkSort _sort = _LinkSort.newest;
  String _search = '';

  final _searchCtrl = TextEditingController();

  List<TripLink> get _filteredLinks {
    var list = _filterCategory == null
        ? List<TripLink>.from(_links)
        : _links.where((l) => l.category == _filterCategory).toList();
    final q = _search.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((l) =>
        l.title.toLowerCase().contains(q) ||
        l.domain.toLowerCase().contains(q) ||
        (l.notes?.toLowerCase().contains(q) ?? false),
      ).toList();
    }
    switch (_sort) {
      case _LinkSort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case _LinkSort.oldest:
        list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      case _LinkSort.alphabetical:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeTripId = ref.read(activeTripIdProvider);
      _load();
      _subscribe(_activeTripId!);
    });
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
    final userId = ref.read(profileProvider)!.id;
    final link = await showAddLinkSheet(
      context,
      tripId: _activeTripId!,
      userId: userId,
    );
    if (link != null && mounted) {
      setState(() => _links = [link, ..._links]);
    }
  }

  Future<void> _editLink(TripLink link) async {
    final userId = ref.read(profileProvider)!.id;
    final updated = await showAddLinkSheet(
      context,
      tripId: _activeTripId!,
      userId: userId,
      existing: link,
    );
    if (updated != null && mounted) {
      setState(() {
        final idx = _links.indexWhere((l) => l.id == updated.id);
        if (idx >= 0) _links[idx] = updated;
      });
    }
  }

  Future<void> _deleteLinkDirect(BuildContext context, TripLink link) async {
    setState(() => _links = _links.where((l) => l.id != link.id).toList());
    try {
      await LinksService.deleteLink(link.id);
    } catch (_) {
      if (!mounted) return;
      if (mounted) _load();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not delete "${link.title}". Try again.',
            style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('"${link.title}" removed.',
          style: kStyleBody.copyWith(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
    ));
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

  void _shareLinks() {
    final list = _filteredLinks;
    if (list.isEmpty || kIsWeb) return;
    final tripName = ref.read(activeTripProvider)!.name;
    final buf = StringBuffer();
    buf.writeln('$tripName — Links');
    buf.writeln();
    final byCategory = <LinkCategory, List<TripLink>>{};
    for (final link in list) {
      byCategory.putIfAbsent(link.category, () => []).add(link);
    }
    for (final cat in LinkCategory.values) {
      final links = byCategory[cat];
      if (links == null || links.isEmpty) continue;
      buf.writeln(cat.label);
      for (final l in links) {
        buf.writeln('  ${l.title}');
        buf.writeln('  ${l.url}');
        if (l.notes != null && l.notes!.isNotEmpty) buf.writeln('  ${l.notes}');
      }
      buf.writeln();
    }
    Share.share(buf.toString().trim(), subject: '$tripName — Links');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _activeTripId) {
        _activeTripId = next;
        _load();
        _subscribe(next);
      }
    });
    final scaffold = Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Links', style: kStyleTitle),
        actions: [
          if (_links.isNotEmpty) ...[
            if (!kIsWeb)
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                color: kColorInkSoft,
                tooltip: 'Share links',
                onPressed: _shareLinks,
              ),
            PopupMenuButton<_LinkSort>(
              icon: Icon(
                Icons.sort_rounded,
                color: _sort != _LinkSort.newest ? kColorPrimary : kColorInkSoft,
              ),
              tooltip: 'Sort',
              onSelected: (s) => setState(() => _sort = s),
              itemBuilder: (_) => [
                _linkSortItem(_LinkSort.newest,       'Newest first', _sort),
                _linkSortItem(_LinkSort.oldest,       'Oldest first', _sort),
                _linkSortItem(_LinkSort.alphabetical, 'A – Z',        _sort),
              ],
            ),
          ],
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
          ? const WabwayLoadingIndicator()
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
                            child: WabwayFilterStrip<LinkCategory>(
                              selected: _filterCategory,
                              options: LinkCategory.values
                                  .where((c) => _links.any((l) => l.category == c))
                                  .map((c) => (
                                        value: c,
                                        label: c.label,
                                        count: _links.where((l) => l.category == c).length,
                                      ))
                                  .toList(),
                              allCount: _links.length,
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
                                    itemBuilder: (ctx, i) {
                                      final link = _filteredLinks[i];
                                      return Dismissible(
                                        key: ValueKey('link_${link.id}'),
                                        direction: DismissDirection.endToStart,
                                        confirmDismiss: (_) async {
                                          await _deleteLinkDirect(ctx, link);
                                          return false;
                                        },
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: kSpace5),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: kRadiusMd,
                                          ),
                                          child: const Icon(Icons.delete_rounded,
                                              color: Colors.red, size: 22),
                                        ),
                                        child: _LinkCard(
                                          link: link,
                                          onEdit: () => _editLink(link),
                                          onDelete: () => _deleteLink(link),
                                        ),
                                      );
                                    },
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

// ─── Link card ────────────────────────────────────────────────────────────────

enum _LinkAction { open, edit, delete }

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.link,
    required this.onEdit,
    required this.onDelete,
  });
  final TripLink link;
  final VoidCallback onEdit;
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

          // Kebab menu
          PopupMenuButton<_LinkAction>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: kColorInkSoft),
            padding: EdgeInsets.zero,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: _LinkAction.open,
                child: Text('Open'),
              ),
              const PopupMenuItem(
                value: _LinkAction.edit,
                child: Text('Edit'),
              ),
              PopupMenuItem(
                value: _LinkAction.delete,
                child: Text('Delete', style: TextStyle(color: kColorDanger)),
              ),
            ],
            onSelected: (action) {
              switch (action) {
                case _LinkAction.open:   _open(context);
                case _LinkAction.edit:   onEdit();
                case _LinkAction.delete: onDelete();
              }
            },
          ),
        ],
      ),
    );
  }
}

PopupMenuItem<_LinkSort> _linkSortItem(
    _LinkSort value, String label, _LinkSort current) {
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
