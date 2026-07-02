import 'package:flutter/material.dart';
import '../core/auth/profile_state.dart';
import '../core/trip/trip_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
import '../widgets/widgets.dart';
import 'members/add_member_sheet.dart';

class MembersScreen extends StatelessWidget {
  const MembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final members = TripState.membersOf(context);
    final trip = TripState.tripOf(context);
    final currentUserId = ProfileState.maybeOf(context)?.id;
    final isOwner = members.any((m) => m.userId == currentUserId && m.isOwner);

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Members', style: kStyleTitle),
        actions: [
          if (isOwner) ...[
            WabwayButton(
              label: 'Add member',
              icon: Icons.person_add_rounded,
              size: WabwayButtonSize.sm,
              onPressed: () => showAddMemberSheet(
                context,
                tripId: trip.id,
                existingMemberIds: members.map((m) => m.userId).toSet(),
                onMemberAdded: () => TripState.refresh(context),
              ),
            ),
            const SizedBox(width: kSpace4),
          ],
        ],
      ),
      body: members.isEmpty
          ? const Center(child: Text('No members yet.'))
          : ListView.separated(
              padding: const EdgeInsets.all(kSpace4),
              itemCount: members.length,
              separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
              itemBuilder: (context, i) {
                final member = members[i];
                final isMe = member.userId == currentUserId;
                final displayName =
                    isMe ? '${member.profile.displayName} (You)' : member.profile.displayName;

                return WabwayCard(
                  padding: const EdgeInsets.all(kSpace4),
                  child: Row(
                    children: [
                      WabwayAvatar(
                        name: member.profile.displayName,
                        size: WabwayAvatarSize.lg,
                      ),
                      const SizedBox(width: kSpace4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: kStyleBodyBold),
                            const SizedBox(height: 2),
                            Text(member.profile.email, style: kStyleCaption),
                          ],
                        ),
                      ),
                      WabwayBadge(
                        label: member.isOwner ? 'Organiser' : 'Member',
                        tone: member.isOwner
                            ? WabwayBadgeTone.accent
                            : WabwayBadgeTone.neutral,
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
