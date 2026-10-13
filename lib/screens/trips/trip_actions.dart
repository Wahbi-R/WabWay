import 'package:flutter/material.dart';
import '../../core/supabase/trip_service.dart';
import '../../widgets/widgets.dart';

// Trip-level destructive actions, shared by Settings and More.

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
