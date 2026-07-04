import 'package:flutter/widgets.dart';
import 'app_trip.dart';
import 'app_trip_member.dart';

class TripState extends InheritedWidget {
  const TripState({
    super.key,
    required this.trip,
    required this.members,
    required super.child,
    this.allTrips = const [],
    this.onRefresh,
    this.onSwitchTrip,
  });

  final AppTrip trip;
  final List<AppTripMember> members;
  final List<AppTrip> allTrips;
  final VoidCallback? onRefresh;
  final void Function(AppTrip)? onSwitchTrip;

  static TripState? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripState>();

  static AppTrip tripOf(BuildContext context) {
    final state = context.dependOnInheritedWidgetOfExactType<TripState>();
    assert(state != null, 'No TripState found in widget tree');
    return state!.trip;
  }

  static List<AppTripMember> membersOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripState>()?.members ?? [];

  static List<AppTrip> allTripsOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripState>()?.allTrips ?? [];

  static void refresh(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripState>()?.onRefresh?.call();

  static void switchTrip(BuildContext context, AppTrip trip) =>
      context.dependOnInheritedWidgetOfExactType<TripState>()?.onSwitchTrip?.call(trip);

  @override
  bool updateShouldNotify(TripState old) =>
      trip.id != old.trip.id ||
      members != old.members ||
      allTrips.length != old.allTrips.length;
}
