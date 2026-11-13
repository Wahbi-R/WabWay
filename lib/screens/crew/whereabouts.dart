import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/image_cache_manager.dart';
import '../../core/location/current_position.dart';
import '../../core/trip/app_trip_member.dart';
import '../../data/crew_data.dart';
import '../../data/spot_data.dart' show fmtCommentTime;
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/wabway_avatar.dart';
import '../../widgets/wabway_button.dart';
import '../../widgets/wabway_form_sheet.dart';
import '../../widgets/wabway_text_field.dart';

// "Where's everyone?" — check-ins that work without GPS. In a mall, a station
// or a big market everyone's pin sits on the same spot (and GPS can't tell
// floors apart), so people say where they are: the shop, the floor, what
// they're next to, and optionally a photo of what's around them.

/// How long a check-in counts as "where they are now".
const kCheckInFresh = Duration(hours: 3);

/// Each member's latest check-in within [kCheckInFresh] of [now], newest first.
List<TripMessage> latestCheckIns(Iterable<TripMessage> messages, DateTime now) {
  final byAuthor = <String, TripMessage>{};
  for (final m in messages) {
    if (m.type != MessageType.checkIn) continue;
    if (now.difference(m.createdAt.toLocal()) > kCheckInFresh) continue;
    final prev = byAuthor[m.authorId];
    if (prev == null || m.createdAt.isAfter(prev.createdAt)) byAuthor[m.authorId] = m;
  }
  return byAuthor.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
}

/// "Uniqlo · 3F · by the escalators" from the sheet's fields.
String composeCheckIn({required String place, String floor = '', String near = ''}) {
  final f = floor.trim();
  final n = near.trim();
  return [
    place.trim(),
    if (f.isNotEmpty) f,
    if (n.isNotEmpty) RegExp(r'^(by|near|next to|in front of|outside|inside|at|behind|opposite)\b', caseSensitive: false).hasMatch(n) ? n : 'near $n',
  ].join(' · ');
}

/// What the crew sees: the text, an optional photo and an optional map pin.
class CheckInDraft {
  const CheckInDraft({required this.body, this.photo, this.position});
  final String body;
  final XFile? photo;
  final Position? position;
}

/// The "Where are you?" sheet. Returns null when cancelled.
Future<CheckInDraft?> showCheckInSheet(BuildContext context) =>
    showWabwayAutoSheet<CheckInDraft>(
      context,
      builder: (ctx, handle) => const _CheckInSheet(),
    );

class _CheckInSheet extends StatefulWidget {
  const _CheckInSheet();

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  final _place = TextEditingController();
  final _floor = TextEditingController();
  final _near = TextEditingController();
  XFile? _photo;
  bool _addPin = false;
  bool _locating = false;
  String? _error;

  @override
  void dispose() {
    _place.dispose();
    _floor.dispose();
    _near.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    try {
      final f = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (f != null && mounted) setState(() => _photo = f);
    } catch (_) {
      if (mounted) setState(() => _error = "Couldn't open the camera");
    }
  }

  Future<void> _submit() async {
    if (_place.text.trim().isEmpty) {
      setState(() => _error = 'Say where you are — a shop, a gate, a landmark…');
      return;
    }
    Position? pos;
    if (_addPin) {
      setState(() => _locating = true);
      if (await ensureLocationPermission()) {
        try {
          pos = await currentPosition(maxAge: const Duration(minutes: 5));
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() => _locating = false);
    }
    Navigator.pop(
      context,
      CheckInDraft(
        body: composeCheckIn(place: _place.text, floor: _floor.text, near: _near.text),
        photo: _photo,
        position: pos,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            kSpace5, kSpace2, kSpace5, kSpace5 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Where are you?', style: kStyleHeadingSm),
            const SizedBox(height: 4),
            Text('Tell the crew where to find you — handy in malls and stations where the map pins all overlap.',
                style: kStyleCaption.copyWith(color: kColorInkSoft)),
            const SizedBox(height: kSpace4),
            WabwayTextField(
              label: 'Place',
              hint: 'Uniqlo, food court, Gate 3, ramen place…',
              controller: _place,
              autofocus: true,
              error: _error,
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: kSpace3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 96,
                  child: WabwayTextField(
                    label: 'Floor',
                    hint: '3F, B1',
                    controller: _floor,
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: WabwayTextField(
                    label: 'Next to',
                    hint: 'the escalators, Starbucks…',
                    controller: _near,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace3),
            if (!kIsWeb)
              _photo == null
                  ? WabwayButton(
                      label: 'Add a photo of what’s around you',
                      icon: Icons.photo_camera_outlined,
                      variant: WabwayButtonVariant.ghost,
                      onPressed: _takePhoto,
                    )
                  : Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: kColorSuccess, size: 18),
                        const SizedBox(width: kSpace2),
                        Expanded(child: Text('Photo added', style: kStyleBodyMedium)),
                        TextButton(onPressed: _takePhoto, child: const Text('Retake')),
                        TextButton(
                          onPressed: () => setState(() => _photo = null),
                          child: const Text('Remove'),
                        ),
                      ],
                    ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              activeTrackColor: kColorPrimary,
              title: Text('Add a map pin too', style: kStyleBodyMedium),
              subtitle: Text('Your GPS spot right now, for getting to the building',
                  style: kStyleCaption.copyWith(color: kColorInkSoft)),
              value: _addPin,
              onChanged: (v) => setState(() => _addPin = v),
            ),
            const SizedBox(height: kSpace3),
            WabwayButton(
              label: _locating ? 'Finding your pin…' : 'Tell the crew',
              icon: Icons.where_to_vote_rounded,
              loading: _locating,
              fullWidth: true,
              onPressed: _locating ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── "Who's where" strip on top of the chat ───────────────────────────────────

class WhereaboutsStrip extends StatelessWidget {
  const WhereaboutsStrip({
    super.key,
    required this.checkIns,
    required this.members,
    required this.currentUserId,
    required this.onCheckIn,
    required this.onOpen,
  });

  final List<TripMessage> checkIns;
  final List<AppTripMember> members;
  final String currentUserId;
  final VoidCallback onCheckIn;
  final ValueChanged<TripMessage> onOpen;

  @override
  Widget build(BuildContext context) {
    final mine = checkIns.where((m) => m.authorId == currentUserId).firstOrNull;
    final others = checkIns.where((m) => m.authorId != currentUserId).toList();
    return Container(
      color: kColorPaper,
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, 0, kSpace2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("WHO'S WHERE", style: kStyleOverline.copyWith(color: kColorInkSoft)),
          const SizedBox(height: kSpace2),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(right: kSpace4),
              children: [
                _StripTile(
                  name: _nameOf(currentUserId),
                  label: mine == null ? "I'm at…" : 'You',
                  body: mine?.body ?? 'Tell the crew',
                  time: mine?.createdAt,
                  highlight: mine == null,
                  onTap: onCheckIn,
                ),
                for (final m in others) ...[
                  const SizedBox(width: kSpace2),
                  _StripTile(
                    name: _nameOf(m.authorId),
                    label: _nameOf(m.authorId),
                    body: m.body,
                    time: m.createdAt,
                    hasPhoto: m.imageUrl != null,
                    onTap: () => onOpen(m),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nameOf(String userId) =>
      members.where((m) => m.userId == userId).firstOrNull?.profile.displayName ?? 'Someone';
}

class _StripTile extends StatelessWidget {
  const _StripTile({
    required this.name,
    required this.label,
    required this.body,
    required this.onTap,
    this.time,
    this.hasPhoto = false,
    this.highlight = false,
  });

  final String name;
  final String label;
  final String body;
  final DateTime? time;
  final bool hasPhoto;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlight ? kColorPrimarySoft : kColorSurfaceSunken,
      borderRadius: kRadiusMd,
      child: InkWell(
        borderRadius: kRadiusMd,
        onTap: onTap,
        child: Container(
          width: 200,
          padding: const EdgeInsets.symmetric(horizontal: kSpace2, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: kRadiusMd,
            border: Border.all(color: highlight ? kColorPrimarySoftBorder : kColorBorder),
          ),
          child: Row(
            children: [
              highlight
                  ? const CircleAvatar(
                      radius: 16,
                      backgroundColor: kColorPrimary,
                      child: Icon(Icons.add_location_alt_rounded, color: Colors.white, size: 18),
                    )
                  : WabwayAvatar(name: name, size: WabwayAvatarSize.sm),
              const SizedBox(width: kSpace2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(label,
                              style: kStyleCaptionMedium.copyWith(
                                  color: highlight ? kColorPrimaryDark : kColorInk),
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (time != null)
                          Text(' · ${fmtCommentTime(time!.toLocal())}',
                              style: kStyleCaption.copyWith(color: kColorInkSoft, fontSize: 11)),
                        if (hasPhoto) ...[
                          const SizedBox(width: 3),
                          const Icon(Icons.photo_camera_outlined, size: 12, color: kColorInkSoft),
                        ],
                      ],
                    ),
                    Text(body,
                        style: kStyleCaption.copyWith(color: kColorInk),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Chat cards ───────────────────────────────────────────────────────────────

class CheckInCard extends StatelessWidget {
  const CheckInCard({super.key, required this.message, required this.name});
  final TripMessage message;

  /// Display name, or 'You'.
  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace6, vertical: kSpace3),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: CheckInDetails(message: message, name: name),
        ),
      ),
    );
  }
}

/// The check-in itself — used by the chat card and when tapping someone in
/// the "Who's where" strip.
class CheckInDetails extends StatelessWidget {
  const CheckInDetails({super.key, required this.message, required this.name});
  final TripMessage message;
  final String name;

  @override
  Widget build(BuildContext context) {
    final photo = message.imageUrl;
    return Container(
      decoration: BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorSecondarySoftBorder),
        boxShadow: kShadowSm,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(kSpace3),
            color: kColorSecondarySoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.where_to_vote_rounded, color: kColorSecondary, size: 18),
                const SizedBox(width: kSpace2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name == 'You' ? "You're at" : '$name is at',
                          style: kStyleCaption.copyWith(color: kColorInkSoft)),
                      Text(message.body, style: kStyleBodySemibold),
                    ],
                  ),
                ),
                Text(fmtCommentTime(message.createdAt.toLocal()),
                    style: kStyleCaption.copyWith(color: kColorInkSoft, fontSize: 11)),
              ],
            ),
          ),
          if (photo != null)
            GestureDetector(
              onTap: () => _showPhoto(context, photo),
              child: CachedNetworkImage(
                imageUrl: photo,
                cacheManager: WabwayImageCache.instance,
                height: 180,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(height: 180, color: kColorSurfaceSunken),
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          if (message.lat != null && message.lng != null)
            Padding(
              padding: const EdgeInsets.all(kSpace3),
              child: WabwayButton(
                label: 'Navigate to the pin',
                icon: Icons.navigation_rounded,
                variant: WabwayButtonVariant.secondary,
                size: WabwayButtonSize.sm,
                fullWidth: true,
                onPressed: () => launchUrl(
                  Uri.parse('https://maps.google.com/?q=${message.lat},${message.lng}'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: InteractiveViewer(
          child: Center(
            child: CachedNetworkImage(imageUrl: url, cacheManager: WabwayImageCache.instance),
          ),
        ),
      ),
    );
  }
}

class WhereAskCard extends StatelessWidget {
  const WhereAskCard({
    super.key,
    required this.name,
    required this.isMe,
    required this.answered,
    required this.onCheckIn,
  });

  final String name;
  final bool isMe;

  /// The current user checked in after this ask.
  final bool answered;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace6, vertical: kSpace3),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 300),
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            color: kColorPaper,
            borderRadius: kRadiusLg,
            border: Border.all(color: kColorBorder),
            boxShadow: kShadowSm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.travel_explore_rounded, color: kColorPrimary, size: 18),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(isMe ? 'You asked where everyone is' : '$name asked where everyone is',
                        style: kStyleBodySemibold),
                  ),
                ],
              ),
              if (!isMe) ...[
                const SizedBox(height: kSpace2),
                answered
                    ? Row(children: [
                        const Icon(Icons.check_rounded, size: 16, color: kColorSuccess),
                        const SizedBox(width: 4),
                        Text('You checked in', style: kStyleCaption.copyWith(color: kColorSuccess)),
                      ])
                    : WabwayButton(
                        label: 'Say where I am',
                        icon: Icons.where_to_vote_rounded,
                        size: WabwayButtonSize.sm,
                        fullWidth: true,
                        onPressed: onCheckIn,
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
