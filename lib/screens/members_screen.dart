import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth/profile_state.dart';
import '../core/supabase/trip_service.dart';
import '../core/trip/app_trip_member.dart';
import '../core/trip/trip_state.dart';
import '../data/date_utils.dart';
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
          if (trip.groupChatUrl != null && trip.groupChatUrl!.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              color: kColorPrimary,
              tooltip: 'Open group chat',
              onPressed: () => launchUrl(
                Uri.parse(trip.groupChatUrl!),
                mode: LaunchMode.externalApplication,
              ),
            ),
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
                return _MemberCard(
                  member: member,
                  isMe: isMe,
                  tripId: trip.id,
                );
              },
            ),
    );
  }
}

// ─── Member card ──────────────────────────────────────────────────────────────

class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.member,
    required this.isMe,
    required this.tripId,
  });

  final AppTripMember member;
  final bool isMe;
  final String tripId;

  Future<void> _editDates(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MemberDatesSheet(member: member, tripId: tripId),
    );
    if (context.mounted) TripState.refresh(context);
  }

  @override
  Widget build(BuildContext context) {
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
                    onTap: () => _editDates(context),
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
              onTap: () => _editDates(context),
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

  Future<void> _pickDate({required bool isArrival}) async {
    final initial = isArrival
        ? (_arrival ?? DateTime.now())
        : (_departure ?? _arrival ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isArrival) {
        _arrival = picked;
        // Keep departure >= arrival
        if (_departure != null && _departure!.isBefore(picked)) {
          _departure = picked;
        }
      } else {
        _departure = picked;
      }
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
              onTap: () => _pickDate(isArrival: true),
              onClear: _arrival != null ? () => setState(() => _arrival = null) : null,
            ),
            const SizedBox(height: kSpace3),
            _DateRow(
              icon: Icons.flight_takeoff_rounded,
              label: 'Departure date',
              date: _departure,
              onTap: () => _pickDate(isArrival: false),
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
