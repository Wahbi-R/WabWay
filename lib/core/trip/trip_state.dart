import 'package:flutter/widgets.dart';
import 'app_trip.dart';
import 'app_trip_member.dart';

class TripState extends InheritedWidget {
  const TripState({
    super.key,
    required this.trip,
    required this.members,
    required super.child,
    this.onRefresh,
  });

  final AppTrip trip;
  final List<AppTripMember> members;
  final VoidCallback? onRefresh;

  static TripState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripState>();

  static AppTrip tripOf(BuildContext context) {
    final state = context.dependOnInheritedWidgetOfExactType<TripState>();
    assert(state != null, 'No TripState found in widget tree');
    return state!.trip;
  }

  static List<AppTripMember> membersOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripState>()?.members ?? [];

  static void refresh(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripState>()?.onRefresh?.call();

  @override
  bool updateShouldNotify(TripState old) =>
      trip.id != old.trip.id || members != old.members;
}
