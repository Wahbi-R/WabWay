import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import '../core/auth/profile_state.dart';
import '../core/supabase/pins_service.dart';
import '../core/trip/trip_state.dart';
import '../data/pins_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';

class PinsScreen extends StatefulWidget {
  const PinsScreen({super.key});

  @override
  State<PinsScreen> createState() => _PinsScreenState();
}

class _PinsScreenState extends State<PinsScreen> {
  List<TripPin> _pins = [];
  bool _loading = true;
  String _tripId = '';
  String _myId = '';
  RealtimeChannel? _channel;
  Timer? _debounce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tripId = TripState.tripOf(context).id;
    _myId   = ProfileState.of(context).id;
    _load();
    _channel ??= PinsService.subscribe(_tripId, () {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 400), () => _load(silent: true));
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final pins = await PinsService.fetchAll(_tripId);
    if (mounted) setState(() { _pins = pins; _loading = false; });
  }

  void _addPin() async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Post to pinboard', style: kStyleBodySemibold),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share a note with the whole group (check-in codes, meet times, reminders).',
              style: kStyleCaption,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 3,
              maxLength: 500,
              style: kStyleBody,
              decoration: InputDecoration(
                hintText: 'e.g. Airbnb code is 4821, check-in after 3 pm…',
                hintStyle: TextStyle(color: kColorInkSoft.withAlpha(120)),
                border: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: kRadiusMd, borderSide: BorderSide(color: kColorPrimary, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Post', style: TextStyle(color: kColorPrimary)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || ctrl.text.trim().isEmpty) return;
    await PinsService.post(tripId: _tripId, authorId: _myId, body: ctrl.text.trim());
    _load(silent: true);
  }

  Future<void> _unpin(TripPin pin) async {
    await PinsService.unpin(pin.id);
    _load(silent: true);
  }

  Future<void> _delete(TripPin pin) async {
    await PinsService.delete(pin.id);
    _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const WabwayLoadingScaffold();

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Pinboard', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: kColorInkSoft,
            tooltip: 'Post a note',
            onPressed: _addPin,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: _pins.isEmpty
            ? _EmptyState(onAdd: _addPin)
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: kSpace3),
                itemCount: _pins.length,
                separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
                itemBuilder: (_, i) => _PinCard(
                  pin: _pins[i],
                  myId: _myId,
                  onUnpin: () => _unpin(_pins[i]),
                  onDelete: () => _delete(_pins[i]),
                ),
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
          const Icon(Icons.push_pin_outlined, size: 48, color: kColorInkSoft),
          const SizedBox(height: 16),
          Text('Pinboard is empty', style: kStyleBodyMedium),
          const SizedBox(height: 8),
          Text('Post notes the whole group can see.', style: kStyleCaption, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Post a note'),
            style: FilledButton.styleFrom(backgroundColor: kColorPrimary),
          ),
        ],
      ),
    );
  }
}

// ─── Pin card ─────────────────────────────────────────────────────────────────

class _PinCard extends StatelessWidget {
  const _PinCard({
    required this.pin,
    required this.myId,
    required this.onUnpin,
    required this.onDelete,
  });

  final TripPin pin;
  final String myId;
  final VoidCallback onUnpin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isMe = pin.authorId == myId;
    final members = TripState.membersOf(context);
    final match = members.where((m) => m.userId == pin.authorId).firstOrNull;
    final name = isMe
        ? 'You'
        : match?.profile.displayName ??
          (pin.authorId.length >= 8 ? pin.authorId.substring(0, 8) : pin.authorId);

    final pinColor = pin.isPinned ? kColorPrimary : kColorInkSoft;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      child: WabwayCard(
        child: Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    pin.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                    size: 14,
                    color: pinColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    pin.isPinned ? 'Pinned' : 'Unpinned',
                    style: kStyleOverline.copyWith(color: pinColor),
                  ),
                  const Spacer(),
                  Text(
                    _fmtPinTime(pin.createdAt),
                    style: kStyleOverline,
                  ),
                  if (isMe) ...[
                    const SizedBox(width: kSpace2),
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_horiz_rounded, size: 18, color: kColorInkSoft),
                      itemBuilder: (_) => [
                        if (pin.isPinned)
                          const PopupMenuItem(value: 'unpin', child: Text('Unpin')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                      onSelected: (v) => v == 'unpin' ? onUnpin() : onDelete(),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: kSpace2),
              Text(pin.body, style: kStyleBody),
              const SizedBox(height: kSpace2),
              Row(
                children: [
                  WabwayAvatar(name: name, size: WabwayAvatarSize.xs),
                  const SizedBox(width: kSpace2),
                  Text(name, style: kStyleCaption),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtPinTime(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  return '${diff.inDays}d ago';
}
