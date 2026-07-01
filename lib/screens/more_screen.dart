import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const _members = [
    ('Alex', 'alex@example.com', true),
    ('Jordan', 'jordan@example.com', false),
    ('Sam', 'sam@example.com', false),
    ('You', 'you@example.com', false),
  ];

  @override
  Widget build(BuildContext context) {
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
                children: _members.asMap().entries.map((e) {
                  final i = e.key;
                  final (name, email, isOrganiser) = e.value;
                  final isLast = i == _members.length - 1;
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
                            name[0],
                            style: kStyleBodySemibold.copyWith(color: kColorPrimaryDark),
                          ),
                        ),
                        title: Text(name, style: kStyleBodyMedium),
                        subtitle: Text(email, style: kStyleCaption),
                        trailing: isOrganiser
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
                                  style: kStyleOverline.copyWith(color: kColorAccent),
                                ),
                              )
                            : null,
                      ),
                      if (!isLast)
                        const Divider(height: 1, indent: kSpace4 + 36 + kSpace3),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: kSpace4),

          // Invite section
          const _SectionHeader(title: 'Invite'),
          const SizedBox(height: kSpace3),
          DecoratedBox(
            decoration: kCardDecoration(),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.all(kSpace4),
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: kColorPrimarySoft,
                    borderRadius: kRadiusMd,
                  ),
                  child: const Icon(Icons.person_add_rounded, size: 20, color: kColorPrimary),
                ),
                title: Text('Invite friends', style: kStyleBodySemibold),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: kSpace1),
                  child: Text('Share a link or invite code', style: kStyleCaption),
                ),
                trailing: Icon(Icons.chevron_right_rounded, color: kColorTextTertiary()),
                onTap: () {},
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
          const SizedBox(height: kSpace16),
        ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace1),
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
      trailing: Icon(Icons.chevron_right_rounded, color: kColorTextTertiary(), size: 18),
      onTap: onTap,
    );
  }
}
