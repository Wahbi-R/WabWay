import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/trip_service.dart';
import '../core/trip/app_trip_member.dart';
import '../data/date_utils.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';
import '../widgets/widgets.dart';
import 'members/add_member_sheet.dart';
import 'members/invite_sheet.dart';
import '../core/text_utils.dart';

/// The member list with the invite / add-member action on top. Lives in
/// Crew → Members — the one "people" screen (chat, live map, members).
class MembersList extends ConsumerWidget {
  const MembersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(tripMembersProvider);
    final trip = ref.watch(activeTripProvider);
    if (trip == null) return const SizedBox.shrink();
    final currentUserId = ref.watch(profileProvider)?.id;
    final isOwner = ref.watch(isOrganiserProvider);

    return ListView(
      padding: const EdgeInsets.all(kSpace4),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(pluralize(members.length, 'member'), style: kStyleCaptionMedium),
            ),
            if (trip.groupChatUrl != null && trip.groupChatUrl!.isNotEmpty) ...[
              WabwayButton(
                label: 'Group chat',
                icon: Icons.chat_bubble_outline_rounded,
                size: WabwayButtonSize.sm,
                variant: WabwayButtonVariant.ghost,
                onPressed: () => launchUrl(
                  Uri.parse(trip.groupChatUrl!),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(width: kSpace2),
            ],
            // Everyone can invite (codes); only the organiser can add an
            // existing user directly (RLS: trip_members insert is owner-only).
            WabwayButton(
              label: isOwner ? 'Add member' : 'Invite',
              icon: Icons.person_add_rounded,
              size: WabwayButtonSize.sm,
              onPressed: () => isOwner
                  ? showAddMemberSheet(
                      context,
                      tripId: trip.id,
                      existingMemberIds: members.map((m) => m.userId).toSet(),
                      onMemberAdded: () => ref.read(tripNotifierProvider.notifier).load(),
                    )
                  : showInviteSheet(context, tripId: trip.id),
            ),
          ],
        ),
        const SizedBox(height: kSpace3),
        for (final member in members) ...[
          _MemberCard(
            member: member,
            isMe: member.userId == currentUserId,
            tripId: trip.id,
          ),
          const SizedBox(height: kSpace3),
        ],
      ],
    );
  }
}

// ─── Member card ──────────────────────────────────────────────────────────────

class _MemberCard extends ConsumerWidget {
  const _MemberCard({
    required this.member,
    required this.isMe,
    required this.tripId,
  });

  final AppTripMember member;
  final bool isMe;
  final String tripId;

  Future<void> _editDates(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberDatesSheet(member: member, tripId: tripId),
    );
    if (context.mounted) ref.read(tripNotifierProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName =
        isMe ? '${member.profile.displayName} (You)' : member.profile.displayName;

    return WabwayCard(
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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

          // Dates row — shown when set, or as an edit prompt for the current user
          if (member.hasDates) ...[
            const SizedBox(height: kSpace3),
            const Divider(height: 1),
            const SizedBox(height: kSpace3),
            Row(
              children: [
                if (member.arrivalDate != null) ...[
                  const Icon(Icons.flight_land_rounded, size: 14, color: kColorInkSoft),
                  const SizedBox(width: 4),
                  Text('Arrives ${fmtDate(member.arrivalDate!)}', style: kStyleCaption),
                ],
                if (member.arrivalDate != null && member.departureDate != null)
                  const SizedBox(width: kSpace4),
                if (member.departureDate != null) ...[
                  const Icon(Icons.flight_takeoff_rounded, size: 14, color: kColorInkSoft),
                  const SizedBox(width: 4),
                  Text('Leaves ${fmtDate(member.departureDate!)}', style: kStyleCaption),
                ],
                const Spacer(),
                if (isMe)
                  GestureDetector(
                    onTap: () => _editDates(context, ref),
                    child: Text(
                      'Edit',
                      style: kStyleCaption.copyWith(color: kColorPrimary),
                    ),
                  ),
              ],
            ),
          ] else if (isMe) ...[
            const SizedBox(height: kSpace3),
            GestureDetector(
              onTap: () => _editDates(context, ref),
              child: Row(
                children: [
                  const Icon(Icons.add_rounded, size: 14, color: kColorPrimary),
                  const SizedBox(width: 4),
                  Text(
                    'Set your arrival & departure dates',
                    style: kStyleCaption.copyWith(color: kColorPrimary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Edit dates sheet ─────────────────────────────────────────────────────────

class _MemberDatesSheet extends StatefulWidget {
  const _MemberDatesSheet({required this.member, required this.tripId});
  final AppTripMember member;
  final String tripId;

  @override
  State<_MemberDatesSheet> createState() => _MemberDatesSheetState();
}

class _MemberDatesSheetState extends State<_MemberDatesSheet> {
  DateTime? _arrival;
  DateTime? _departure;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _arrival   = widget.member.arrivalDate;
    _departure = widget.member.departureDate;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _arrival ?? now,
        end: _departure ??
            (_arrival?.add(const Duration(days: 7)) ??
                now.add(const Duration(days: 7))),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      helpText: 'SELECT YOUR DATES',
      saveText: 'Done',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _arrival = picked.start;
      _departure = picked.end;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await TripService.updateMemberDates(
        widget.tripId,
        widget.member.userId,
        arrivalDate:     _arrival,
        departureDate:   _departure,
        clearArrival:    _arrival == null,
        clearDeparture:  _departure == null,
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusSheet,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kSpace4, kSpace3, kSpace4,
          kSpace6 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WabwayDragHandle(),
            const SizedBox(height: kSpace3),
            Text('Your trip dates', style: kStyleTitle),
            const SizedBox(height: 4),
            Text(
              'Let the group know when you\'re joining and leaving.',
              style: kStyleCaption,
            ),
            const SizedBox(height: kSpace5),

            _DateRow(
              icon: Icons.flight_land_rounded,
              label: 'Arrival date',
              date: _arrival,
              onTap: _pickDateRange,
              onClear: _arrival != null ? () => setState(() => _arrival = null) : null,
            ),
            const SizedBox(height: kSpace3),
            _DateRow(
              icon: Icons.flight_takeoff_rounded,
              label: 'Departure date',
              date: _departure,
              onTap: _pickDateRange,
              onClear: _departure != null ? () => setState(() => _departure = null) : null,
            ),

            const SizedBox(height: kSpace5),
            WabwayButton(
              label: _saving ? 'Saving…' : 'Save',
              icon: Icons.check_rounded,
              fullWidth: true,
              size: WabwayButtonSize.lg,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.icon,
    required this.label,
    required this.date,
    required this.onTap,
    this.onClear,
  });
  final IconData icon;
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border: Border.all(color: kColorBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
          child: Row(
            children: [
              Icon(icon, size: 18, color: kColorInkSoft),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: kStyleCaption),
                    const SizedBox(height: 2),
                    Text(
                      date != null ? fmtDate(date!) : 'Not set',
                      style: kStyleBodyMedium.copyWith(
                        color: date != null ? kColorInk : kColorInkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded, size: 18, color: kColorInkSoft),
                )
              else
                const Icon(Icons.chevron_right_rounded, size: 18, color: kColorInkSoft),
            ],
          ),
        ),
      ),
    );
  }
}
