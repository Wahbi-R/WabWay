import 'package:flutter/material.dart';
import '../core/auth/profile_state.dart';
import '../core/supabase/auth_service.dart';
import '../core/supabase/trip_service.dart';
import '../core/trip/trip_state.dart';
import 'account_sheets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
import '../widgets/wabway_button.dart';
import '../widgets/wabway_text_field.dart';
import 'docs_screen.dart';
import 'members/add_member_sheet.dart';
import 'members/invite_sheet.dart';
import 'share/incoming_share_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final members = TripState.membersOf(context);
    final trip = TripState.tripOf(context);
    final currentUserId = ProfileState.maybeOf(context)?.id;
    final isOwner = members.any((m) => m.userId == currentUserId && m.isOwner);

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(title: Text('More', style: kStyleTitle)),
      body: ListView(
        padding: const EdgeInsets.all(kSpace4),
        children: [
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

          // Invite section — owner only
          if (isOwner) ...[
            const _SectionHeader(title: 'Invite'),
            const SizedBox(height: kSpace3),
            DecoratedBox(
              decoration: kCardDecoration(),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
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
                        child: Text('Add an existing Wabway user by email',
                            style: kStyleCaption),
                      ),
                      trailing: Icon(Icons.chevron_right_rounded,
                          color: kColorTextTertiary()),
                      onTap: () => showAddMemberSheet(
                        context,
                        tripId: trip.id,
                        existingMemberIds: members.map((m) => m.userId).toSet(),
                        onMemberAdded: () => TripState.refresh(context),
                      ),
                    ),
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
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
                      onTap: () => showInviteSheet(context, tripId: trip.id),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: kSpace4),

          // Documents shortcut — visible on mobile only (docs tab removed from bottom nav)
          const _SectionHeader(title: 'Documents'),
          const SizedBox(height: kSpace3),
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: _SettingsRow(
                icon: Icons.folder_rounded,
                label: 'View documents',
                onTap: () {
                  // Capture providers before pushing — InheritedWidgets are not
                  // available to new routes pushed on the root Navigator.
                  final trip = TripState.tripOf(context);
                  final members = TripState.membersOf(context);
                  final profile = ProfileState.of(context);
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileState(
                        profile: profile,
                        child: TripState(
                          trip: trip,
                          members: members,
                          child: const DocsScreen(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: kSpace4),

          // Settings
          const _SectionHeader(title: 'Trip settings'),
          const SizedBox(height: kSpace3),
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: Column(
                children: [
                  _SettingsRow(
                    icon: Icons.edit_rounded,
                    label: 'Edit trip name',
                    onTap: () => _showEditTripNameSheet(context, trip),
                  ),
                  const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                  _SettingsRow(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    // TODO: Notifications — needs a backend event system (Supabase
                    // realtime or push via FCM). Show per-category toggles here.
                    onTap: () {},
                  ),
                  if (!isOwner) ...[
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    _SettingsRow(
                      icon: Icons.logout_rounded,
                      label: 'Leave trip',
                      color: kColorDanger,
                      onTap: () => _confirmLeaveTrip(context, trip),
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

          const SizedBox(height: kSpace16),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final profile = ProfileState.maybeOf(context);
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
                onTap: () => showEditNameSheet(context),
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

void _showEditTripNameSheet(BuildContext context, trip) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EditTripNameSheet(
      initialName: trip.name,
      tripId: trip.id,
      onSaved: (_) => TripState.refresh(context),
    ),
  );
}

Future<void> _confirmLeaveTrip(BuildContext context, trip) async {
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
    if (context.mounted) TripState.refresh(context);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not leave trip.', style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }
}

class _EditTripNameSheet extends StatefulWidget {
  const _EditTripNameSheet({
    required this.initialName,
    required this.tripId,
    required this.onSaved,
  });
  final String initialName;
  final String tripId;
  final ValueChanged<String> onSaved;

  @override
  State<_EditTripNameSheet> createState() => _EditTripNameSheetState();
}

class _EditTripNameSheetState extends State<_EditTripNameSheet> {
  late final TextEditingController _ctrl;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Trip name cannot be empty.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await TripService.updateTripName(widget.tripId, name);
      if (mounted) {
        widget.onSaved(name);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(kSpace6, kSpace5, kSpace6, kSpace8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: const BoxDecoration(color: kColorBorder, borderRadius: kRadiusPill),
                ),
              ),
              const SizedBox(height: kSpace4),
              Text('Edit trip name', style: kStyleTitle),
              const SizedBox(height: kSpace5),
              WabwayTextField(
                label: 'Trip name',
                controller: _ctrl,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                error: _error,
              ),
              const SizedBox(height: kSpace4),
              WabwayButton(
                label: 'Save',
                onPressed: _loading ? null : _save,
                loading: _loading,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
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
