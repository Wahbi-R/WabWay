import 'dart:async';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../core/image_cache_manager.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/location/location_sharing_manager.dart';
import '../core/supabase/crew_service.dart';
import '../core/trip/app_trip_member.dart';
import '../core/notifications/push_notifier.dart';
import 'notification_settings_screen.dart';
import '../data/crew_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/wabway_avatar.dart';

class CrewScreen extends ConsumerStatefulWidget {
  const CrewScreen({super.key});

  @override
  ConsumerState<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends ConsumerState<CrewScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  List<TripMessage> _messages = [];
  List<LocationShare> _locations = [];
  bool _loadingMessages = true;
  bool _sendingPing = false;
  bool _sendingFindMe = false;
  bool _sending = false;
  bool _sendingImage = false;

  RealtimeChannel? _messageChannel;
  RealtimeChannel? _locationChannel;

  final _scrollController = ScrollController();
  final _textController = TextEditingController();

  String? _tripId;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    LocationSharingManager.instance.isSharing.addListener(_onSharingChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _tripId = ref.read(activeTripIdProvider);
      _userId = ref.read(profileProvider)?.id;
      _load(_tripId!);
    });
  }

  void _onSharingChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    LocationSharingManager.instance.isSharing.removeListener(_onSharingChanged);
    _messageChannel?.unsubscribe();
    _locationChannel?.unsubscribe();
    _tabs.dispose();
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _load(String tripId) async {
    setState(() => _loadingMessages = true);
    try {
      final results = await Future.wait([
        CrewService.fetchMessages(tripId),
        CrewService.fetchActiveLocations(tripId),
      ]);
      if (!mounted) return;
      setState(() {
        _messages = results[0] as List<TripMessage>;
        _locations = results[1] as List<LocationShare>;
        _loadingMessages = false;
      });
      _scrollToBottom();
      _subscribe(tripId);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMessages = false);
    }
  }

  void _subscribe(String tripId) {
    _messageChannel?.unsubscribe();
    _locationChannel?.unsubscribe();
    _messageChannel = CrewService.subscribeMessages(tripId, _onNewMessage);
    _locationChannel = CrewService.subscribeLocations(tripId, _onLocationsChanged);
  }

  Future<void> _onNewMessage() async {
    if (_tripId == null) return;
    final messages = await CrewService.fetchMessages(_tripId!);
    if (!mounted) return;
    setState(() => _messages = messages);
    _scrollToBottom();
  }

  Future<void> _onLocationsChanged() async {
    if (_tripId == null) return;
    final locations = await CrewService.fetchActiveLocations(_tripId!);
    if (!mounted) return;
    setState(() => _locations = locations);
  }

  Future<void> _onReact(String messageId, String emoji) async {
    final userId = _userId;
    if (userId == null) return;
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = _messages[idx];
    final myReacted = (msg.reactions[emoji] ?? []).contains(userId);
    if (myReacted) {
      await CrewService.removeReaction(messageId: messageId, userId: userId, emoji: emoji);
    } else {
      await CrewService.addReaction(messageId: messageId, userId: userId, emoji: emoji);
    }
    // Reactions refresh via the realtime subscription; no extra setState needed.
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: kDurationBase,
          curve: kEaseOut,
        );
      }
    });
  }

  String get _myDisplayName {
    try {
      return ref.read(tripMembersProvider)
          .firstWhere((m) => m.userId == _userId)
          .profile
          .displayName;
    } catch (_) {
      return 'Someone';
    }
  }

  Future<void> _toggleLocationSharing() async {
    final mgr = LocationSharingManager.instance;
    if (mgr.isSharing.value) {
      await mgr.stop();
      return;
    }

    final granted = await _ensureLocationPermission();
    if (!granted || !mounted) return;

    pushNotify(
      tripId: _tripId!,
      title: '\u{1F4CD} $_myDisplayName started sharing location',
      body: 'Check the Live Map in crew',
      excludeUserId: _userId,
      data: {'screen': 'crew', 'trip_id': _tripId!},
    );

    await mgr.start(
      tripId: _tripId!,
      userId: _userId!,
      settings: _buildLocationSettings(),
      onError: (e) {
        if (!mounted) return;
        if (e is LocationServiceDisabledException) {
          _showError('Location services are off — enable them in Settings');
          Geolocator.openLocationSettings();
        } else {
          _showError('Location sharing stopped unexpectedly');
        }
      },
    );
  }

  LocationSettings _buildLocationSettings() {
    if (kIsWeb) {
      return const LocationSettings(accuracy: LocationAccuracy.high);
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        intervalDuration: const Duration(seconds: 10),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'WabWay location sharing',
          notificationText: 'Sharing your location with your crew',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.other,
        pauseLocationUpdatesAutomatically: false,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  Future<bool> _ensureLocationPermission() async {
    try {
      if (kIsWeb) {
        await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.medium),
        );
        return true;
      }
      // Check that the device's location service is turned on.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          _showError('Location services are off — enable them in Settings');
          await Geolocator.openLocationSettings();
        }
        return false;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) await Geolocator.openAppSettings();
        return false;
      }
      return perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
    } catch (_) {
      if (mounted) _showError('Could not access location');
      return false;
    }
  }

  /// Gets current position with layered fallbacks (fastest first):
  /// 1. Cached position from active location-sharing stream (instant)
  /// 2. Last-known position from OS (instant, usually fresh)
  /// 3. One-shot medium-accuracy request (15s timeout — network/WiFi)
  Future<Position> _getCurrentPosition() async {
    // If the sharing stream is running, its most recent fix is right there.
    final cached = LocationSharingManager.instance.lastPosition;
    if (cached != null) return cached;

    // OS-cached position — instant, no radio needed.
    final last = await Geolocator.getLastKnownPosition();
    if (last != null) return last;

    // Nothing cached — request a fresh fix (medium accuracy works without GPS).
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _sending) return;
    _textController.clear();
    setState(() => _sending = true);
    try {
      await CrewService.sendMessage(
        tripId: _tripId!,
        authorId: _userId!,
        body: text,
      );
      // Refresh immediately so the sender sees their message without waiting
      // for the realtime subscription (which requires the table to be in the
      // Supabase realtime publication).
      await _onNewMessage();
      pushNotify(
        tripId: _tripId!,
        title: 'New crew message',
        body: text.length > 80 ? '${text.substring(0, 80)}…' : text,
        excludeUserId: _userId,
        data: {'screen': 'crew', 'trip_id': _tripId!},
        prefKey: kPrefNotifCrew,
      );
    } catch (_) {
      _showError('Failed to send');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendLocationPing() async {
    if (_sendingPing) return;
    final granted = await _ensureLocationPermission();
    if (!granted || !mounted) return;

    setState(() => _sendingPing = true);
    try {
      final pos = await _getCurrentPosition();
      await CrewService.sendLocationPing(
        tripId: _tripId!,
        authorId: _userId!,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      await _onNewMessage();
    } catch (_) {
      _showError('Could not get location');
    } finally {
      if (mounted) setState(() => _sendingPing = false);
    }
  }

  Future<void> _sendFindMe() async {
    if (_sendingFindMe) return;

    // Confirm before alerting the whole crew.
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        title: const Text('Alert your crew?'),
        content: const Text(
          'Everyone in the trip will get a high-priority notification and can navigate to your location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kColorDanger),
            child: const Text('Send SOS'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final granted = await _ensureLocationPermission();
    if (!granted || !mounted) return;

    setState(() => _sendingFindMe = true);
    try {
      final pos = await _getCurrentPosition();
      await CrewService.sendFindMe(
        tripId: _tripId!,
        authorId: _userId!,
        lat: pos.latitude,
        lng: pos.longitude,
      );
      await _onNewMessage();
      pushNotify(
        tripId: _tripId!,
        title: '\u{1F6A8} $_myDisplayName needs the crew!',
        body: 'Tap to navigate to them',
        excludeUserId: _userId,
        data: {'screen': 'crew', 'trip_id': _tripId!},
        highPriority: true,
      );
      // Auto-start live location sharing so the crew's map pin stays current.
      final mgr = LocationSharingManager.instance;
      if (!mgr.isSharing.value && mounted) {
        await mgr.start(
          tripId: _tripId!,
          userId: _userId!,
          settings: _buildLocationSettings(),
          onError: (_) {},
        );
      }
    } catch (_) {
      _showError('Could not send SOS — check your connection');
    } finally {
      if (mounted) setState(() => _sendingFindMe = false);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace4),
          child: Container(
            decoration: const BoxDecoration(
              color: kColorPaper,
              borderRadius: kRadiusXl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: Text('Camera', style: kStyleBodyMedium),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.camera);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text('Photo library', style: kStyleBodyMedium),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickAndSendImage(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1280,
      maxHeight: 1280,
    );
    if (file == null || !mounted) return;
    setState(() => _sendingImage = true);
    try {
      final imageUrl = await CrewService.uploadChatImage(_tripId!, file);
      await CrewService.sendImageMessage(
        tripId: _tripId!,
        authorId: _userId!,
        imageUrl: imageUrl,
      );
      await _onNewMessage();
    } catch (_) {
      _showError('Failed to send image');
    } finally {
      if (mounted) setState(() => _sendingImage = false);
    }
  }

  Future<void> _onSetMeetupPoint(LatLng point) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        title: const Text('Set meetup point?'),
        content: const Text(
          "Share this location with your crew as a meeting spot. They'll get a notification and can navigate here.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: kColorSecondary),
            child: const Text('Share'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    try {
      await CrewService.sendMeetupPoint(
        tripId: _tripId!,
        authorId: _userId!,
        lat: point.latitude,
        lng: point.longitude,
      );
      await _onNewMessage();
      pushNotify(
        tripId: _tripId!,
        title: '\u{1F4CD} $_myDisplayName set a meetup point',
        body: 'Open crew chat to navigate there',
        excludeUserId: _userId,
        data: {'screen': 'crew', 'trip_id': _tripId!},
      );
    } catch (_) {
      _showError('Could not set meetup point');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message,
          style: kStyleBody.copyWith(color: Colors.white)),
      backgroundColor: kColorDanger,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _tripId) {
        _tripId = next;
        _userId = ref.read(profileProvider)?.id;
        _load(next);
      }
    });
    final members = ref.watch(tripMembersProvider);

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Crew', style: kStyleTitle),
        backgroundColor: kColorPaper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: kSpace4),
            child: _LocationToggle(
              sharing: LocationSharingManager.instance.isSharing.value,
              onTap: _toggleLocationSharing,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Chat'),
            Tab(text: 'Live Map'),
          ],
          labelColor: kColorPrimary,
          unselectedLabelColor: kColorInkSoft,
          indicatorColor: kColorPrimary,
          dividerColor: kColorBorder,
          labelStyle: kStyleBodySemibold,
          unselectedLabelStyle: kStyleBody,
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ChatTab(
            messages: _messages,
            loading: _loadingMessages,
            members: members,
            currentUserId: _userId ?? '',
            scrollController: _scrollController,
            textController: _textController,
            sending: _sending,
            sendingPing: _sendingPing,
            sendingFindMe: _sendingFindMe,
            sendingImage: _sendingImage,
            onSend: _sendMessage,
            onLinkUp: _sendLocationPing,
            onFindMe: _sendFindMe,
            onSendImage: _showImageSourceSheet,
            onReact: _onReact,
          ),
          _MapTab(
            locations: _locations,
            members: members,
            messages: _messages,
            currentUserId: _userId ?? '',
            onSetMeetupPoint: _onSetMeetupPoint,
          ),
        ],
      ),
    );
  }
}

// ─── Location toggle chip ─────────────────────────────────────────────────────

class _LocationToggle extends StatelessWidget {
  const _LocationToggle({required this.sharing, required this.onTap});
  final bool sharing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: kDurationBase,
        padding:
            const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace1 + 2),
        decoration: BoxDecoration(
          color: sharing ? kColorPrimary : kColorSurfaceSunken,
          borderRadius: kRadiusPill,
          border: Border.all(
            color: sharing ? kColorPrimaryDark : kColorBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              sharing ? Icons.location_on_rounded : Icons.location_off_rounded,
              size: 13,
              color: sharing ? Colors.white : kColorInkSoft,
            ),
            const SizedBox(width: 4),
            Text(
              sharing ? 'Sharing' : 'Share location',
              style: kStyleCaption.copyWith(
                color: sharing ? Colors.white : kColorInkSoft,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Chat tab ─────────────────────────────────────────────────────────────────

class _ChatTab extends StatelessWidget {
  const _ChatTab({
    required this.messages,
    required this.loading,
    required this.members,
    required this.currentUserId,
    required this.scrollController,
    required this.textController,
    required this.sending,
    required this.sendingPing,
    required this.sendingFindMe,
    required this.sendingImage,
    required this.onSend,
    required this.onLinkUp,
    required this.onFindMe,
    required this.onSendImage,
    required this.onReact,
  });

  final List<TripMessage> messages;
  final bool loading;
  final List<AppTripMember> members;
  final String currentUserId;
  final ScrollController scrollController;
  final TextEditingController textController;
  final bool sending;
  final bool sendingPing;
  final bool sendingFindMe;
  final bool sendingImage;
  final VoidCallback onSend;
  final VoidCallback onLinkUp;
  final VoidCallback onFindMe;
  final VoidCallback onSendImage;
  final Future<void> Function(String messageId, String emoji) onReact;

  AppTripMember? _memberById(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (loading) {
      body = const Center(
          child: CircularProgressIndicator(
              color: kColorPrimary, strokeWidth: 2));
    } else if (messages.isEmpty) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(kSpace8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline_rounded,
                  size: 48,
                  color: kColorInkSoft.withValues(alpha: 0.35)),
              const SizedBox(height: kSpace3),
              Text('No messages yet',
                  style:
                      kStyleBodyMedium.copyWith(color: kColorInkSoft)),
              const SizedBox(height: kSpace1),
              Text(
                'Say hi or tap 📍 to share your location',
                style: kStyleCaption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    } else {
      body = ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(vertical: kSpace3),
        itemCount: messages.length,
        itemBuilder: (ctx, i) {
          final msg = messages[i];
          final isMe = msg.authorId == currentUserId;
          final member = _memberById(msg.authorId);
          final showSender =
              i == 0 || messages[i - 1].authorId != msg.authorId;

          if (msg.type == MessageType.locationPing) {
            return _LocationPingCard(
                message: msg, member: member, isMe: isMe);
          }
          if (msg.type == MessageType.findMe) {
            return _FindMeCard(
                message: msg, member: member, isMe: isMe);
          }
          if (msg.type == MessageType.meetupPoint) {
            return _MeetupPointCard(
                message: msg, member: member, isMe: isMe);
          }
          return _MessageBubble(
            message: msg,
            member: member,
            isMe: isMe,
            showSender: showSender && !isMe,
            currentUserId: currentUserId,
            onReact: (emoji) => onReact(msg.id, emoji),
          );
        },
      );
    }

    return Column(
      children: [
        Expanded(child: body),
        _InputBar(
          textController: textController,
          sending: sending,
          sendingPing: sendingPing,
          sendingFindMe: sendingFindMe,
          sendingImage: sendingImage,
          onSend: onSend,
          onLinkUp: onLinkUp,
          onFindMe: onFindMe,
          onSendImage: onSendImage,
        ),
      ],
    );
  }
}

// ─── Message bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.member,
    required this.isMe,
    required this.showSender,
    required this.currentUserId,
    required this.onReact,
  });

  final TripMessage message;
  final AppTripMember? member;
  final bool isMe;
  final bool showSender;
  final String currentUserId;
  final ValueChanged<String> onReact;

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmojiPickerSheet(
        reactions: message.reactions,
        currentUserId: currentUserId,
        onReact: onReact,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMe ? kColorPrimary : kColorPaper;
    final textColor = isMe ? Colors.white : kColorInk;
    final hasReactions = message.reactions.isNotEmpty;

    final avatar = WabwayAvatar(
      name: member?.profile.displayName ?? '?',
      size: WabwayAvatarSize.xs,
    );

    return Padding(
      padding: EdgeInsets.only(
        left: kSpace3,
        right: kSpace3,
        top: showSender ? kSpace3 : kSpace1,
        bottom: kSpace1,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            avatar,
            const SizedBox(width: kSpace2),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (showSender && member != null && !isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: kSpace1, bottom: kSpace1),
                    child: Text(
                      member!.profile.displayName,
                      style: kStyleCaption.copyWith(
                          fontWeight: FontWeight.w600, color: kColorInkSoft),
                    ),
                  ),
                GestureDetector(
                  onLongPress: () => _showEmojiPicker(context),
                  child: message.type == MessageType.image && message.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: Radius.circular(isMe ? 16 : 4),
                            bottomRight: Radius.circular(isMe ? 4 : 16),
                          ),
                          child: CachedNetworkImage(
                            imageUrl: message.imageUrl!,
                            cacheManager: WabwayImageCache.instance,
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              width: 220,
                              height: 220,
                              color: kColorSurfaceSunken,
                              child: const Center(
                                child: CircularProgressIndicator(
                                    color: kColorPrimary, strokeWidth: 2),
                              ),
                            ),
                            errorBuilder: (_, __, ___) => Container(
                              width: 220,
                              height: 220,
                              color: kColorSurfaceSunken,
                              child: const Icon(Icons.broken_image_rounded,
                                  color: kColorInkSoft),
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: kSpace3, vertical: kSpace2 + 2),
                          decoration: BoxDecoration(
                            color: bubbleColor,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 16),
                            ),
                            border: isMe ? null : Border.all(color: kColorBorder),
                            boxShadow: kShadowXs,
                          ),
                          child: Text(
                            message.body,
                            style: kStyleBody.copyWith(color: textColor),
                          ),
                        ),
                ),
                if (hasReactions) ...[
                  const SizedBox(height: 4),
                  _ReactionRow(
                    reactions: message.reactions,
                    currentUserId: currentUserId,
                    onReact: onReact,
                  ),
                ],
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: kSpace2),
            avatar,
          ],
        ],
      ),
    );
  }
}

// ─── Reaction row ─────────────────────────────────────────────────────────────

class _ReactionRow extends StatelessWidget {
  const _ReactionRow({
    required this.reactions,
    required this.currentUserId,
    required this.onReact,
  });

  final Map<String, List<String>> reactions;
  final String currentUserId;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: reactions.entries.map((e) {
        final emoji = e.key;
        final users = e.value;
        final iMine = users.contains(currentUserId);
        return GestureDetector(
          onTap: () => onReact(emoji),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: iMine ? kColorPrimarySoft : kColorSurfaceSunken,
              borderRadius: kRadiusPill,
              border: Border.all(
                color: iMine ? kColorPrimaryDark : kColorBorder,
                width: 1,
              ),
            ),
            child: Text(
              '$emoji ${users.length}',
              style: const TextStyle(fontSize: 12, height: 1.2),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Emoji picker sheet ───────────────────────────────────────────────────────

const _kReactionEmojis = ['❤️', '👍', '😂', '😮', '😢', '🔥'];

class _EmojiPickerSheet extends StatelessWidget {
  const _EmojiPickerSheet({
    required this.reactions,
    required this.currentUserId,
    required this.onReact,
  });

  final Map<String, List<String>> reactions;
  final String currentUserId;
  final ValueChanged<String> onReact;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace4),
        child: Container(
          decoration: const BoxDecoration(
            color: kColorPaper,
            borderRadius: kRadiusXl,
            boxShadow: kShadowMd,
          ),
          padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _kReactionEmojis.map((emoji) {
              final iMine = (reactions[emoji] ?? []).contains(currentUserId);
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  onReact(emoji);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iMine ? kColorPrimarySoft : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ─── Location ping card ───────────────────────────────────────────────────────

class _LocationPingCard extends StatelessWidget {
  const _LocationPingCard({
    required this.message,
    required this.member,
    required this.isMe,
  });

  final TripMessage message;
  final AppTripMember? member;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = isMe ? 'You' : (member?.profile.displayName ?? 'Someone');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace6, vertical: kSpace3),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: kColorPaper,
            borderRadius: kRadiusLg,
            border: Border.all(color: kColorPrimarySoftBorder),
            boxShadow: kShadowSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(kSpace3),
                decoration: const BoxDecoration(
                  color: kColorPrimarySoft,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: kColorPrimary, size: 18),
                    const SizedBox(width: kSpace2),
                    Expanded(
                      child: Text(
                        '$name linked up',
                        style: kStyleBodySemibold
                            .copyWith(color: kColorPrimaryDark),
                      ),
                    ),
                  ],
                ),
              ),
              if (message.lat != null && message.lng != null)
                Padding(
                  padding: const EdgeInsets.all(kSpace3),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(
                          'https://maps.google.com/?q=${message.lat},${message.lng}',
                        );
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: const Text('Navigate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kColorPrimary,
                        side: const BorderSide(color: kColorPrimarySoftBorder),
                        shape: const RoundedRectangleBorder(
                            borderRadius: kRadiusSm),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Find Me card ────────────────────────────────────────────────────────────

class _FindMeCard extends StatelessWidget {
  const _FindMeCard({
    required this.message,
    required this.member,
    required this.isMe,
  });

  final TripMessage message;
  final AppTripMember? member;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = isMe ? 'You' : (member?.profile.displayName ?? 'Someone');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace6, vertical: kSpace3),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: kColorPaper,
            borderRadius: kRadiusLg,
            border: Border.all(color: kColorDangerBorder),
            boxShadow: kShadowSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(kSpace3),
                decoration: const BoxDecoration(
                  color: kColorDangerSoft,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sos_rounded,
                        color: kColorDanger, size: 18),
                    const SizedBox(width: kSpace2),
                    Expanded(
                      child: Text(
                        '$name needs the crew!',
                        style: kStyleBodySemibold.copyWith(color: kColorDanger),
                      ),
                    ),
                  ],
                ),
              ),
              if (message.lat != null && message.lng != null)
                Padding(
                  padding: const EdgeInsets.all(kSpace3),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final geoUri = Uri.parse(
                          'geo:${message.lat},${message.lng}?q=${message.lat},${message.lng}($name)',
                        );
                        if (await canLaunchUrl(geoUri)) {
                          await launchUrl(geoUri,
                              mode: LaunchMode.externalApplication);
                        } else {
                          final mapsUri = Uri.parse(
                            'https://maps.google.com/?q=${message.lat},${message.lng}',
                          );
                          await launchUrl(mapsUri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: Text('Go to $name'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kColorDanger,
                        side: const BorderSide(color: kColorDangerBorder),
                        shape: const RoundedRectangleBorder(
                            borderRadius: kRadiusSm),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Meetup point card ───────────────────────────────────────────────────────

class _MeetupPointCard extends StatelessWidget {
  const _MeetupPointCard({
    required this.message,
    required this.member,
    required this.isMe,
  });

  final TripMessage message;
  final AppTripMember? member;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final name = isMe ? 'You' : (member?.profile.displayName ?? 'Someone');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace6, vertical: kSpace3),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: kColorPaper,
            borderRadius: kRadiusLg,
            border: Border.all(color: kColorSecondarySoftBorder),
            boxShadow: kShadowSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(kSpace3),
                decoration: const BoxDecoration(
                  color: kColorSecondarySoft,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: kColorSecondary, size: 18),
                    const SizedBox(width: kSpace2),
                    Expanded(
                      child: Text(
                        '$name set a meetup point',
                        style:
                            kStyleBodySemibold.copyWith(color: kColorSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              if (message.lat != null && message.lng != null)
                Padding(
                  padding: const EdgeInsets.all(kSpace3),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final geoUri = Uri.parse(
                          'geo:${message.lat},${message.lng}?q=${message.lat},${message.lng}(Meetup)',
                        );
                        if (await canLaunchUrl(geoUri)) {
                          await launchUrl(geoUri,
                              mode: LaunchMode.externalApplication);
                        } else {
                          final mapsUri = Uri.parse(
                            'https://maps.google.com/?q=${message.lat},${message.lng}',
                          );
                          await launchUrl(mapsUri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: const Text('Navigate to meetup'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kColorSecondary,
                        side: const BorderSide(color: kColorSecondarySoftBorder),
                        shape: const RoundedRectangleBorder(
                            borderRadius: kRadiusSm),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.textController,
    required this.sending,
    required this.sendingPing,
    required this.sendingFindMe,
    required this.sendingImage,
    required this.onSend,
    required this.onLinkUp,
    required this.onFindMe,
    required this.onSendImage,
  });

  final TextEditingController textController;
  final bool sending;
  final bool sendingPing;
  final bool sendingFindMe;
  final bool sendingImage;
  final VoidCallback onSend;
  final VoidCallback onLinkUp;
  final VoidCallback onFindMe;
  final VoidCallback onSendImage;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        border: Border(top: BorderSide(color: kColorBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace3, kSpace2, kSpace3, kSpace2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // SOS button — prominent, full width
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: sendingFindMe ? null : onFindMe,
                  icon: sendingFindMe
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.crisis_alert_rounded, size: 20),
                  label: Text(
                    sendingFindMe ? 'Alerting crew…' : 'Find Me',
                    style: kStyleBodySemibold.copyWith(color: Colors.white),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: sendingFindMe ? kColorBorder : kColorDanger,
                    foregroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(height: kSpace2),
              // Message row
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _CircleIconButton(
                    tooltip: 'Link Up — share your location in chat',
                    icon: Icons.location_on_rounded,
                    color: kColorPrimarySoft,
                    iconColor: kColorPrimary,
                    loading: sendingPing,
                    onTap: onLinkUp,
                  ),
                  const SizedBox(width: kSpace2),
                  if (!kIsWeb)
                    _CircleIconButton(
                      tooltip: 'Send a photo',
                      icon: Icons.image_rounded,
                      color: kColorSurfaceSunken,
                      iconColor: kColorInkSoft,
                      loading: sendingImage,
                      onTap: onSendImage,
                    ),
                  if (!kIsWeb) const SizedBox(width: kSpace2),
                  Expanded(
                    child: TextField(
                      controller: textController,
                      style: kStyleBody,
                      minLines: 1,
                      maxLines: 5,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: 'Message the crew…',
                        hintStyle: kStyleBody.copyWith(
                            color: kColorInkSoft.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: kColorSurfaceSunken,
                        border: const OutlineInputBorder(
                          borderRadius: kRadiusPill,
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: const OutlineInputBorder(
                          borderRadius: kRadiusPill,
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: const OutlineInputBorder(
                          borderRadius: kRadiusPill,
                          borderSide:
                              BorderSide(color: kColorPrimary, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: kSpace4, vertical: kSpace2 + 2),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: kSpace2),
                  _CircleIconButton(
                    tooltip: 'Send',
                    icon: Icons.send_rounded,
                    color: kColorPrimary,
                    iconColor: Colors.white,
                    loading: sending,
                    onTap: onSend,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.loading,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final Color iconColor;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: loading ? kColorBorder : color,
            shape: BoxShape.circle,
          ),
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(10),
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(iconColor)),
                )
              : Icon(icon, size: 18, color: iconColor),
        ),
      ),
    );
  }
}

// ─── Live map tab ─────────────────────────────────────────────────────────────

class _MapTab extends StatelessWidget {
  const _MapTab({
    required this.locations,
    required this.members,
    required this.messages,
    required this.currentUserId,
    required this.onSetMeetupPoint,
  });

  final List<LocationShare> locations;
  final List<AppTripMember> members;
  final List<TripMessage> messages;
  final String currentUserId;
  final void Function(LatLng) onSetMeetupPoint;

  AppTripMember? _memberById(String userId) {
    try {
      return members.firstWhere((m) => m.userId == userId);
    } catch (_) {
      return null;
    }
  }

  LocationShare? _myLocation() {
    try {
      return locations.firstWhere((l) => l.userId == currentUserId);
    } catch (_) {
      return null;
    }
  }

  /// Users who sent a findMe in the last 2 hours.
  Set<String> _findMeUserIds() => messages
      .where((m) =>
          m.type == MessageType.findMe &&
          DateTime.now().difference(m.createdAt).inHours < 2)
      .map((m) => m.authorId)
      .toSet();

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _showMemberSheet(
    BuildContext context,
    LocationShare loc,
    AppTripMember? member,
    String? distanceLabel,
  ) {
    final name = member?.profile.displayName ?? 'Crew member';
    showModalBottomSheet(
      context: context,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: kStyleTitle),
              const SizedBox(height: kSpace1),
              Row(
                children: [
                  Text(
                    'Last updated ${_formatRelative(loc.lastUpdatedAt)}',
                    style: kStyleCaption.copyWith(color: kColorInkSoft),
                  ),
                  if (distanceLabel != null) ...[
                    Text('  ·  ', style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    const Icon(Icons.straighten_rounded, size: 12, color: kColorInkSoft),
                    const SizedBox(width: 3),
                    Text(distanceLabel,
                        style: kStyleCaption.copyWith(color: kColorInkSoft)),
                  ],
                ],
              ),
              const SizedBox(height: kSpace4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.navigation_rounded, size: 18),
                  label: Text('Navigate to $name'),
                  onPressed: () async {
                    Navigator.pop(context);
                    final geoUri = Uri.parse(
                      'geo:${loc.lat},${loc.lng}?q=${loc.lat},${loc.lng}($name)',
                    );
                    if (await canLaunchUrl(geoUri)) {
                      await launchUrl(geoUri,
                          mode: LaunchMode.externalApplication);
                    } else {
                      final mapsUri = Uri.parse(
                        'https://maps.google.com/?q=${loc.lat},${loc.lng}',
                      );
                      await launchUrl(mapsUri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kColorPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
                    padding: const EdgeInsets.symmetric(vertical: kSpace3),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 30) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    if (locations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(kSpace8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_searching_rounded,
                  size: 48,
                  color: kColorInkSoft.withValues(alpha: 0.35)),
              const SizedBox(height: kSpace3),
              Text('Nobody is sharing yet',
                  style:
                      kStyleBodyMedium.copyWith(color: kColorInkSoft)),
              const SizedBox(height: kSpace1),
              Text(
                'Tap "Share location" to appear on the map',
                style: kStyleCaption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final avgLat =
        locations.map((l) => l.lat).reduce((a, b) => a + b) / locations.length;
    final avgLng =
        locations.map((l) => l.lng).reduce((a, b) => a + b) / locations.length;

    final findMeIds = _findMeUserIds();
    final myLoc = _myLocation();

    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: LatLng(avgLat, avgLng),
            initialZoom: 15,
            onLongPress: (_, point) => onSetMeetupPoint(point),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'ca.wabble.wabway',
            ),
            const SimpleAttributionWidget(
              source: Text('Tiles © Esri'),
            ),
            MarkerLayer(
              markers: locations.map((loc) {
                final member = _memberById(loc.userId);
                final isMe = loc.userId == currentUserId;
                final isFindMe = findMeIds.contains(loc.userId);

                // Distance from me to this member (null if my location unknown or this is me)
                final String? distanceLabel = (!isMe && myLoc != null)
                    ? _formatDistance(Geolocator.distanceBetween(
                        myLoc.lat, myLoc.lng, loc.lat, loc.lng))
                    : null;

                final Color markerColor = isFindMe
                    ? kColorDanger
                    : (isMe ? kColorPrimary : kColorSecondary);

                final Widget markerContent = isFindMe
                    ? const Icon(Icons.crisis_alert_rounded,
                        size: 18, color: Colors.white)
                    : Text(
                        member?.profile.initials ?? '?',
                        style: kStyleBodySemibold.copyWith(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                      );

                return Marker(
                  point: LatLng(loc.lat, loc.lng),
                  width: 64,
                  height: distanceLabel != null ? 62 : 44,
                  alignment: Alignment.topCenter,
                  child: GestureDetector(
                    onTap: isMe
                        ? null
                        : () => _showMemberSheet(context, loc, member, distanceLabel),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: markerColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isFindMe
                                  ? const Color(0xFFFFD0D0)
                                  : Colors.white,
                              width: isFindMe ? 3 : 2.5,
                            ),
                            boxShadow: kShadowMd,
                          ),
                          child: Center(child: markerContent),
                        ),
                        if (distanceLabel != null) ...[
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: kColorPaper,
                              borderRadius: kRadiusPill,
                              border: Border.all(color: kColorBorder),
                              boxShadow: kShadowXs,
                            ),
                            child: Text(
                              distanceLabel,
                              style: kStyleCaption.copyWith(
                                fontSize: 10,
                                color: kColorInk,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        // Hint pill
        Positioned(
          top: 10,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: kSpace3, vertical: kSpace1 + 1),
              decoration: BoxDecoration(
                color: kColorPaper.withValues(alpha: 0.88),
                borderRadius: kRadiusPill,
                boxShadow: kShadowXs,
              ),
              child: Text(
                'Long-press to set a meetup point',
                style: kStyleCaption.copyWith(color: kColorInkSoft),
              ),
            ),
          ),
        ),
        // Meet in the middle button (only when 2+ crew are sharing)
        if (locations.length >= 2)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final mLat = locations
                          .map((l) => l.lat)
                          .reduce((a, b) => a + b) /
                      locations.length;
                  final mLng = locations
                          .map((l) => l.lng)
                          .reduce((a, b) => a + b) /
                      locations.length;
                  onSetMeetupPoint(LatLng(mLat, mLng));
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: kSpace4, vertical: kSpace2 + 2),
                  decoration: const BoxDecoration(
                    color: kColorSecondary,
                    borderRadius: kRadiusPill,
                    boxShadow: kShadowMd,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.group_rounded,
                          size: 16, color: Colors.white),
                      const SizedBox(width: kSpace2),
                      Text(
                        'Meet in the middle',
                        style: kStyleBodySemibold.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
