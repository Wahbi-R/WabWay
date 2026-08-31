import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/auth_service.dart';
import '../core/supabase/trip_service.dart';
import 'account_sheets.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'emergency_screen.dart';
import 'pins_screen.dart';
import 'members/invite_sheet.dart';
import 'trips/trip_settings_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDeleteTrip(BuildContext context, WidgetRef ref, trip) async {
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
      if (context.mounted) await ref.read(tripNotifierProvider.notifier).load();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not delete trip.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _confirmLeaveTrip(BuildContext context, WidgetRef ref, trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Leave trip?', style: kStyleBodySemibold),
        content: Text(
          'You will lose access to "${trip.name}" immediately.',
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
      if (context.mounted) await ref.read(tripNotifierProvider.notifier).load();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not leave trip.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(title: Text('Settings', style: kStyleTitle)),
      body: ListView(
        padding: const EdgeInsets.all(kSpace4),
        children: [
          Text('ACCOUNT', style: kStyleOverline),
          const SizedBox(height: kSpace3),
          DecoratedBox(
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
                          style: kStyleBodySemibold.copyWith(color: kColorPrimaryDark),
                        ),
                      ),
                      title: Text(profile.displayName, style: kStyleBodyMedium),
                      subtitle: Text(profile.email, style: kStyleCaption),
                    ),
                  if (profile != null) ...[
                    const Divider(height: 1, indent: kSpace4),
                    _SettingsTile(
                      icon: Icons.badge_rounded,
                      label: 'Edit name',
                      onTap: () => showEditNameSheet(context, ref),
                    ),
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    _SettingsTile(
                      icon: Icons.lock_rounded,
                      label: 'Set / change password',
                      onTap: () => showSetPasswordSheet(context),
                    ),
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                  ],
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    color: kColorDanger,
                    onTap: () async => AuthService.signOut(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: kSpace4),
          Text('TRIP', style: kStyleOverline),
          const SizedBox(height: kSpace3),
          Builder(builder: (ctx) {
            final trip = ref.watch(activeTripProvider)!;
            final members = ref.watch(tripMembersProvider);
            final currentUserId = ref.watch(profileProvider)?.id;
            final isOwner = members.any((m) => m.userId == currentUserId && m.isOwner);
            return DecoratedBox(
              decoration: kCardDecoration(),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    if (isOwner) ...[
                      _SettingsTile(
                        icon: Icons.tune_rounded,
                        label: 'Trip settings',
                        onTap: () => showTripSettingsSheet(ctx, ref, trip: trip),
                      ),
                      const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    ],
                    _SettingsTile(
                      icon: Icons.person_add_rounded,
                      label: 'Invite members',
                      onTap: () => showInviteSheet(ctx, tripId: trip.id, canRevoke: isOwner),
                    ),
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    _SettingsTile(
                      icon: Icons.health_and_safety_rounded,
                      label: 'Emergency info',
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(builder: (_) => const EmergencyScreen()),
                      ),
                    ),
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    _SettingsTile(
                      icon: Icons.push_pin_rounded,
                      label: 'Pinboard',
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(builder: (_) => const PinsScreen()),
                      ),
                    ),
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    if (isOwner)
                      _SettingsTile(
                        icon: Icons.delete_rounded,
                        label: 'Delete trip',
                        color: kColorDanger,
                        onTap: () => _confirmDeleteTrip(ctx, ref, trip),
                      )
                    else
                      _SettingsTile(
                        icon: Icons.logout_rounded,
                        label: 'Leave trip',
                        color: kColorDanger,
                        onTap: () => _confirmLeaveTrip(ctx, ref, trip),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
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
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpace4,
        vertical: kSpace1,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color != null ? kColorDangerSoft : kColorSurfaceSunken,
          borderRadius: kRadiusMd,
        ),
        child: Icon(icon, size: 20, color: color ?? kColorInkSoft),
      ),
      title: Text(
        label,
        style: kStyleBodyMedium.copyWith(color: color ?? kColorInk),
      ),
      onTap: onTap,
    );
  }
}
