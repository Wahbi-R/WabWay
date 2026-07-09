import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/auth/profile_state.dart';
import '../core/supabase/client.dart';
import '../core/supabase/photo_album_service.dart';
import '../core/trip/trip_state.dart';
import '../data/photo_album_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'photos/add_album_sheet.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  List<TripPhotoAlbum> _albums = [];
  bool _loading = true;
  bool _error   = false;
  bool _offline  = false;
  String? _activeTripId;
  RealtimeChannel? _channel;
  Timer? _debounce;

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
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribe(String tripId) {
    _channel?.unsubscribe();
    _channel = supabase
        .channel('trip_photo_albums-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trip_photo_albums',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(
                const Duration(milliseconds: 400), () => _load(silent: true));
          },
        )
        .subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = false; });
    try {
      final albums = await PhotoAlbumService.loadAlbums(_activeTripId!);
      if (mounted) {
        setState(() {
          _albums  = albums;
          _loading = false;
          _error   = false;
          _offline  = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      if (silent) { setState(() => _offline = true); return; }
      setState(() { _loading = false; _error = true; });
    }
  }

  Future<void> _addAlbum() async {
    final userId = ProfileState.of(context).id;
    final album  = await showAddAlbumSheet(
      context,
      tripId: _activeTripId!,
      userId: userId,
    );
    if (album != null && mounted) {
      setState(() => _albums = [album, ..._albums]);
    }
  }

  Future<void> _delete(TripPhotoAlbum album) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Remove album?', style: kStyleBodySemibold),
        content: Text(
          '"${album.title}" will be removed for everyone.',
          style: kStyleBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: kStyleBody.copyWith(color: kColorInkSoft)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Remove',
                style: kStyleBodyMedium.copyWith(color: kColorDanger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _albums = _albums.where((a) => a.id != album.id).toList());
    try {
      await PhotoAlbumService.deleteAlbum(album.id);
    } catch (_) {
      if (mounted) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ProfileState.maybeOf(context)?.id;
    final members = TripState.membersOf(context);

    final scaffold = Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Photos', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            color: kColorPrimary,
            tooltip: 'Add album',
            onPressed: _addAlbum,
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
                    description: 'Could not load albums.',
                    action: WabwayButton(label: 'Retry', onPressed: _load),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      kSpace4,
                      kSpace3,
                      kSpace4,
                      kSpace8 + MediaQuery.paddingOf(context).bottom,
                    ),
                    children: [
                      _GuideCard(expanded: _albums.isEmpty),
                      const SizedBox(height: kSpace4),
                      if (_albums.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: kSpace6),
                            child: WabwayEmptyState(
                              icon: Icons.photo_library_outlined,
                              title: 'No albums yet',
                              description:
                                  'Add a link to your Google Photos album, iCloud shared album, or any photo collection.',
                              action: WabwayButton(
                                label: 'Add album',
                                icon: Icons.add_rounded,
                                onPressed: _addAlbum,
                              ),
                            ),
                          ),
                        )
                      else
                        ...(_albums.map((album) {
                          final ms = members.where((m) => m.userId == album.addedById);
                          final member = ms.isEmpty ? null : ms.first;
                          final isOwn = album.addedById == currentUserId;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: kSpace3),
                            child: _AlbumCard(
                              album: album,
                              memberName: member?.profile.displayName,
                              memberInitials: member?.profile.initials,
                              isOwn: isOwn,
                              onDelete: isOwn ? () => _delete(album) : null,
                            ),
                          );
                        }).toList()),
                    ],
                  ),
                ),
      floatingActionButton: _albums.isNotEmpty
          ? FloatingActionButton(
              onPressed: _addAlbum,
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

// ─── Guide card ───────────────────────────────────────────────────────────────

class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.expanded});
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kColorPrimarySoft,
              borderRadius: kRadiusSm,
            ),
            child: const Icon(Icons.tips_and_updates_rounded,
                size: 18, color: kColorPrimary),
          ),
          title: Text('How to share trip photos', style: kStyleBodySemibold),
          subtitle: Text('Set up a shared album for the whole group',
              style: kStyleCaption.copyWith(color: kColorInkSoft)),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: kSpace4),
                  _GuideSection(
                    serviceIcon: Icons.photo_library_rounded,
                    serviceColor: const Color(0xFF4285F4),
                    serviceSoftColor: const Color(0xFFE8F0FE),
                    title: 'Google Photos — recommended',
                    subtitle: 'Everyone can add photos directly to one shared album',
                    steps: const [
                      'Open Google Photos → tap Library → New album',
                      'Name it (e.g. "Japan 2026") and tap Create',
                      'Tap the share icon → Invite by link or add contacts',
                      'Turn on "Collaborators can add photos & videos"',
                      'Everyone who joins can upload from their own phone',
                      'Paste the share link here using the + button above',
                    ],
                    tip: 'Auto-backup tip: open the shared album → three-dot menu → "Automatically add photos" — Google Photos will suggest your camera roll shots to add.',
                  ),
                  const SizedBox(height: kSpace5),
                  _GuideSection(
                    serviceIcon: Icons.cloud_rounded,
                    serviceColor: const Color(0xFF3478F6),
                    serviceSoftColor: const Color(0xFFE8F1FB),
                    title: 'iCloud Shared Album',
                    subtitle: 'Works well if everyone is on iPhone',
                    steps: const [
                      'Open Photos → Albums → New Shared Album',
                      'Name the album and invite trip members by iCloud / email',
                      'Members can upload from their own library to the shared album',
                      'Paste the album link here (or share via Messages)',
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.serviceIcon,
    required this.serviceColor,
    required this.serviceSoftColor,
    required this.title,
    required this.subtitle,
    required this.steps,
    this.tip,
  });

  final IconData serviceIcon;
  final Color    serviceColor;
  final Color    serviceSoftColor;
  final String   title;
  final String   subtitle;
  final List<String> steps;
  final String? tip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: serviceSoftColor,
                borderRadius: kRadiusSm,
              ),
              child: Icon(serviceIcon, size: 15, color: serviceColor),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: kStyleBodySemibold),
                  Text(subtitle,
                      style: kStyleCaption.copyWith(color: kColorInkSoft)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: kSpace3),
        ...steps.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: kSpace2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: serviceSoftColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${e.key + 1}',
                        style: kStyleCaption.copyWith(
                            color: serviceColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 9),
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(e.value,
                        style: kStyleBodyMedium.copyWith(
                            color: kColorInk, height: 1.4)),
                  ),
                ],
              ),
            )),
        if (tip != null) ...[
          const SizedBox(height: kSpace2),
          Container(
            padding: const EdgeInsets.all(kSpace3),
            decoration: BoxDecoration(
              color: kColorPrimarySoft,
              borderRadius: kRadiusSm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    size: 14, color: kColorPrimary),
                const SizedBox(width: kSpace2),
                Expanded(
                  child: Text(tip!,
                      style: kStyleCaption.copyWith(
                          color: kColorPrimaryDark, height: 1.4)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Album card ───────────────────────────────────────────────────────────────

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({
    required this.album,
    required this.isOwn,
    this.memberName,
    this.memberInitials,
    this.onDelete,
  });

  final TripPhotoAlbum album;
  final bool           isOwn;
  final String?        memberName;
  final String?        memberInitials;
  final VoidCallback?  onDelete;

  Future<void> _open(BuildContext context) async {
    final uri = Uri.tryParse(album.url);
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
          // Service icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: album.service.softColor,
              borderRadius: kRadiusMd,
            ),
            child: Icon(album.service.icon,
                size: 22, color: album.service.color),
          ),
          const SizedBox(width: kSpace3),

          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(album.title,
                    style: kStyleBodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      album.service.label,
                      style: kStyleCaption.copyWith(color: album.service.color),
                    ),
                    Text(' · ', style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    Flexible(
                      child: Text(
                        album.domain,
                        style: kStyleCaption.copyWith(color: kColorInkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (album.note != null) ...[
                  const SizedBox(height: kSpace2),
                  Text(album.note!,
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: kSpace2),
                // Added by
                Row(
                  children: [
                    CircleAvatar(
                      radius: 9,
                      backgroundColor: kColorPrimarySoft,
                      child: Text(
                        memberInitials ?? '?',
                        style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: kColorPrimaryDark),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isOwn
                          ? 'You${memberName != null ? ' (${memberName!})' : ''}'
                          : memberName ?? 'Member',
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpace2),

          // Actions
          Column(
            children: [
              const Icon(Icons.open_in_new_rounded,
                  size: 16, color: kColorInkSoft),
              if (onDelete != null) ...[
                const SizedBox(height: kSpace3),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline_rounded,
                      size: 16, color: kColorDanger),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
