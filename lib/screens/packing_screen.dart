import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../core/auth/profile_state.dart';
import '../core/supabase/packing_service.dart';
import '../core/trip/app_trip_member.dart';
import '../core/trip/trip_state.dart';
import '../data/packing_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';

class PackingScreen extends StatefulWidget {
  const PackingScreen({super.key});

  @override
  State<PackingScreen> createState() => _PackingScreenState();
}

class _PackingScreenState extends State<PackingScreen> {
  List<PackingItem> _items = [];
  bool _loading = true;
  RealtimeChannel? _channel;
  Timer? _debounce;

  String _search = '';
  final _searchCtrl = TextEditingController();

  List<PackingItem> get _filtered {
    final q = _search.toLowerCase().trim();
    if (q.isEmpty) return _items;
    return _items.where((i) => i.title.toLowerCase().contains(q)).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
    _subscribe();
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
    final tripId = TripState.tripOf(context).id;
    final items = await PackingService.fetchAll(tripId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  void _subscribe() {
    final tripId = TripState.tripOf(context).id;
    _channel = PackingService.subscribe(tripId, () {
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
        title: Text('Add item', style: kStyleBodySemibold),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: kStyleBody,
          decoration: InputDecoration(
            hintText: 'e.g. Passport, charger…',
            hintStyle: TextStyle(color: kColorInkSoft.withAlpha(120)),
            border: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorPrimary, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('Add', style: TextStyle(color: kColorPrimary))),
        ],
      ),
    );
    if (confirmed != true || !mounted || ctrl.text.trim().isEmpty) return;
    final tripId = TripState.tripOf(context).id;
    final userId = ProfileState.of(context).id;
    await PackingService.addItem(tripId, ctrl.text.trim(), userId);
    _load(silent: true);
  }

  Future<void> _toggle(PackingItem item) async {
    final userId = ProfileState.of(context).id;
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) _items[idx] = item.copyWith(isPacked: !item.isPacked, packedBy: userId);
    });
    await PackingService.setPackedState(item.id, !item.isPacked, userId);
  }

  Future<void> _assign(PackingItem item) async {
    final members = TripState.membersOf(context);
    final myId    = ProfileState.of(context).id;
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

  void _reorder(int oldIndex, int newIndex, List<PackingItem> unpacked) {
    if (newIndex > oldIndex) newIndex -= 1;
    final moved = unpacked.removeAt(oldIndex);
    unpacked.insert(newIndex, moved);
    final packed = _items.where((i) => i.isPacked).toList();
    setState(() => _items = [...unpacked, ...packed]);
    PackingService.reorderItems(unpacked).catchError((_) => _load(silent: true));
  }

  Widget _buildList() {
    final visible     = _filtered;
    final canReorder  = _search.isEmpty;
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
    if (_loading) return const WabwayLoadingScaffold();

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
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: total == 0
            ? _EmptyState(onAdd: _addItem)
            : Column(
                children: [
                  WabwaySearchBar(
                    controller: _searchCtrl,
                    hint: 'Search items…',
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: WabwayEmptyState(
                              icon: Icons.search_off_rounded,
                              title: 'No results for "$_search"',
                              description: 'Try a different search term.',
                            ),
                          )
                        : _buildList(),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});
  final VoidCallback onAdd;

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
        ],
      ),
    );
  }
}

// ─── Packing tile ─────────────────────────────────────────────────────────────

enum _TileAction { assign, rename, delete }

class _PackingTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final myId   = ProfileState.maybeOf(context)?.id;
    final members = TripState.membersOf(context);

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

    return ListTile(
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
