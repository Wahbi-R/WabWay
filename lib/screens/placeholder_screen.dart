import 'package:flutter/material.dart';
import '../core/auth/profile_state.dart';
import '../core/supabase/auth_service.dart';
import 'account_sheets.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    required this.icon,
    this.body,
  });

  final String title;
  final IconData icon;
  final String? body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(title: Text(title, style: kStyleTitle)),
      body: Center(
        child: WabwayEmptyState(
          icon: icon,
          title: 'Nothing here yet',
          description: body ?? '$title is coming soon.',
        ),
      ),
    );
  }
}

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
          DecoratedBox(
            decoration: kCardDecoration(),
            child: const Material(
              color: Colors.transparent,
              child: WabwayEmptyState(
                icon: Icons.settings_rounded,
                title: 'Coming soon',
                description:
                    'Trip settings, invite codes, and notifications will appear here.',
              ),
            ),
          ),
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
