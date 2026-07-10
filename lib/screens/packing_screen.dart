import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../core/auth/profile_state.dart';
import '../core/supabase/packing_service.dart';
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

  Future<void> _delete(PackingItem item) async {
    await PackingService.deleteItem(item.id);
    _load(silent: true);
  }

  Widget _buildList() {
    final unpacked = _items.where((i) => !i.isPacked).toList();
    final packed   = _items.where((i) => i.isPacked).toList();

    // Build a flat entry list: unpacked items, then an optional "Packed" header
    // + packed items. A null entry is used as the section header sentinel.
    final entries = <PackingItem?>[];
    entries.addAll(unpacked.map((i) => i));
    if (packed.isNotEmpty) {
      entries.add(null); // section header
      entries.addAll(packed.map((i) => i));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: kSpace3),
      itemCount: entries.length,
      itemBuilder: (_, i) {
        final entry = entries[i];
        if (entry == null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace2),
            child: Text(
              'Packed (${packed.length})',
              style: kStyleCaptionMedium.copyWith(color: kColorInkSoft),
            ),
          );
        }
        final isLast = i == entries.length - 1 ||
            (i < entries.length - 1 && entries[i + 1] == null);
        return Column(
          children: [
            _PackingTile(
              item: entry,
              onToggle: () => _toggle(entry),
              onDelete: () => _delete(entry),
            ),
            if (!isLast)
              const Divider(
                height: 1,
                indent: kSpace4 + 40 + kSpace3,
                endIndent: kSpace4,
              ),
          ],
        );
      },
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
            : _buildList(),
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

class _PackingTile extends StatelessWidget {
  const _PackingTile({
    required this.item,
    required this.onToggle,
    required this.onDelete,
  });

  final PackingItem item;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    // Resolve packedBy userId to a display name if available.
    String? packedByName;
    if (item.isPacked && item.packedBy != null) {
      final myId = ProfileState.maybeOf(context)?.id;
      if (item.packedBy == myId) {
        packedByName = 'you';
      } else {
        final members = TripState.membersOf(context);
        packedByName = members
            .where((m) => m.userId == item.packedBy)
            .firstOrNull
            ?.profile
            .displayName;
      }
    }

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
      subtitle: packedByName != null
          ? Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                'Packed by $packedByName',
                style: kStyleCaption.copyWith(color: kColorInkSoft),
              ),
            )
          : null,
      trailing: IconButton(
        icon: const Icon(Icons.close_rounded, size: 18),
        color: kColorInkSoft,
        onPressed: onDelete,
      ),
      onTap: onToggle,
    );
  }
}
