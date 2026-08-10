import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/packing_service.dart';
import '../core/trip/app_trip_member.dart';
import '../data/packing_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';

class PackingScreen extends ConsumerStatefulWidget {
  const PackingScreen({super.key});

  @override
  ConsumerState<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends ConsumerState<PackingScreen> {
  List<PackingItem> _items = [];
  bool _loading = true;
  RealtimeChannel? _channel;
  Timer? _debounce;

  String _tripId = '';
  String _myId   = '';

  String _search = '';
  bool   _mineOnly = false;
  final _searchCtrl = TextEditingController();

  List<PackingItem> _getFiltered(String myId) {
    final q = _search.toLowerCase().trim();
    return _items.where((i) {
      if (q.isNotEmpty && !i.title.toLowerCase().contains(q)) return false;
      if (_mineOnly && i.assignedTo != myId) return false;
      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tripId = ref.read(activeTripIdProvider);
      _myId   = ref.read(profileProvider)?.id ?? '';
      _load();
      _subscribe();
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    final items = await PackingService.fetchAll(_tripId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _subscribe() {
    _channel = PackingService.subscribe(_tripId, () {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () => _load(silent: true));
    });
  }

  void _addItem() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Add items', style: kStyleBodySemibold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              style: kStyleBody,
              decoration: InputDecoration(
                hintText: 'Passport, charger, adapter…',
                hintStyle: TextStyle(color: kColorInkSoft.withAlpha(120)),
                border: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorPrimary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 6),
            Text(
              'Separate multiple items with commas',
              style: kStyleCaption.copyWith(color: kColorInkSoft, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Add', style: TextStyle(color: kColorPrimary))),
        ],
      ),
    );
    if (confirmed != true || !mounted || ctrl.text.trim().isEmpty) return;
    final tripId = _tripId;
    final userId = _myId;
    final titles = ctrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    for (final title in titles) {
      await PackingService.addItem(tripId, title, userId);
    }
    if (mounted && titles.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Added ${titles.length} items',
            style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    }
    _load(silent: true);
  }

  Future<void> _toggle(PackingItem item) async {
    final userId = _myId;
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) _items[idx] = item.copyWith(isPacked: !item.isPacked, packedBy: userId);
    });
    await PackingService.setPackedState(item.id, !item.isPacked, userId);
  }

  Future<void> _assign(PackingItem item) async {
    final members = ref.read(tripMembersProvider);
    final myId    = _myId;
    final result  = await showDialog<({String? userId})>(
      context: context,
      builder: (_) => _AssignDialog(
        members:  members,
        myId:     myId,
        current:  item.assignedTo,
      ),
    );
    if (result == null || !mounted) return;
    final newAssignee = result.userId;
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) {
        _items[idx] = PackingItem(
          id:         item.id,
          tripId:     item.tripId,
          title:      item.title,
          isPacked:   item.isPacked,
          createdBy:  item.createdBy,
          assignedTo: newAssignee,
          packedBy:   item.packedBy,
          sortOrder:  item.sortOrder,
        );
      }
    });
    await PackingService.assignItem(item.id, newAssignee);
  }

  Future<void> _rename(PackingItem item) async {
    final ctrl = TextEditingController(text: item.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Rename item', style: kStyleBodySemibold),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: kStyleBody,
          decoration: InputDecoration(
            hintText: 'Item name',
            hintStyle: TextStyle(color: kColorInkSoft.withAlpha(120)),
            border: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorPrimary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Save', style: TextStyle(color: kColorPrimary))),
        ],
      ),
    );
    if (confirmed != true || !mounted || ctrl.text.trim().isEmpty || ctrl.text.trim() == item.title) return;
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) _items[idx] = item.copyWith(title: ctrl.text.trim());
    });
    await PackingService.renameItem(item.id, ctrl.text.trim());
  }

  Future<void> _delete(PackingItem item) async {
    await PackingService.deleteItem(item.id);
    _load(silent: true);
  }

  Future<void> _packAll() async {
    final unpacked = _items.where((i) => !i.isPacked).toList();
    if (unpacked.isEmpty) return;
    final tripId = _tripId;
    final userId = _myId;
    setState(() {
      _items = _items.map((i) => i.isPacked ? i : i.copyWith(isPacked: true, packedBy: userId)).toList();
    });
    PackingService.packAllItems(tripId, userId).catchError((_) => _load(silent: true));
  }

  Future<void> _clearPacked() async {
    final packed = _items.where((i) => i.isPacked).toList();
    if (packed.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear packed items?'),
        content: Text(
          '${packed.length} packed ${packed.length == 1 ? 'item' : 'items'} will be permanently removed from the list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _items.removeWhere((i) => i.isPacked));
    PackingService.clearPackedItems(_tripId).catchError((_) => _load(silent: true));
  }

  Future<void> _addFromTemplate() async {
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _TemplateSheet(),
    );
    if (result == null || result.isEmpty || !mounted) return;

    final tripId = _tripId;
    final userId = _myId;
    final existing = _items.map((i) => i.title.toLowerCase()).toSet();
    final toAdd = result.where((t) => !existing.contains(t.toLowerCase())).toList();
    if (toAdd.isEmpty) return;

    for (final title in toAdd) {
      await PackingService.addItem(tripId, title, userId);
    }
    _load(silent: true);
  }

  void _shareList() {
    if (_items.isEmpty) return;
    final tripName = ref.read(activeTripProvider)?.name ?? 'Trip';
    final buf = StringBuffer();
    buf.writeln('$tripName — Packing List');
    buf.writeln();
    final unpacked = _items.where((i) => !i.isPacked).toList();
    final packed   = _items.where((i) => i.isPacked).toList();
    for (final item in unpacked) buf.writeln('□ ${item.title}');
    if (packed.isNotEmpty) {
      buf.writeln();
      buf.writeln('Packed (${packed.length})');
      for (final item in packed) buf.writeln('✓ ${item.title}');
    }
    Share.share(buf.toString().trim(), subject: '$tripName — Packing List');
  }

  void _reorder(int oldIndex, int newIndex, List<PackingItem> unpacked) {
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = unpacked.removeAt(oldIndex);
    unpacked.insert(newIndex, moved);
    final packed = _items.where((i) => i.isPacked).toList();
    setState(() => _items = [...unpacked, ...packed]);
    PackingService.reorderItems(unpacked).catchError((_) => _load(silent: true));
  }

  Widget _buildList(List<PackingItem> filtered) {
    final visible     = filtered;
    final canReorder  = _search.isEmpty && !_mineOnly;
    final unpacked    = canReorder
        ? _items.where((i) => !i.isPacked).toList()
        : visible.where((i) => !i.isPacked).toList();
    final packed      = visible.where((i) => i.isPacked).toList();

    Widget tile(PackingItem entry, {int? index, bool showHandle = false}) =>
        _PackingTile(
          key: ValueKey(entry.id),
          item: entry,
          onToggle: () => _toggle(entry),
          onAssign: () => _assign(entry),
          onRename: () => _rename(entry),
          onDelete: () => _delete(entry),
          index: index,
          showHandle: showHandle,
        );

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.only(top: kSpace3),
          sliver: SliverReorderableList(
            itemCount: unpacked.length,
            itemBuilder: (_, i) {
              final entry = unpacked[i];
              final isLast = i == unpacked.length - 1;
              return KeyedSubtree(
                key: ValueKey(entry.id),
                child: Column(
                  children: [
                    tile(entry, index: i, showHandle: canReorder),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        indent: kSpace4 + 40 + kSpace3,
                        endIndent: kSpace4,
                      ),
                  ],
                ),
              );
            },
            onReorder: (oldIdx, newIdx) =>
                _reorder(oldIdx, newIdx, List.of(unpacked)),
            proxyDecorator: (child, _, animation) => Material(
              elevation: 4,
              shadowColor: kColorInk.withValues(alpha: 0.12),
              borderRadius: kRadiusMd,
              child: child,
            ),
          ),
        ),
        if (packed.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace2),
              child: Text(
                'Packed (${packed.length})',
                style: kStyleCaptionMedium.copyWith(color: kColorInkSoft),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final entry = packed[i];
                final isLast = i == packed.length - 1;
                return Column(
                  children: [
                    tile(entry),
                    if (!isLast)
                      const Divider(
                        height: 1,
                        indent: kSpace4 + 40 + kSpace3,
                        endIndent: kSpace4,
                      ),
                  ],
                );
              },
              childCount: packed.length,
            ),
          ),
        ],
        const SliverPadding(padding: EdgeInsets.only(bottom: kSpace8)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _tripId) {
        _tripId = next;
        _myId   = ref.read(profileProvider)?.id ?? '';
        _load();
        _subscribe();
      }
    });
    if (_loading) return const WabwayLoadingScaffold();

    final myId  = _myId;
    final filtered = _getFiltered(myId);
    final packed = _items.where((i) => i.isPacked).length;
    final total = _items.length;

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Packing List', style: kStyleTitle),
        actions: [
          if (total > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  '$packed / $total',
                  style: kStyleCaptionMedium.copyWith(
                    color: packed == total && total > 0 ? kColorSuccess : kColorInkSoft,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: kColorInkSoft,
            tooltip: 'Add item',
            onPressed: _addItem,
          ),
          PopupMenuButton<String>(
            iconColor: kColorInkSoft,
            onSelected: (v) {
              if (v == 'template') _addFromTemplate();
              if (v == 'clear_packed') _clearPacked();
              if (v == 'share') _shareList();
              if (v == 'pack_all') _packAll();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'template',
                child: Row(children: [
                  Icon(Icons.list_alt_rounded, size: 16),
                  SizedBox(width: 10),
                  Text('Add from template'),
                ]),
              ),
              if (total > packed)
                const PopupMenuItem(
                  value: 'pack_all',
                  child: Row(children: [
                    Icon(Icons.check_circle_rounded, size: 16),
                    SizedBox(width: 10),
                    Text('Pack all items'),
                  ]),
                ),
              if (!kIsWeb && total > 0)
                const PopupMenuItem(
                  value: 'share',
                  child: Row(children: [
                    Icon(Icons.ios_share_rounded, size: 16),
                    SizedBox(width: 10),
                    Text('Share list'),
                  ]),
                ),
              if (packed > 0)
                const PopupMenuItem(
                  value: 'clear_packed',
                  child: Row(children: [
                    Icon(Icons.delete_sweep_rounded, size: 16, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Clear packed items', style: TextStyle(color: Colors.red)),
                  ]),
                ),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: total == 0
            ? _EmptyState(onAdd: _addItem, onTemplate: _addFromTemplate)
            : Column(
                children: [
                  WabwaySearchBar(
                    controller: _searchCtrl,
                    hint: 'Search items…',
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  if (_items.any((i) => i.assignedTo != null))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace2),
                      child: Row(
                        children: [
                          FilterChip(
                            label: const Text('Mine only'),
                            selected: _mineOnly,
                            onSelected: (v) => setState(() => _mineOnly = v),
                            selectedColor: kColorPrimarySoft,
                            checkmarkColor: kColorPrimary,
                            side: BorderSide(
                              color: _mineOnly
                                  ? kColorPrimarySoftBorder
                                  : kColorBorder,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: kRadiusPill,
                            ),
                            labelStyle: kStyleCaption.copyWith(
                              color: _mineOnly ? kColorPrimary : kColorInk,
                              fontWeight: _mineOnly ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  _PackingProgress(packed: packed, total: total),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: WabwayEmptyState(
                              icon: _mineOnly
                                  ? Icons.person_off_rounded
                                  : Icons.search_off_rounded,
                              title: _mineOnly
                                  ? 'No items assigned to you'
                                  : 'No results for "$_search"',
                              description: _mineOnly
                                  ? 'Ask a crew member to assign you some items.'
                                  : 'Try a different search term.',
                            ),
                          )
                        : _buildList(filtered),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd, required this.onTemplate});
  final VoidCallback onAdd;
  final VoidCallback onTemplate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.luggage_rounded, size: 48, color: kColorInkSoft),
          const SizedBox(height: 16),
          Text('Nothing to pack yet', style: kStyleBodyMedium),
          const SizedBox(height: 8),
          Text('Add items your group needs to bring.', style: kStyleCaption),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add item'),
            style: FilledButton.styleFrom(backgroundColor: kColorPrimary),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onTemplate,
            icon: const Icon(Icons.list_alt_rounded, size: 18),
            label: const Text('Add from template'),
            style: OutlinedButton.styleFrom(foregroundColor: kColorPrimary),
          ),
        ],
      ),
    );
  }
}

// ─── Progress bar ─────────────────────────────────────────────────────────────

class _PackingProgress extends StatelessWidget {
  const _PackingProgress({required this.packed, required this.total});
  final int packed;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();
    final progress = packed / total;
    final allDone  = packed == total;
    final color    = allDone ? kColorSuccess : kColorPrimary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: kRadiusPill,
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: kColorBorder,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: kSpace3),
              Text(
                allDone ? 'All packed!' : '$packed of $total packed',
                style: kStyleCaption.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
        ],
      ),
    );
  }
}

// ─── Template sheet ───────────────────────────────────────────────────────────

const _kTemplates = <({String category, IconData icon, List<String> items})>[
  (
    category: 'Documents',
    icon: Icons.badge_rounded,
    items: ['Passport', 'Travel insurance', 'Flight tickets', 'Hotel bookings', 'Visa / entry docs', 'Driver\'s licence', 'Credit cards', 'Emergency contacts'],
  ),
  (
    category: 'Toiletries',
    icon: Icons.soap_rounded,
    items: ['Toothbrush', 'Toothpaste', 'Shampoo', 'Conditioner', 'Body wash', 'Deodorant', 'Sunscreen', 'Razor', 'Lip balm', 'Hand sanitiser'],
  ),
  (
    category: 'Clothes',
    icon: Icons.checkroom_rounded,
    items: ['T-shirts', 'Underwear', 'Socks', 'Jeans / trousers', 'Jacket', 'Pyjamas', 'Swimwear', 'Comfortable shoes', 'Sandals', 'Hat / cap'],
  ),
  (
    category: 'Electronics',
    icon: Icons.devices_rounded,
    items: ['Phone charger', 'Power bank', 'Adapter / converter', 'Earphones / AirPods', 'Camera', 'Laptop', 'Laptop charger', 'E-reader'],
  ),
  (
    category: 'Health & Meds',
    icon: Icons.medical_services_rounded,
    items: ['Prescription medication', 'Pain reliever', 'Antihistamine', 'Band-aids / plasters', 'Insect repellent', 'Motion sickness pills'],
  ),
  (
    category: 'Comfort & Entertainment',
    icon: Icons.headphones_rounded,
    items: ['Neck pillow', 'Eye mask', 'Earplugs', 'Snacks', 'Book / magazine', 'Playing cards'],
  ),
];

class _TemplateSheet extends StatefulWidget {
  const _TemplateSheet();

  @override
  State<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<_TemplateSheet> {
  final _selected = <String>{};
  int? _expandedCategory;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
            child: Row(
              children: [
                Expanded(child: Text('Add from template', style: kStyleTitle)),
                if (_selected.isNotEmpty)
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _selected.toList()),
                    style: FilledButton.styleFrom(
                      backgroundColor: kColorPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
                    ),
                    child: Text('Add ${_selected.length}'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
            child: Text(
              'Tap items to select, then tap Add.',
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: ctrl,
              itemCount: _kTemplates.length,
              itemBuilder: (_, i) {
                final cat = _kTemplates[i];
                final expanded = _expandedCategory == i;
                final selectedInCat = cat.items.where(_selected.contains).length;
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(cat.icon, color: kColorPrimary, size: 20),
                      title: Text(cat.category, style: kStyleBodySemibold),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectedInCat > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: kColorPrimary, borderRadius: kRadiusPill),
                              child: Text('$selectedInCat', style: kStyleCaption.copyWith(color: Colors.white)),
                            ),
                          const SizedBox(width: kSpace2),
                          Icon(expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: kColorInkSoft),
                        ],
                      ),
                      onTap: () => setState(() => _expandedCategory = expanded ? null : i),
                    ),
                    if (expanded)
                      ...cat.items.map((item) {
                        final sel = _selected.contains(item);
                        return CheckboxListTile(
                          value: sel,
                          onChanged: (_) => setState(() {
                            if (sel) _selected.remove(item); else _selected.add(item);
                          }),
                          title: Text(item, style: kStyleBody),
                          activeColor: kColorPrimary,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.only(left: kSpace10, right: kSpace4),
                          dense: true,
                        );
                      }),
                    const Divider(height: 1),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(kSpace4),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.pop(context, _selected.toList()),
                  style: FilledButton.styleFrom(
                    backgroundColor: kColorPrimary,
                    disabledBackgroundColor: kColorBorder,
                    padding: const EdgeInsets.symmetric(vertical: kSpace3),
                    shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
                  ),
                  child: Text(
                    _selected.isEmpty ? 'Select items to add' : 'Add ${_selected.length} item${_selected.length == 1 ? '' : 's'}',
                    style: kStyleBodySemibold.copyWith(color: Colors.white),
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

// ─── Packing tile ─────────────────────────────────────────────────────────────

enum _TileAction { assign, rename, delete }

class _PackingTile extends ConsumerWidget {
  const _PackingTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onAssign,
    required this.onRename,
    required this.onDelete,
    this.index,
    this.showHandle = false,
  });

  final PackingItem item;
  final VoidCallback onToggle;
  final VoidCallback onAssign;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final int? index;
  final bool showHandle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myId   = ref.watch(profileProvider)?.id;
    final members = ref.watch(tripMembersProvider);

    // Resolve packedBy to a display name (shown when packed).
    String? packedByName;
    if (item.isPacked && item.packedBy != null) {
      packedByName = item.packedBy == myId
          ? 'you'
          : members.where((m) => m.userId == item.packedBy).firstOrNull?.profile.displayName;
    }

    // Resolve assignedTo to a display name (shown when not packed).
    String? assignedToName;
    if (!item.isPacked && item.assignedTo != null) {
      assignedToName = item.assignedTo == myId
          ? 'you'
          : members.where((m) => m.userId == item.assignedTo).firstOrNull?.profile.displayName;
    }

    final subtitleText = packedByName != null
        ? 'Packed by $packedByName'
        : assignedToName != null
            ? 'Assigned to $assignedToName'
            : null;

    final alreadyAssigned = item.assignedTo != null;

    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: 2),
      leading: GestureDetector(
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: item.isPacked ? kColorPrimary : Colors.transparent,
            border: Border.all(
              color: item.isPacked ? kColorPrimary : kColorBorder,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: item.isPacked
              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
              : null,
        ),
      ),
      title: Text(
        item.title,
        style: kStyleBodyMedium.copyWith(
          decoration: item.isPacked ? TextDecoration.lineThrough : null,
          color: item.isPacked ? kColorInkSoft : kColorInk,
        ),
      ),
      subtitle: subtitleText != null
          ? Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                subtitleText,
                style: kStyleCaption.copyWith(color: kColorInkSoft),
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PopupMenuButton<_TileAction>(
            icon: const Icon(Icons.more_vert_rounded, size: 18, color: kColorInkSoft),
            padding: EdgeInsets.zero,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: _TileAction.assign,
                child: Text(alreadyAssigned ? 'Reassign' : 'Assign to...'),
              ),
              const PopupMenuItem(value: _TileAction.rename, child: Text('Rename')),
              PopupMenuItem(
                value: _TileAction.delete,
                child: Text('Delete', style: TextStyle(color: kColorDanger)),
              ),
            ],
            onSelected: (action) {
              switch (action) {
                case _TileAction.assign: onAssign();
                case _TileAction.rename: onRename();
                case _TileAction.delete: onDelete();
              }
            },
          ),
          if (showHandle && index != null)
            ReorderableDragStartListener(
              index: index!,
              child: const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.drag_handle_rounded, size: 18, color: kColorInkSoft),
              ),
            ),
        ],
      ),
      onTap: onToggle,
    );

    return Dismissible(
      key: ValueKey('swipe_${item.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onToggle();
        return false;
      },
      background: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: kSpace5),
        color: item.isPacked
            ? kColorSurfaceSunken
            : kColorPrimary.withValues(alpha: 0.1),
        child: Icon(
          item.isPacked ? Icons.undo_rounded : Icons.check_rounded,
          color: item.isPacked ? kColorInkSoft : kColorPrimary,
          size: 20,
        ),
      ),
      child: tile,
    );
  }
}

// ─── Assign dialog ────────────────────────────────────────────────────────────

class _AssignDialog extends StatefulWidget {
  const _AssignDialog({
    required this.members,
    required this.myId,
    this.current,
  });
  final List<AppTripMember> members;
  final String myId;
  final String? current;

  @override
  State<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<_AssignDialog> {
  late String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.current;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
      title: Text('Assign to', style: kStyleBodySemibold),
      contentPadding: const EdgeInsets.symmetric(vertical: kSpace2),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String?>(
              title: Text('No one', style: kStyleBody),
              value: null,
              groupValue: _selected,
              activeColor: kColorPrimary,
              onChanged: (v) => setState(() => _selected = v),
            ),
            ...widget.members.map((m) {
              final name = m.userId == widget.myId
                  ? '${m.profile.displayName} (you)'
                  : m.profile.displayName;
              return RadioListTile<String?>(
                title: Text(name, style: kStyleBody),
                value: m.userId,
                groupValue: _selected,
                activeColor: kColorPrimary,
                onChanged: (v) => setState(() => _selected = v),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: kStyleBody.copyWith(color: kColorInkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, (userId: _selected)),
          child: Text('Assign', style: kStyleBodyMedium.copyWith(color: kColorPrimary)),
        ),
      ],
    );
  }
}
