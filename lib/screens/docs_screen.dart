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
import '../core/supabase/client.dart';
import '../core/supabase/doc_service.dart';
import '../core/supabase/spot_service.dart';
import '../data/docs_data.dart';
import '../data/spot_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'docs/doc_card.dart';
import 'docs/doc_detail.dart';
import 'docs/add_doc_sheet.dart';

enum _DocSort { newest, alphabetical, type }

class DocsScreen extends ConsumerStatefulWidget {
  const DocsScreen({super.key});

  @override
  ConsumerState<DocsScreen> createState() => _DocsScreenState();
}

class _DocsScreenState extends ConsumerState<DocsScreen> {
  List<TripDocument> _docs = [];
  List<Spot> _availableSpots = [];

  bool _loading = true;
  bool _error = false;
  bool _offline = false;

  String? _activeTripId;
  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  // Uploader name resolver (built from TripState in didChangeDependencies)
  String Function(String) _memberName = (id) => id;

  String? _selectedDocId;
  DocType? _filterType;
  String? _filterUploaderId;
  _DocSort _sort = _DocSort.newest;
  String _search = '';

  final _searchCtrl = TextEditingController();
  final _filterScrollCtrl = ScrollController();

  void _rebuildMemberName() {
    final members = ref.read(tripMembersProvider);
    final myId = supabase.auth.currentUser?.id;
    _memberName = (userId) {
      if (userId == myId) return 'You';
      final m = members.where((m) => m.userId == userId).firstOrNull;
      return m?.profile.displayName ?? userId;
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeTripId = ref.read(activeTripIdProvider);
      _rebuildMemberName();
      _loadDocs();
      _loadAvailableSpots();
      _subscribeRealtime(_activeTripId!);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _realtimeChannel?.unsubscribe();
    _searchCtrl.dispose();
    _filterScrollCtrl.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  Future<void> _loadDocs({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = false; });
    try {
      final tripId = _activeTripId!;
      final docs = await DocService.loadDocuments(tripId);
      if (!mounted) return;
      setState(() { _docs = docs; _loading = false; _offline = false; });
    } catch (_) {
      if (!mounted) return;
      if (silent) { setState(() => _offline = true); return; }
      // Try cached data on cold-start failure
      final tripId = _activeTripId ?? '';
      final cached = tripId.isNotEmpty
          ? await DocService.loadDocumentsFromCache(tripId)
          : null;
      if (!mounted) return;
      if (cached != null) {
        setState(() { _docs = cached; _loading = false; _offline = true; });
      } else {
        setState(() { _loading = false; _error = true; });
      }
    }
  }

  Future<void> _loadAvailableSpots() async {
    try {
      final tripId = _activeTripId!;
      final spots = await SpotService.loadSpots(tripId);
      if (mounted) setState(() => _availableSpots = spots);
    } catch (_) {}
  }

  // ── Realtime ─────────────────────────────────────────────────────────────────

  void _subscribeRealtime(String tripId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supabase
        .channel('docs-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'documents',
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
          table: 'document_links',
          callback: (_) => _scheduleReload(),
        )
        .subscribe();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadDocs(silent: true);
    });
  }

  // ── Mutations ────────────────────────────────────────────────────────────────

  Future<void> _addDoc(BuildContext context) async {
    final trip = ref.read(activeTripProvider);
    final tripId   = trip?.id ?? _activeTripId ?? '';
    final tripName = trip?.name ?? 'Trip';
    final userId   = ref.read(profileProvider)?.id ?? '';

    final doc = await showAddDocSheet(
      context,
      tripId: tripId,
      tripName: tripName,
      userId: userId,
      availableSpots: _availableSpots,
    );
    if (doc != null && mounted) {
      setState(() {
        _docs.insert(0, doc);
        _selectedDocId = doc.id;
      });
    }
  }

  Future<void> _deleteDoc(TripDocument doc) async {
    // Step 1: delete the DB row (cascades document_links). Show error if this fails.
    try {
      await DocService.deleteDocument(doc.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not delete document.',
              style: kStyleBody.copyWith(color: Colors.white)),
          backgroundColor: kColorDanger,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    // Step 2: update UI immediately after successful DB delete.
    if (mounted) {
      setState(() {
        _docs.removeWhere((d) => d.id == doc.id);
        if (_selectedDocId == doc.id) _selectedDocId = null;
      });
    }

    // Step 3: best-effort storage cleanup — swallow errors silently.
    if (doc.storagePath != null) {
      try {
        await DocService.deleteStorageFile(doc.storagePath!);
      } catch (_) {}
    }
  }

  // ── Derived state ────────────────────────────────────────────────────────────

  TripDocument? get _selectedDoc =>
      _selectedDocId == null
          ? null
          : _docs.where((d) => d.id == _selectedDocId).firstOrNull;

  List<TripDocument> get _filtered {
    final q = _search.toLowerCase().trim();
    final results = _docs.where((d) {
      final matchType = _filterType == null || d.type == _filterType;
      final matchUploader = _filterUploaderId == null || d.uploadedById == _filterUploaderId;
      final matchSearch = q.isEmpty ||
          d.title.toLowerCase().contains(q) ||
          d.type.label.toLowerCase().contains(q) ||
          _memberName(d.uploadedById).toLowerCase().contains(q);
      return matchType && matchUploader && matchSearch;
    }).toList();
    switch (_sort) {
      case _DocSort.newest:
        results.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
      case _DocSort.alphabetical:
        results.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case _DocSort.type:
        results.sort((a, b) {
          final c = a.type.label.compareTo(b.type.label);
          return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
        });
    }
    return results;
  }

  Widget _uploaderFilterStrip() {
    final uploaderIds = _docs.map((d) => d.uploadedById).toSet();
    if (uploaderIds.length < 2) return const SizedBox.shrink();
    final myId = supabase.auth.currentUser?.id;
    final uploaders = uploaderIds.toList()
      ..sort((a, b) {
        if (a == myId) return -1;
        if (b == myId) return 1;
        return _memberName(a).compareTo(_memberName(b));
      });
    return WabwayFilterStrip<String>(
      selected: _filterUploaderId,
      options: uploaders.map((id) => (
        value: id,
        label: id == myId ? 'Me' : _memberName(id),
        count: _docs.where((d) => d.uploadedById == id).length,
      )).toList(),
      allCount: _docs.length,
      onChanged: (id) => setState(() {
        _filterUploaderId = id;
        _selectedDocId = null;
      }),
    );
  }

  // ── Share ────────────────────────────────────────────────────────────────────

  void _shareDocs() {
    final list = _filtered;
    if (list.isEmpty || kIsWeb) return;
    final tripName = ref.read(activeTripProvider)?.name ?? 'Trip';
    final buf = StringBuffer();
    buf.writeln('$tripName — Documents');
    buf.writeln();
    final byType = <DocType, List<TripDocument>>{};
    for (final doc in list) {
      byType.putIfAbsent(doc.type, () => []).add(doc);
    }
    for (final type in DocType.values) {
      final docs = byType[type];
      if (docs == null || docs.isEmpty) continue;
      buf.writeln('${type.label} (${docs.length})');
      for (final d in docs) {
        buf.write('  ${d.title}');
        if (d.amount != null) {
          final cur = d.currency ?? '';
          buf.write(' — ${cur.isNotEmpty ? '$cur ' : ''}${d.amount!.toStringAsFixed(2)}');
        }
        buf.writeln();
        if (d.notes != null && d.notes!.isNotEmpty) {
          buf.writeln('    ${d.notes}');
        }
      }
      buf.writeln();
    }
    Share.share(buf.toString().trim(), subject: '$tripName — Documents');
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _activeTripId) {
        _activeTripId = next;
        _rebuildMemberName();
        _loadDocs();
        _loadAvailableSpots();
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
            title: 'Could not load documents',
            description: 'Check your connection and try again.',
            action: WabwayButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _loadDocs,
            ),
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
          child: OfflineBanner(onRetry: _loadDocs),
        ),
      ],
    );
  }

  // ── Desktop ───────────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Column(
        children: [
          _DesktopDocsBar(
            onSearchChanged: (v) => setState(() => _search = v),
            onAdd: () => _addDoc(context),
            sort: _sort,
            onSortChange: (s) => setState(() => _sort = s),
            onShare: _docs.isNotEmpty && !kIsWeb ? _shareDocs : null,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      _FilterStrip(
                        selected: _filterType,
                        onSelect: (t) => setState(() {
                          _filterType = _filterType == t ? null : t;
                        }),
                        scrollController: _filterScrollCtrl,
                      ),
                      _uploaderFilterStrip(),
                      Expanded(child: _buildDesktopList()),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: kColorBorder),
                Expanded(child: _buildDesktopDetail(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopList() {
    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: WabwayEmptyState(
          icon: Icons.folder_open_rounded,
          title: _search.isNotEmpty ? 'No results' : 'No documents',
          description: _search.isNotEmpty
              ? 'Try a different search term.'
              : 'Upload your first document.',
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(kSpace3),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
      itemBuilder: (_, i) => DocListRow(
        doc: items[i],
        selected: _selectedDocId == items[i].id,
        onTap: () => setState(() => _selectedDocId = items[i].id),
      ),
    );
  }

  Widget _buildDesktopDetail(BuildContext context) {
    final doc = _selectedDoc;
    if (doc == null) {
      return const Center(
        child: WabwayEmptyState(
          icon: Icons.insert_drive_file_rounded,
          title: 'Select a document',
          description: 'Click any document in the list to view details.',
        ),
      );
    }
    final trip = ref.read(activeTripProvider);
    return SingleChildScrollView(
      child: DocDetailContent(
        key: ValueKey(doc.id),
        doc: doc,
        tripId: trip?.id ?? _activeTripId ?? '',
        tripName: trip?.name ?? 'Trip',
        availableSpots: _availableSpots,
        onDelete: () => _deleteDoc(doc),
        onRenamed: (title) => setState(() {
          final idx = _docs.indexWhere((d) => d.id == doc.id);
          if (idx != -1) _docs[idx] = _docs[idx].copyWith(title: title);
        }),
      ),
    );
  }

  // ── Mobile ────────────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Documents', style: kStyleTitle),
        actions: [
          if (_docs.isNotEmpty && !kIsWeb)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              color: kColorInkSoft,
              tooltip: 'Share document list',
              onPressed: _shareDocs,
            ),
          PopupMenuButton<_DocSort>(
            icon: Icon(
              Icons.sort_rounded,
              color: _sort != _DocSort.newest ? kColorPrimary : kColorInkSoft,
            ),
            tooltip: 'Sort',
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => [
              _docSortItem(_DocSort.newest,       'Newest first', _sort),
              _docSortItem(_DocSort.alphabetical, 'A – Z',        _sort),
              _docSortItem(_DocSort.type,         'By type',      _sort),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: kColorInkSoft,
            onPressed: () => _addDoc(context),
          ),
          const SizedBox(width: kSpace2),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
            child: WabwayTextField(
              hint: 'Search documents…',
              prefixIcon: Icons.search_rounded,
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          _FilterStrip(
            selected: _filterType,
            onSelect: (t) => setState(() {
              _filterType = _filterType == t ? null : t;
            }),
            scrollController: _filterScrollCtrl,
          ),
          _uploaderFilterStrip(),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: WabwayEmptyState(
                      icon: Icons.folder_open_rounded,
                      title: _search.isNotEmpty ? 'No results' : 'No documents',
                      description: _search.isNotEmpty
                          ? 'Try a different search term.'
                          : 'Tap + to upload your first document.',
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(kSpace3),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: kSpace3,
                      mainAxisSpacing: kSpace3,
                      childAspectRatio: 0.68,
                    ),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) => DocGridCard(
                      doc: items[i],
                      onTap: () {
                        final trip = ref.read(activeTripProvider);
                        final doc = items[i];
                        Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => DocDetailScreen(
                              doc: doc,
                              tripId: trip?.id ?? _activeTripId ?? '',
                              tripName: trip?.name ?? 'Trip',
                              availableSpots: _availableSpots,
                              onDelete: () => _deleteDoc(doc),
                              onRenamed: (title) => setState(() {
                                final idx = _docs.indexWhere((d) => d.id == doc.id);
                                if (idx != -1) _docs[idx] = _docs[idx].copyWith(title: title);
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'docs_fab',
        onPressed: () => _addDoc(context),
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(
          'Add document',
          style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
        ),
      ),
    );
  }
}

// ── Desktop top bar ───────────────────────────────────────────────────────────

class _DesktopDocsBar extends StatelessWidget {
  const _DesktopDocsBar({
    required this.onSearchChanged,
    required this.onAdd,
    required this.sort,
    required this.onSortChange,
    this.onShare,
  });

  final ValueChanged<String> onSearchChanged;
  final VoidCallback onAdd;
  final _DocSort sort;
  final ValueChanged<_DocSort> onSortChange;
  final VoidCallback? onShare;

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
          Text('Documents', style: kStyleTitle),
          const SizedBox(width: kSpace6),
          SizedBox(
            width: 260,
            child: WabwayTextField(
              hint: 'Search documents…',
              prefixIcon: Icons.search_rounded,
              onChanged: onSearchChanged,
            ),
          ),
          const Spacer(),
          if (onShare != null)
            IconButton(
              icon: const Icon(Icons.ios_share_rounded),
              color: kColorInkSoft,
              tooltip: 'Share document list',
              onPressed: onShare,
            ),
          PopupMenuButton<_DocSort>(
            icon: Icon(
              Icons.sort_rounded,
              color: sort != _DocSort.newest ? kColorPrimary : kColorInkSoft,
            ),
            tooltip: 'Sort',
            onSelected: onSortChange,
            itemBuilder: (_) => [
              _docSortItem(_DocSort.newest,       'Newest first', sort),
              _docSortItem(_DocSort.alphabetical, 'A – Z',        sort),
              _docSortItem(_DocSort.type,         'By type',      sort),
            ],
          ),
          const SizedBox(width: kSpace2),
          WabwayButton(
            label: 'Add document',
            icon: Icons.upload_file_rounded,
            size: WabwayButtonSize.sm,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

// ── Filter strip ─────────────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.selected,
    required this.onSelect,
    required this.scrollController,
  });

  final DocType? selected;
  final ValueChanged<DocType> onSelect;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: const BoxDecoration(
        color: kColorBgRaised,
        border: Border(bottom: BorderSide(color: kColorBorder)),
      ),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
          },
        ),
        child: ListView.separated(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: kSpace3, vertical: kSpace2),
          itemCount: DocType.values.length,
          separatorBuilder: (_, __) => const SizedBox(width: kSpace1),
          itemBuilder: (_, i) {
            final type = DocType.values[i];
            return _FilterChip(
              label: type.label,
              icon: type.icon,
              color: type.color,
              selected: selected == type,
              onTap: () => onSelect(type),
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: kSpace3),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: kRadiusPill,
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.4) : kColorBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: selected ? color : kColorInkSoft),
            const SizedBox(width: kSpace1),
            Text(
              label,
              style: kStyleCaptionMedium.copyWith(
                color: selected ? color : kColorInkSoft,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

PopupMenuItem<_DocSort> _docSortItem(
    _DocSort value, String label, _DocSort current) {
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
