import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/trip_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// Trip-level actions (delete, leave, remove member, transfer ownership),
// shared by Settings and More.

Future<void> confirmDeleteTrip(
    BuildContext context, dynamic trip, Future<void> Function() onDone) async {
  final ok = await showWabwayDeleteConfirm(context,
      entity: 'trip', name: trip.name as String, detail: 'and all its data for every member');
  if (!ok || !context.mounted) return;
  try {
    await TripService.deleteTrip(trip.id as String);
    if (context.mounted) await onDone();
  } catch (_) {
    if (context.mounted) showWabwaySnack(context, 'Could not delete trip.', error: true);
  }
}

Future<void> confirmLeaveTrip(
    BuildContext context, dynamic trip, Future<void> Function() onDone) async {
  final ok = await showWabwayConfirm(context,
      title: 'Leave trip?',
      message: 'You will lose access to "${trip.name}" and all its data immediately.',
      confirmLabel: 'Leave');
  if (!ok || !context.mounted) return;
  try {
    await TripService.leaveTrip(trip.id as String);
    if (context.mounted) await onDone();
  } catch (_) {
    if (context.mounted) showWabwaySnack(context, 'Could not leave trip.', error: true);
  }
}

Future<void> confirmRemoveMember(BuildContext context, String tripId, dynamic member,
    Future<void> Function() onDone) async {
  final ok = await showWabwayConfirm(context,
      title: 'Remove member?',
      message:
          'Remove ${member.profile.displayName} from the trip? They will lose access immediately.',
      confirmLabel: 'Remove');
  if (!ok || !context.mounted) return;
  try {
    await TripService.removeMember(tripId, member.userId as String);
    if (context.mounted) await onDone();
  } catch (_) {
    if (context.mounted) showWabwaySnack(context, 'Could not remove member.', error: true);
  }
}

/// Hand the active trip to another member; you become a regular member.
Future<void> showTransferOwnershipSheet(BuildContext context) {
  return showWabwayAutoSheet<void>(
    context,
    builder: (ctx, handle) => _TransferOwnershipSheet(showDragHandle: handle),
  );
}

class _TransferOwnershipSheet extends ConsumerStatefulWidget {
  const _TransferOwnershipSheet({required this.showDragHandle});
  final bool showDragHandle;

  @override
  ConsumerState<_TransferOwnershipSheet> createState() => _TransferOwnershipSheetState();
}

class _TransferOwnershipSheetState extends ConsumerState<_TransferOwnershipSheet> {
  String? _selectedId;
  bool _saving = false;

  Future<void> _transfer(String tripId) async {
    final newOwner = _selectedId;
    if (newOwner == null) return;
    setState(() => _saving = true);
    try {
      await TripService.transferOwnership(tripId, newOwner);
      await ref.read(tripNotifierProvider.notifier).load();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWabwaySnack(context, 'Transfer failed. Try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = ref.watch(activeTripProvider);
    final myId = ref.watch(profileProvider)?.id;
    final candidates =
        ref.watch(tripMembersProvider).where((m) => m.userId != myId).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(0, kSpace2, 0, kSpace5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showDragHandle) const WabwayDragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, kSpace1),
            child: Text('Transfer ownership', style: kStyleTitle),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpace4),
            child: Text(
              'Choose a member to become the new organiser. You will become a regular member.',
              style: kStyleCaption,
            ),
          ),
          const SizedBox(height: kSpace3),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(kSpace4),
              child: Text('No other members to transfer to.', style: kStyleBody),
            )
          else
            for (final m in candidates)
              InkWell(
                onTap: () => setState(() => _selectedId = m.userId),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
                  child: Row(
                    children: [
                      WabwayAvatar(name: m.profile.displayName, size: WabwayAvatarSize.md),
                      const SizedBox(width: kSpace3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.profile.displayName, style: kStyleBodyMedium),
                            Text(m.profile.email, style: kStyleCaption),
                          ],
                        ),
                      ),
                      if (_selectedId == m.userId)
                        const Icon(Icons.check_circle_rounded, color: kColorPrimary, size: 20),
                    ],
                  ),
                ),
              ),
          const SizedBox(height: kSpace4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpace4),
            child: WabwayButton(
              label: 'Transfer',
              fullWidth: true,
              loading: _saving,
              onPressed: _selectedId == null || trip == null ? null : () => _transfer(trip.id),
            ),
          ),
        ],
      ),
    );
  }
}
