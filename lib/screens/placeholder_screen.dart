import 'package:flutter/material.dart';
import '../core/auth/profile_state.dart';
import '../core/supabase/auth_service.dart';
import '../core/trip/trip_state.dart';
import 'account_sheets.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'members/invite_sheet.dart';
import 'trips/trip_settings_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = ProfileState.maybeOf(context);
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
                      onTap: () => showEditNameSheet(context),
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
            final trip = TripState.tripOf(ctx);
            return DecoratedBox(
              decoration: kCardDecoration(),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    _SettingsTile(
                      icon: Icons.tune_rounded,
                      label: 'Trip settings',
                      onTap: () => showTripSettingsSheet(ctx, trip: trip),
                    ),
                    const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
                    _SettingsTile(
                      icon: Icons.person_add_rounded,
                      label: 'Invite members',
                      onTap: () => showInviteSheet(ctx, tripId: trip.id),
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
