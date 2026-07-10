import 'package:flutter/widgets.dart';
import 'app_trip.dart';
import 'app_trip_member.dart';

// InheritedWidget that broadcasts the active trip and its member list down
// the widget tree without threading them through every constructor.
//
// Usage inside any descendant:
//   final trip    = TripState.tripOf(context);     // throws if missing
//   final members = TripState.membersOf(context);  // returns [] if missing
//   TripState.refresh(context);                    // tells TripGate to re-fetch
//
// Secondary screens pushed from the More screen must wrap their builder in
// ProfileState + TripState so the InheritedWidgets survive the new route.
// Use the _pushWithState() helper in more_screen.dart for this.
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
