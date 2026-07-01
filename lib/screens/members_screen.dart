import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
import '../widgets/widgets.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  static const _members = [
    ('Alex',   'alex@example.com',   'Organiser', WabwayBadgeTone.accent),
    ('Jordan', 'jordan@example.com', 'Member',    WabwayBadgeTone.neutral),
    ('Sam',    'sam@example.com',    'Member',    WabwayBadgeTone.neutral),
    ('You',    'you@example.com',    'Member',    WabwayBadgeTone.neutral),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Members', style: kStyleTitle),
        actions: [
          WabwayButton(
            label: 'Invite friends',
            icon: Icons.person_add_rounded,
            size: WabwayButtonSize.sm,
            onPressed: () {},
          ),
          const SizedBox(width: kSpace4),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(kSpace4),
        itemCount: _members.length,
        separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
        itemBuilder: (context, i) {
          final (name, email, role, tone) = _members[i];
          return WabwayCard(
            padding: const EdgeInsets.all(kSpace4),
            child: Row(
              children: [
                WabwayAvatar(name: name, size: WabwayAvatarSize.lg),
                const SizedBox(width: kSpace4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: kStyleBodyBold),
                      const SizedBox(height: 2),
                      Text(email, style: kStyleCaption),
                    ],
                  ),
                ),
                WabwayBadge(label: role, tone: tone),
              ],
            ),
          );
        },
      ),
    );
  }
}
