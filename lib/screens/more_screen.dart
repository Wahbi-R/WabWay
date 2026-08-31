import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/auth_service.dart';
import '../core/supabase/trip_service.dart';
import 'account_sheets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
import 'accommodations/accommodations_screen.dart';
import 'crew_screen.dart';
import 'docs_screen.dart';
import 'map_screen.dart';
import 'travel_screen.dart';
import 'links_screen.dart';
import 'packing_screen.dart';
import 'shopping/shopping_screen.dart';
import 'photos_screen.dart';
import 'members/add_member_sheet.dart';
import 'members/invite_sheet.dart';
import 'share/incoming_share_screen.dart';
import 'trips/trip_settings_sheet.dart';
import 'trips/trip_switcher_sheet.dart';
import 'diagnostics_screen.dart';
import 'notification_settings_screen.dart';
import '../core/changelog.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(tripMembersProvider);
    final trip = ref.watch(activeTripProvider);
    final currentUserId = ref.watch(profileProvider)?.id;
    final isOwner = members.any((m) => m.userId == currentUserId && m.isOwner);
    final reload = () => ref.read(tripNotifierProvider.notifier).load();

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(title: Text('More', style: kStyleTitle)),
      body: ListView(
        padding: const EdgeInsets.all(kSpace4),
        children: [
          // Trip switcher
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace1,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: kColorPrimarySoft,
                    borderRadius: kRadiusMd,
                  ),
                  child: const Icon(Icons.swap_horiz_rounded,
                      size: 20, color: kColorPrimary),
                ),
                title: Text(trip?.name ?? '', style: kStyleBodyMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Tap to switch trip', style: kStyleCaption),
                ),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: kColorTextTertiary(), size: 18),
                onTap: () => showTripSwitcherSheet(context, ref),
              ),
            ),
          ),

          const SizedBox(height: kSpace4),

          // Crew / Chat — prominent card for quick access
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace1,
                ),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: kColorPrimarySoft,
                    borderRadius: kRadiusMd,
                  ),
                  child: const Icon(Icons.chat_rounded,
                      size: 20, color: kColorPrimary),
                ),
                title: Text('Crew Chat', style: kStyleBodyMedium),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Message your trip crew & share location',
                      style: kStyleCaption),
                ),
                trailing: Icon(Icons.chevron_right_rounded,
                    color: kColorTextTertiary(), size: 18),
                onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const CrewScreen())),
              ),
            ),
          ),

          const SizedBox(height: kSpace4),

          // Members section
          Text('Members', style: kStyleOverline),
          const SizedBox(height: kSpace3),
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: members.asMap().entries.map((e) {
                  final i = e.key;
                  final member = e.value;
                  final isLast = i == members.length - 1;
                  final isMe = member.userId == currentUserId;
                  final displayName = isMe
                      ? '${member.profile.displayName} (You)'
                      : member.profile.displayName;
                  final canRemove = isOwner && !isMe && !member.isOwner;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: kSpace4,
                          vertical: kSpace2,
                        ),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: kColorPrimarySoft,
                          child: Text(
                            member.profile.initials,
                            style: kStyleBodySemibold.copyWith(
                                color: kColorPrimaryDark),
                          ),
                        ),
                        title: Text(displayName, style: kStyleBodyMedium),
                        subtitle:
                            Text(member.profile.email, style: kStyleCaption),
                        trailing: member.isOwner
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: kSpace2,
                                  vertical: 2,
                                ),
                                decoration: const BoxDecoration(
                                  color: kColorAccentSoft,
                                  borderRadius: kRadiusPill,
                                ),
                                child: Text(
                                  'Organiser',
                                  style: kStyleOverline.copyWith(
                                      color: kColorAccent),
                                ),
                              )
                            : canRemove
                                ? IconButton(
                                    icon: const Icon(Icons.person_remove_outlined,
                                        size: 18, color: kColorDanger),
                                    tooltip: 'Remove member',
                                    onPressed: () => _confirmRemoveMember(
                                        context, trip?.id ?? '', member, reload),
                                  )
                                : null,
                      ),
                      if (!isLast)
                        const Divider(
                            height: 1, indent: kSpace4 + 36 + kSpace3),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: kSpace4),

          // Screens not in the mobile bottom nav
          const _SectionHeader(title: 'Explore'),
          const SizedBox(height: kSpace3),
          _ExploreGrid(items: [
            _ExploreItem(icon: Icons.map_rounded,           label: 'Map',       onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const MapScreen()))),
            _ExploreItem(icon: Icons.flight_rounded,        label: 'Travel',    onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const TravelScreen()))),
            _ExploreItem(icon: Icons.photo_library_rounded, label: 'Photos',    onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const PhotosScreen()))),
            _ExploreItem(icon: Icons.link_rounded,          label: 'Links',     onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const LinksScreen()))),
            _ExploreItem(icon: Icons.hotel_rounded,         label: 'Stays',     onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const AccommodationsScreen()))),
            _ExploreItem(icon: Icons.folder_rounded,        label: 'Docs',      onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const DocsScreen()))),
            _ExploreItem(icon: Icons.luggage_rounded,       label: 'Packing',   onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const PackingScreen()))),
            _ExploreItem(icon: Icons.shopping_cart_rounded, label: 'Shopping',  onTap: () => Navigator.push<void>(context, MaterialPageRoute(builder: (_) => const ShoppingScreen()))),
          ]),

          const SizedBox(height: kSpace4),

          // Invite section — any trip member (hidden until trip data is loaded)
          if (trip != null) ...[
            const _SectionHeader(title: 'Invite'),
            const SizedBox(height: kSpace3),
            DecoratedBox(
              decoration: kCardDecoration(),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    if (isOwner) ...[
                      ListTile(
                        contentPadding: const EdgeInsets.all(kSpace4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: kColorPrimarySoft,
                            borderRadius: kRadiusMd,
                          ),
                          child: const Icon(Icons.person_add_rounded,
                              size: 20, color: kColorPrimary),
                        ),
                        title: Text('Add a member', style: kStyleBodySemibold),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: kSpace1),
                          child: Text('Add an existing WabWay user by email',
                              style: kStyleCaption),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded,
                            color: kColorTextTertiary()),
                        onTap: () => showAddMemberSheet(
                          context,
                          tripId: trip?.id ?? '',
                          existingMemberIds: members.map((m) => m.userId).toSet(),
                          onMemberAdded: reload,
                        ),
                      ),
                      const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    ],
                    ListTile(
                      contentPadding: const EdgeInsets.all(kSpace4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: kColorPrimarySoft,
                          borderRadius: kRadiusMd,
                        ),
                        child: const Icon(Icons.key_rounded,
                            size: 20, color: kColorPrimary),
                      ),
                      title: Text('Create invite code', style: kStyleBodySemibold),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: kSpace1),
                        child: Text('Generate a code anyone can use to join',
                            style: kStyleCaption),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: kColorTextTertiary()),
                      onTap: () => showInviteSheet(context, tripId: trip?.id ?? ''),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: kSpace4),

          // Settings
          const _SectionHeader(title: 'Import'),
          const SizedBox(height: kSpace3),
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: _SettingsRow(
                icon: Icons.download_rounded,
                label: 'Import file or link',
                onTap: () => showImportScreen(context, ref),
              ),
            ),
          ),
          const SizedBox(height: kSpace4),

          const _SectionHeader(title: 'Trip settings'),
          const SizedBox(height: kSpace3),
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  if (isOwner) ...[
                    _SettingsRow(
                      icon: Icons.settings_rounded,
                      label: 'Edit trip details',
                      onTap: () { if (trip != null) showTripSettingsSheet(context, ref, trip: trip); },
                    ),
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                  ],
                  _SettingsRow(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    ),
                  ),
                  if (isOwner) ...[
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    _SettingsRow(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Transfer ownership',
                      onTap: () => _showTransferOwnershipSheet(
                          context, trip, members, currentUserId, reload),
                    ),
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    _SettingsRow(
                      icon: Icons.delete_rounded,
                      label: 'Delete trip',
                      color: kColorDanger,
                      onTap: () => _confirmDeleteTrip(context, trip, reload),
                    ),
                  ],
                  if (!isOwner) ...[
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    _SettingsRow(
                      icon: Icons.logout_rounded,
                      label: 'Leave trip',
                      color: kColorDanger,
                      onTap: () => _confirmLeaveTrip(context, trip, reload),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpace4),

          // Share flow preview
          const _SectionHeader(title: 'Share'),
          const SizedBox(height: kSpace3),
          const IncomingShareDemoLauncher(),

          const SizedBox(height: kSpace4),

          // Account
          const _SectionHeader(title: 'Account'),
          const SizedBox(height: kSpace3),
          _AccountSection(),

          const SizedBox(height: kSpace4),

          // Android app download (web only)
          if (kIsWeb) ...[
            const SizedBox(height: kSpace4),
            const _SectionHeader(title: 'App'),
            const SizedBox(height: kSpace3),
            DecoratedBox(
              decoration: kCardDecoration(),
              child: Material(
                color: Colors.transparent,
                child: _SettingsRow(
                  icon: Icons.android_rounded,
                  label: 'Download Android app',
                  onTap: () => launchUrl(
                    Uri.parse('https://github.com/Wahbi-R/WabWay/releases'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ),
            ),
          ],

          // What's new
          const SizedBox(height: kSpace5),
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: _SettingsRow(
                icon: Icons.new_releases_rounded,
                label: "What's new",
                onTap: () => ChangelogService.show(context, forceShow: true),
              ),
            ),
          ),

          // Diagnostics
          const SizedBox(height: kSpace5),
          const _SectionHeader(title: 'Debug'),
          const SizedBox(height: kSpace3),
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: _SettingsRow(
                icon: Icons.bug_report_rounded,
                label: 'Diagnostics',
                onTap: () {
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DiagnosticsScreen(
                        profile: ref.read(profileProvider),
                        trip: ref.read(activeTripProvider),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: kSpace16),
        ],
      ),
    );
  }
}

class _AccountSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            if (profile != null)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace2,
                ),
                leading: CircleAvatar(
                  radius: 20,
                  backgroundColor: kColorPrimarySoft,
                  child: Text(
                    profile.initials,
                    style:
                        kStyleBodySemibold.copyWith(color: kColorPrimaryDark),
                  ),
                ),
                title: Text(profile.displayName, style: kStyleBodyMedium),
                subtitle: Text(profile.email, style: kStyleCaption),
              ),
            if (profile != null) ...[
              const Divider(height: 1, indent: kSpace4),
              _SettingsRow(
                icon: Icons.badge_rounded,
                label: 'Edit name',
                onTap: () => showEditNameSheet(context, ref),
              ),
              const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
              _SettingsRow(
                icon: Icons.lock_rounded,
                label: 'Set / change password',
                onTap: () => showSetPasswordSheet(context),
              ),
              const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
            ],
            _SettingsRow(
              icon: Icons.logout_rounded,
              label: 'Sign out',
              color: kColorDanger,
              onTap: () async => AuthService.signOut(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => Text(title, style: kStyleOverline);
}

// ─── Trip actions ─────────────────────────────────────────────────────────────

Future<void> _confirmRemoveMember(
    BuildContext context, String tripId, member, VoidCallback onRefresh) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
      title: Text('Remove member?', style: kStyleBodySemibold),
      content: Text(
        'Remove ${member.profile.displayName} from the trip? They will lose access immediately.',
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
  if (confirmed != true || !context.mounted) return;
  try {
    await TripService.removeMember(tripId, member.userId as String);
    if (context.mounted) onRefresh();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not remove member.',
            style: kStyleBody.copyWith(color: Colors.white)),
        backgroundColor: kColorDanger,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

Future<void> _confirmLeaveTrip(BuildContext context, trip, VoidCallback onRefresh) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
      title: Text('Leave trip?', style: kStyleBodySemibold),
      content: Text(
        'You will lose access to "${trip.name}" and all its data.',
        style: kStyleBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: kStyleBody.copyWith(color: kColorInkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Leave', style: kStyleBodyMedium.copyWith(color: kColorDanger)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await TripService.leaveTrip(trip.id);
    if (context.mounted) onRefresh();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not leave trip.', style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

Future<void> _confirmDeleteTrip(BuildContext context, trip, VoidCallback onRefresh) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
      title: Text('Delete trip?', style: kStyleBodySemibold),
      content: Text(
        'This will permanently delete "${trip.name}" and all its data for every member. This cannot be undone.',
        style: kStyleBody,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: kStyleBody.copyWith(color: kColorInkSoft)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text('Delete', style: kStyleBodyMedium.copyWith(color: kColorDanger)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  try {
    await TripService.deleteTrip(trip.id);
    if (context.mounted) onRefresh();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not delete trip.', style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kColorDanger,
      ));
    }
  }
}

void _showTransferOwnershipSheet(
  BuildContext context,
  trip,
  List members,
  String? currentUserId,
  VoidCallback onRefresh,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TransferOwnershipSheet(
      trip: trip,
      members: members,
      currentUserId: currentUserId,
      onTransferred: onRefresh,
    ),
  );
}

class _TransferOwnershipSheet extends StatefulWidget {
  const _TransferOwnershipSheet({
    required this.trip,
    required this.members,
    required this.currentUserId,
    required this.onTransferred,
  });

  final dynamic trip;
  final List members;
  final String? currentUserId;
  final VoidCallback onTransferred;

  @override
  State<_TransferOwnershipSheet> createState() =>
      _TransferOwnershipSheetState();
}

class _TransferOwnershipSheetState extends State<_TransferOwnershipSheet> {
  String? _selectedId;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final candidates = (widget.members as List)
        .where((m) => m.userId != widget.currentUserId)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: kColorPaper,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom + kSpace4,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: kSpace2),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: kColorBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: kSpace4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpace4),
              child: Text('Transfer ownership', style: kStyleTitle),
            ),
            const SizedBox(height: kSpace1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpace4),
              child: Text(
                'Choose a member to become the new organiser. You will become a regular member.',
                style: kStyleCaption,
              ),
            ),
            const SizedBox(height: kSpace4),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(kSpace4),
                child: Text('No other members to transfer to.', style: kStyleBody),
              )
            else
              ...candidates.map((m) {
                final isSelected = _selectedId == m.userId;
                return InkWell(
                  onTap: () => setState(() => _selectedId = m.userId),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpace4, vertical: kSpace3),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: kColorPrimarySoft,
                          child: Text(
                            m.profile.initials,
                            style: kStyleBodySemibold.copyWith(
                                color: kColorPrimaryDark),
                          ),
                        ),
                        const SizedBox(width: kSpace3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.profile.displayName, style: kStyleBodyMedium),
                              Text(m.profile.email, style: kStyleCaption),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded,
                              color: kColorPrimary, size: 20),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: kSpace4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpace4),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _selectedId == null ? kColorBorder : kColorPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: kRadiusMd),
                ),
                onPressed: _selectedId == null || _saving ? null : _transfer,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text('Transfer',
                        style: kStyleBodySemibold.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _transfer() async {
    if (_selectedId == null) return;
    setState(() => _saving = true);
    try {
      await TripService.transferOwnership(widget.trip.id, _selectedId!);
      widget.onTransferred();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Transfer failed. Try again.',
              style: kStyleBody.copyWith(color: Colors.white)),
          backgroundColor: kColorDanger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? kColorInkSoft;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace1),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color != null ? kColorDangerSoft : kColorSurfaceSunken,
          borderRadius: kRadiusMd,
        ),
        child: Icon(icon, size: 20, color: effectiveColor),
      ),
      title: Text(
        label,
        style: kStyleBodyMedium.copyWith(color: color ?? kColorInk),
      ),
      trailing: Icon(Icons.chevron_right_rounded,
          color: kColorTextTertiary(), size: 18),
      onTap: onTap,
    );
  }
}

class _ExploreItem {
  const _ExploreItem({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ExploreGrid extends StatelessWidget {
  const _ExploreGrid({required this.items});
  final List<_ExploreItem> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(kSpace2),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childAspectRatio: 0.85,
          children: items.map((item) => _ExploreGridItem(item: item)).toList(),
        ),
      ),
    );
  }
}

class _ExploreGridItem extends StatelessWidget {
  const _ExploreGridItem({required this.item});
  final _ExploreItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusSm,
            ),
            child: Icon(item.icon, size: 20, color: kColorInkSoft),
          ),
          const SizedBox(height: kSpace1),
          Text(
            item.label,
            style: kStyleCaption.copyWith(fontWeight: FontWeight.w600, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

