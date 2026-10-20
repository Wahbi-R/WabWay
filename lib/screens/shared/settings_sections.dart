import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/changelog.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../account_sheets.dart';
import '../ai_access_screen.dart';
import '../diagnostics_screen.dart';
import '../emergency_screen.dart';
import '../members/invite_sheet.dart';
import '../notification_settings_screen.dart';
import '../pins_screen.dart';
import '../share/incoming_share_screen.dart';
import '../trips/trip_actions.dart';
import '../trips/trip_settings_sheet.dart';

// Settings sections shared by mobile More and desktop Settings, so a row added
// to one screen can't go missing from the other again (AI access, Pinboard,
// Emergency info and Transfer ownership each did).

/// One settings row: icon tile, label, chevron. [color] marks it destructive.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace1),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color != null ? kColorDangerSoft : kColorSurfaceSunken,
          borderRadius: kRadiusMd,
        ),
        child: Icon(icon, size: 20, color: color ?? kColorInkSoft),
      ),
      title: Text(label, style: kStyleBodyMedium.copyWith(color: color ?? kColorInk)),
      trailing: Icon(Icons.chevron_right_rounded, color: kColorTextTertiary(), size: 18),
      onTap: onTap,
    );
  }
}

/// A card of rows with the standard inset dividers between them.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: kSpace4 + 40 + kSpace3),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Overline title + card, with the spacing both screens use.
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: kStyleOverline),
          const SizedBox(height: kSpace3),
          child,
        ],
      ),
    );
  }
}

void _push(BuildContext context, Widget screen) =>
    Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));

/// Profile + Edit name / password / AI access / Sign out.
class AccountSettingsCard extends ConsumerWidget {
  const AccountSettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return SettingsCard(children: [
      if (profile != null) ...[
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: kColorPrimarySoft,
            child: Text(profile.initials,
                style: kStyleBodySemibold.copyWith(color: kColorPrimaryDark)),
          ),
          title: Text(profile.displayName, style: kStyleBodyMedium),
          subtitle: Text(profile.email, style: kStyleCaption),
        ),
        SettingsRow(
          icon: Icons.badge_rounded,
          label: 'Edit name',
          onTap: () => showEditNameSheet(context, ref),
        ),
        SettingsRow(
          icon: Icons.lock_rounded,
          label: 'Set / change password',
          onTap: () => showSetPasswordSheet(context),
        ),
        SettingsRow(
          icon: Icons.smart_toy_rounded,
          label: 'AI access',
          onTap: () => _push(context, const AiAccessScreen()),
        ),
      ],
      SettingsRow(
        icon: Icons.logout_rounded,
        label: 'Sign out',
        color: kColorDanger,
        onTap: () async => AuthService.signOut(),
      ),
    ]);
  }
}

/// Everything about the active trip: details, invite, emergency info,
/// pinboard, notifications, ownership, delete/leave. Hidden until a trip loads.
class TripSettingsCard extends ConsumerWidget {
  const TripSettingsCard({super.key, this.showInvite = true});

  /// Mobile More has its own Invite section, so it passes false.
  final bool showInvite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(activeTripProvider);
    if (trip == null) return const SizedBox.shrink();
    final isOwner = ref.watch(isOrganiserProvider);
    Future<void> reload() => ref.read(tripNotifierProvider.notifier).load();

    return SettingsCard(children: [
      if (isOwner)
        SettingsRow(
          icon: Icons.tune_rounded,
          label: 'Edit trip details',
          onTap: () => showTripSettingsSheet(context, ref, trip: trip),
        ),
      if (showInvite)
        SettingsRow(
          icon: Icons.person_add_rounded,
          label: 'Invite members',
          onTap: () => showInviteSheet(context, tripId: trip.id, canRevoke: isOwner),
        ),
      SettingsRow(
        icon: Icons.health_and_safety_rounded,
        label: 'Emergency info',
        onTap: () => _push(context, const EmergencyScreen()),
      ),
      SettingsRow(
        icon: Icons.push_pin_rounded,
        label: 'Pinboard',
        onTap: () => _push(context, const PinsScreen()),
      ),
      SettingsRow(
        icon: Icons.notifications_rounded,
        label: 'Notifications',
        onTap: () => _push(context, const NotificationSettingsScreen()),
      ),
      if (isOwner) ...[
        SettingsRow(
          icon: Icons.swap_horiz_rounded,
          label: 'Transfer ownership',
          onTap: () => showTransferOwnershipSheet(context),
        ),
        SettingsRow(
          icon: Icons.delete_rounded,
          label: 'Delete trip',
          color: kColorDanger,
          onTap: () => confirmDeleteTrip(context, trip, reload),
        ),
      ] else
        SettingsRow(
          icon: Icons.logout_rounded,
          label: 'Leave trip',
          color: kColorDanger,
          onTap: () => confirmLeaveTrip(context, trip, reload),
        ),
    ]);
  }
}

/// Import, Android download (web), What's new, Diagnostics, share-flow preview.
class AppSettingsSections extends ConsumerWidget {
  const AppSettingsSections({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          title: 'Import',
          child: SettingsCard(children: [
            SettingsRow(
              icon: Icons.download_rounded,
              label: 'Import file or link',
              onTap: () => showImportScreen(context, ref),
            ),
          ]),
        ),
        SettingsSection(
          title: 'App',
          child: SettingsCard(children: [
            if (kIsWeb)
              SettingsRow(
                icon: Icons.android_rounded,
                label: 'Download Android app',
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/Wahbi-R/WabWay/releases/latest'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            SettingsRow(
              icon: Icons.new_releases_rounded,
              label: "What's new",
              onTap: () => ChangelogService.show(context, forceShow: true),
            ),
            SettingsRow(
              icon: Icons.bug_report_rounded,
              label: 'Diagnostics',
              onTap: () => _push(
                context,
                DiagnosticsScreen(
                  profile: ref.read(profileProvider),
                  trip: ref.read(activeTripProvider),
                ),
              ),
            ),
          ]),
        ),
        const SettingsSection(title: 'Share preview', child: IncomingShareDemoLauncher()),
      ],
    );
  }
}
