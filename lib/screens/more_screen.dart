import 'package:flutter/material.dart';
import '../core/auth/profile_state.dart';
import '../core/supabase/auth_service.dart';
import '../core/trip/trip_state.dart';
import 'account_sheets.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
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
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                  _SettingsRow(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    onTap: () {},
                  ),
                  const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                  _SettingsRow(
                    icon: Icons.logout_rounded,
                    label: 'Leave trip',
                    color: kColorDanger,
                    onTap: () {},
                  ),
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
