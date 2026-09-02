import 'dart:async';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../core/image_cache_manager.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/shopping_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../data/shopping_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// Fetches the og:image meta tag from a URL. Returns null on error or CORS block.
Future<String?> _fetchOgImage(String rawUrl) async {
  try {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null || !uri.hasScheme) return null;
    final resp = await http
        .get(uri, headers: {'User-Agent': 'WabWayBot/1.0'})
        .timeout(const Duration(seconds: 8));
    final body = resp.body;
    final patterns = [
      RegExp(r'''property=["']og:image["'][^>]+content=["'](https?://[^"']+)["']'''),
      RegExp(r'''content=["'](https?://[^"']+)["'][^>]+property=["']og:image["']'''),
      RegExp(r'''name=["']twitter:image["'][^>]+content=["'](https?://[^"']+)["']'''),
      RegExp(r'''content=["'](https?://[^"']+)["'][^>]+name=["']twitter:image["']'''),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(body);
      if (m != null) return m.group(1);
    }
    return null;
  } catch (_) {
    return null;
  }
}

class ShoppingScreen extends ConsumerStatefulWidget {
  const ShoppingScreen({super.key});

  @override
  ConsumerState<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends ConsumerState<ShoppingScreen> {
  String _tripId = '';
  List<ShoppingItem> _items   = [];
  bool               _loading = true;
  RealtimeChannel?   _channel;
  Timer?             _debounce;
  int                _loadGen = 0;

  String? get _userId => supabase.auth.currentUser?.id;

  List<ShoppingItem> get _unchecked => _items.where((i) => !i.checked).toList();
  List<ShoppingItem> get _checked   => _items.where((i) =>  i.checked).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tripId = ref.read(activeTripIdProvider);
      _load();
      _subscribeRealtime();
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (_tripId.isEmpty || !mounted) return;
    final gen = ++_loadGen;
    if (!silent) setState(() => _loading = true);

    if (!silent) {
      final cached = await ShoppingService.loadFromCache(_tripId);
      if (!mounted || gen != _loadGen) return;
      if (cached != null) setState(() { _items = cached; _loading = false; });
    }

    try {
      final items = await ShoppingService.loadAll(_tripId);
      if (!mounted || gen != _loadGen) return;
      setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      if (silent) return;
      setState(() => _loading = false);
    }
  }

  void _subscribeRealtime() {
    _channel?.unsubscribe();
    _channel = supabase
        .channel('shopping-$_tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'shopping_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: _tripId,
          ),
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 400),
              () { if (mounted) _load(silent: true); },
            );
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ─── Mutations ───────────────────────────────────────────────────────────────

  Future<void> _addItem(String name, {String? quantity, String? notes, String? spotId, String? linkUrl, String? imageUrl}) async {
    final userId = _userId;
    if (userId == null || name.trim().isEmpty || _tripId.isEmpty) return;
    try {
      final item = await ShoppingService.create(
        tripId:    _tripId,
        userId:    userId,
        name:      name.trim(),
        quantity:  quantity,
        notes:     notes,
        spotId:    spotId,
        sortOrder: _items.length,
        linkUrl:   linkUrl,
        imageUrl:  imageUrl,
      );
      if (!mounted) return;
      setState(() {
        _items.add(item);
        _sort();
      });
    } catch (_) {
      if (mounted) _showError('Could not add item.');
    }
  }

  Future<void> _toggleCheck(ShoppingItem item) async {
    final userId = _userId ?? '';
    final nowChecked = !item.checked;
    setState(() {
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx != -1) {
        _items[idx] = item.copyWith(
          checked:   nowChecked,
          checkedBy: nowChecked ? userId : null,
          checkedAt: nowChecked ? DateTime.now() : null,
        );
        _sort();
      }
    });
    try {
      await ShoppingService.setChecked(item.id, nowChecked, userId);
    } catch (_) {
      if (mounted) _load(silent: true);
    }
  }

  Future<void> _updateItem(ShoppingItem updated) async {
    try {
      final result = await ShoppingService.update(updated);
      if (!mounted) return;
      setState(() {
        final idx = _items.indexWhere((i) => i.id == result.id);
        if (idx != -1) _items[idx] = result;
      });
    } catch (_) {
      if (mounted) _load(silent: true);
    }
  }

  Future<void> _deleteItem(String id) async {
    setState(() => _items.removeWhere((i) => i.id == id));
    try {
      await ShoppingService.delete(id);
    } catch (_) {
      if (mounted) _load(silent: true);
    }
  }

  Future<void> _clearChecked() async {
    if (_checked.isEmpty) return;
    final count = _checked.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear checked items?'),
        content: Text(
            'Remove $count ${count == 1 ? 'item' : 'items'} from the list.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Clear',
                  style: TextStyle(color: kColorDanger))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _items.removeWhere((i) => i.checked));
    try {
      await ShoppingService.deleteChecked(_tripId);
    } catch (_) {
      if (mounted) _load(silent: true);
    }
  }

  void _sort() {
    _items.sort((a, b) {
      if (a.checked != b.checked) return a.checked ? 1 : -1;
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: kStyleBody.copyWith(color: Colors.white)),
      backgroundColor: kColorDanger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ─── UI ──────────────────────────────────────────────────────────────────────

  void _openEditSheet(ShoppingItem item) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSheet(
        item: item,
        tripId: _tripId,
        onSave: _updateItem,
        onDelete: () => _deleteItem(item.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _tripId) {
        _debounce?.cancel();
        _tripId = next;
        _load();
        _subscribeRealtime();
      }
    });
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        backgroundColor: kColorPaper,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: Text('Shopping', style: kStyleTitle),
        actions: [
          if (_checked.isNotEmpty)
            TextButton(
              onPressed: _clearChecked,
              child: Text('Clear checked',
                  style: kStyleCaption.copyWith(color: kColorDanger)),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildList()),
                _AddItemBar(tripId: _tripId, onAdd: _addItem),
              ],
            ),
    );
  }

  Widget _buildList() {
    final unchecked = _unchecked;
    final checked   = _checked;

    if (unchecked.isEmpty && checked.isEmpty) {
      return const WabwayEmptyState(
        icon: Icons.shopping_cart_outlined,
        title: 'Nothing on the list',
        description:
            'Add items below — your whole crew can check them off as you go.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace4),
      children: [
        ...unchecked.map((item) => _ShoppingItemTile(
              item: item,
              onToggle: () => _toggleCheck(item),
              onTap: () => _openEditSheet(item),
              onDelete: () => _deleteItem(item.id),
            )),
        if (checked.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: kSpace3),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace3),
                  child: Text(
                    'Checked (${checked.length})',
                    style: kStyleCaption.copyWith(color: kColorInkSoft),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          ...checked.map((item) => _ShoppingItemTile(
                item: item,
                onToggle: () => _toggleCheck(item),
                onTap: () => _openEditSheet(item),
                onDelete: () => _deleteItem(item.id),
              )),
        ],
      ],
    );
  }
}

// ─── Item tile ────────────────────────────────────────────────────────────────

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  final ShoppingItem item;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: kSpace4),
        decoration: BoxDecoration(
          color: kColorDanger.withValues(alpha: 0.1),
          borderRadius: kRadiusMd,
        ),
        child: const Icon(Icons.delete_outline_rounded, color: kColorDanger),
      ),
      onDismissed: (_) => onDelete(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: kSpace2),
        child: WabwayCard(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: kSpace3, vertical: kSpace3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: onToggle,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: item.checked ? kColorSuccess : Colors.transparent,
                      border: Border.all(
                        color: item.checked ? kColorSuccess : kColorBorder,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: item.checked
                        ? const Icon(Icons.check_rounded,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: kStyleBodyMedium.copyWith(
                                color: item.checked
                                    ? kColorInkSoft
                                    : kColorInk,
                                decoration: item.checked
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: kColorInkSoft,
                              ),
                            ),
                          ),
                          if (item.quantity != null) ...[
                            const SizedBox(width: kSpace2),
                            Text(
                              item.quantity!,
                              style: kStyleCaption.copyWith(
                                  color: kColorInkSoft),
                            ),
                          ],
                        ],
                      ),
                      if (item.spotName != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.place_rounded,
                                size: 11, color: kColorInkSoft),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text(
                                item.spotName!,
                                style: kStyleCaption.copyWith(
                                    fontSize: 11, color: kColorInkSoft),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (item.imageUrl != null) ...[
                  const SizedBox(width: kSpace2),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: CachedNetworkImage(
                      imageUrl: item.imageUrl!,
                      cacheManager: WabwayImageCache.instance,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ] else if (item.linkUrl != null) ...[
                  const SizedBox(width: kSpace2),
                  const Icon(Icons.link_rounded, size: 16, color: kColorInkSoft),
                ],
                const SizedBox(width: kSpace2),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: kColorInkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Add item bar (pinned at bottom) ─────────────────────────────────────────

class _AddItemBar extends StatefulWidget {
  const _AddItemBar({required this.tripId, required this.onAdd});

  final String tripId;
  final Future<void> Function(String name,
      {String? quantity, String? notes, String? spotId, String? linkUrl, String? imageUrl}) onAdd;

  @override
  State<_AddItemBar> createState() => _AddItemBarState();
}

class _AddItemBarState extends State<_AddItemBar> {
  final _ctrl    = TextEditingController();
  bool  _sending = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _ctrl.clear();
    await widget.onAdd(text);
    if (mounted) setState(() => _sending = false);
  }

  void _openExpanded() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSheet(
        tripId: widget.tripId,
        initialName: _ctrl.text.trim(),
        onSave: (item) async {
          _ctrl.clear();
          await widget.onAdd(
            item.name,
            quantity: item.quantity,
            notes:    item.notes,
            spotId:   item.spotId,
            linkUrl:  item.linkUrl,
            imageUrl: item.imageUrl,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        border: Border(top: BorderSide(color: kColorBorder)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace3 + bottom),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                style: kStyleBody,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: 'Add an item…',
                  hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
                  isDense: true,
                  filled: true,
                  fillColor: kColorSurfaceSunken,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: kSpace3, vertical: kSpace3),
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
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    color: kColorInkSoft,
                    tooltip: 'More options',
                    onPressed: _openExpanded,
                  ),
                ),
              ),
            ),
            const SizedBox(width: kSpace2),
            WabwayIconButton(
              icon: _sending
                  ? Icons.hourglass_empty_rounded
                  : Icons.add_rounded,
              label: 'Add',
              variant: WabwayIconButtonVariant.solid,
              onPressed: _sending ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Item sheet (add + edit) ──────────────────────────────────────────────────

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.tripId,
    this.item,
    this.initialName = '',
    required this.onSave,
    this.onDelete,
  });

  final String        tripId;
  final ShoppingItem? item;
  final String        initialName;
  final Future<void> Function(ShoppingItem item) onSave;
  final VoidCallback? onDelete;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _linkCtrl;
  late final FocusNode _linkFocus;
  bool    _saving        = false;
  bool    _deleting      = false;
  bool    _fetchingImage = false;
  String? _spotId;
  String? _spotName;
  String? _imageUrl;

  bool get _isEdit => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameCtrl  = TextEditingController(text: item?.name  ?? widget.initialName);
    _qtyCtrl   = TextEditingController(text: item?.quantity ?? '');
    _notesCtrl = TextEditingController(text: item?.notes ?? '');
    _linkCtrl  = TextEditingController(text: item?.linkUrl ?? '');
    _spotId    = item?.spotId;
    _spotName  = item?.spotName;
    _imageUrl  = item?.imageUrl;
    _linkFocus = FocusNode();
    _linkFocus.addListener(() {
      if (!_linkFocus.hasFocus) _onLinkUnfocused();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _linkCtrl.dispose();
    _linkFocus.dispose();
    super.dispose();
  }

  Future<void> _onLinkUnfocused() async {
    final url = _linkCtrl.text.trim();
    if (url.isEmpty || _imageUrl != null || _fetchingImage) return;
    setState(() => _fetchingImage = true);
    final found = await _fetchOgImage(url);
    if (!mounted) return;
    setState(() {
      _imageUrl = found;
      _fetchingImage = false;
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final link = _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim();
    final base = widget.item ?? ShoppingItem(
      id:        '',
      tripId:    widget.tripId,
      name:      name,
      createdBy: '',
      createdAt: DateTime.now(),
    );
    final updated = base.copyWith(
      name:     name,
      quantity: _qtyCtrl.text.trim().isEmpty ? null : _qtyCtrl.text.trim(),
      notes:    _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      spotId:   _spotId,
      spotName: _spotName,
      linkUrl:  link,
      imageUrl: _imageUrl,
    );
    await widget.onSave(updated);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    setState(() => _deleting = true);
    widget.onDelete?.call();
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickSpot() async {
    List<Spot> spots;
    try {
      spots = await SpotService.loadSpots(widget.tripId);
    } catch (_) {
      spots = [];
    }
    if (!mounted) return;
    final result = await showModalBottomSheet<_SpotPickResult>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SpotPicker(spots: spots, selectedId: _spotId),
    );
    if (!mounted || result == null) return;
    setState(() {
      _spotId   = result.spot?.id;
      _spotName = result.spot?.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
              child: Row(children: [WabwayDragHandle()]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 0),
              child: Row(
                children: [
                  Text(_isEdit ? 'Edit item' : 'Add item', style: kStyleTitle),
                  const Spacer(),
                  WabwayIconButton(
                    icon: Icons.close_rounded,
                    label: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(
                    kSpace4, kSpace4, kSpace4, kSpace8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WabwayTextField(
                      label: 'Item name',
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: kSpace3),
                    WabwayTextField(
                      label: 'Quantity (optional)',
                      controller: _qtyCtrl,
                      hint: 'e.g. 2, 500g, a dozen',
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: kSpace3),
                    WabwayTextField(
                      label: 'Notes (optional)',
                      controller: _notesCtrl,
                      maxLines: 2,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: kSpace3),
                    _SpotLinkRow(spotName: _spotName, onTap: _pickSpot),
                    const SizedBox(height: kSpace3),
                    WabwayTextField(
                      label: 'Link (optional)',
                      hint: 'https://…',
                      controller: _linkCtrl,
                      textInputAction: TextInputAction.done,
                      keyboardType: TextInputType.url,
                      focusNode: _linkFocus,
                    ),
                    if (_fetchingImage) ...[
                      const SizedBox(height: kSpace2),
                      Row(
                        children: [
                          const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                          const SizedBox(width: kSpace2),
                          Text('Fetching preview…',
                              style: kStyleCaption.copyWith(color: kColorInkSoft)),
                        ],
                      ),
                    ],
                    if (_imageUrl != null) ...[
                      const SizedBox(height: kSpace3),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: kRadiusMd,
                            child: CachedNetworkImage(
                              imageUrl: _imageUrl!,
                              cacheManager: WabwayImageCache.instance,
                              height: 160,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                            ),
                          ),
                          Positioned(
                            top: kSpace2,
                            right: kSpace2,
                            child: GestureDetector(
                              onTap: () => setState(() => _imageUrl = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: kRadiusMd,
                                ),
                                child: const Icon(Icons.close_rounded,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: kSpace5),
                    WabwayButton(
                      label: _isEdit ? 'Save' : 'Add to list',
                      loading: _saving,
                      onPressed: _saving || _deleting ? null : _save,
                      fullWidth: true,
                      size: WabwayButtonSize.lg,
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: kSpace3),
                      WabwayButton(
                        label: 'Delete item',
                        variant: WabwayButtonVariant.ghost,
                        loading: _deleting,
                        onPressed: _saving || _deleting ? null : _delete,
                        fullWidth: true,
                        size: WabwayButtonSize.lg,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Spot link row ────────────────────────────────────────────────────────────

class _SpotLinkRow extends StatelessWidget {
  const _SpotLinkRow({required this.spotName, required this.onTap});

  final String?      spotName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLinked = spotName != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 14),
        decoration: BoxDecoration(
          color: kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border: Border.all(
            color: isLinked
                ? kColorPrimary.withValues(alpha: 0.4)
                : kColorBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isLinked ? Icons.place_rounded : Icons.link_rounded,
              size: 16,
              color: isLinked ? kColorPrimary : kColorInkSoft,
            ),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Linked spot', style: kStyleOverline),
                  const SizedBox(height: 2),
                  Text(
                    isLinked ? spotName! : 'None — tap to link',
                    style: kStyleBody.copyWith(
                        color: isLinked ? kColorInk : kColorInkSoft),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: kColorInkSoft),
          ],
        ),
      ),
    );
  }
}

// ─── Spot picker ──────────────────────────────────────────────────────────────

class _SpotPickResult {
  const _SpotPickResult(this.spot);
  final Spot? spot;
}

class _SpotPicker extends StatelessWidget {
  const _SpotPicker({required this.spots, required this.selectedId});

  final List<Spot> spots;
  final String?    selectedId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollCtrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
              child: Row(children: [WabwayDragHandle()]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  kSpace4, kSpace2, kSpace4, kSpace3),
              child: Row(
                children: [
                  Text('Link to spot', style: kStyleTitle),
                  const Spacer(),
                  WabwayIconButton(
                    icon: Icons.close_rounded,
                    label: 'Close',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: kSpace4, vertical: kSpace3),
                children: [
                  if (selectedId != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.link_off_rounded,
                          color: kColorDanger),
                      title: Text('Remove link',
                          style:
                              kStyleBody.copyWith(color: kColorDanger)),
                      onTap: () => Navigator.pop(
                          context, const _SpotPickResult(null)),
                    ),
                  if (spots.isEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: kSpace8),
                      child: Text(
                        'No spots in this trip yet.',
                        style: kStyleCaption.copyWith(color: kColorInkSoft),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ...spots.map((s) {
                    final sel = s.id == selectedId;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(s.category.icon,
                          color: sel ? kColorPrimary : kColorInkSoft,
                          size: 20),
                      title: Text(s.name,
                          style: kStyleBody.copyWith(
                            color: sel ? kColorPrimary : kColorInk,
                            fontWeight:
                                sel ? FontWeight.w600 : FontWeight.normal,
                          )),
                      subtitle: Text(s.city,
                          style: kStyleCaption.copyWith(
                              color: kColorInkSoft)),
                      trailing: sel
                          ? const Icon(Icons.check_circle_rounded,
                              color: kColorPrimary)
                          : null,
                      onTap: () =>
                          Navigator.pop(context, _SpotPickResult(s)),
                    );
                  }),
                  const SizedBox(height: kSpace8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
