import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../trip/app_trip.dart';
import '../trip/app_trip_member.dart';
import '../supabase/trip_service.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class TripData {
  const TripData({
    this.trips          = const [],
    this.members        = const [],
    this.selectedIndex  = 0,
    this.loading        = true,
    this.error          = false,
  });

  final List<AppTrip>       trips;
  final List<AppTripMember> members;
  final int                 selectedIndex;
  final bool                loading;
  final bool                error;

  AppTrip? get activeTrip =>
      trips.isEmpty ? null : trips[selectedIndex];

  TripData copyWith({
    List<AppTrip>?       trips,
    List<AppTripMember>? members,
    int?                 selectedIndex,
    bool?                loading,
    bool?                error,
  }) => TripData(
    trips:         trips         ?? this.trips,
    members:       members       ?? this.members,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    loading:       loading       ?? this.loading,
    error:         error         ?? this.error,
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TripNotifier extends StateNotifier<TripData> {
  TripNotifier() : super(const TripData());

  Future<void> load() async {
    state = state.copyWith(loading: true, error: false);
    try {
      final trips = await TripService.loadUserTrips();
      if (trips.isEmpty) {
        state = state.copyWith(trips: [], members: [], loading: false);
        return;
      }
      final idx     = state.selectedIndex.clamp(0, trips.length - 1);
      final members = await TripService.loadTripMembers(trips[idx].id);
      state = state.copyWith(
        trips:        trips,
        members:      members,
        selectedIndex: idx,
        loading:      false,
      );
    } catch (_) {
      state = state.copyWith(loading: false, error: true);
    }
  }

  Future<void> switchTrip(AppTrip trip) async {
    final idx = state.trips.indexWhere((t) => t.id == trip.id);
    if (idx < 0 || idx == state.selectedIndex) return;
    state = state.copyWith(loading: true);
    try {
      final members = await TripService.loadTripMembers(trip.id);
      state = state.copyWith(
        selectedIndex: idx,
        members:       members,
        loading:       false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> reloadMembers() async {
    if (state.trips.isEmpty) return;
    try {
      final members =
          await TripService.loadTripMembers(state.trips[state.selectedIndex].id);
      state = state.copyWith(members: members);
    } catch (_) {}
  }

  void setTrips(List<AppTrip> trips, List<AppTripMember> members, int idx) {
    state = state.copyWith(
      trips:        trips,
      members:      members,
      selectedIndex: idx,
      loading:      false,
      error:        false,
    );
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final tripNotifierProvider =
    StateNotifierProvider<TripNotifier, TripData>((ref) => TripNotifier());

/// Convenience: just the active trip (null while loading or no trips).
final activeTripProvider =
    Provider<AppTrip?>((ref) => ref.watch(tripNotifierProvider).activeTrip);

/// Convenience: just the active trip's id (empty string while loading).
final activeTripIdProvider =
    Provider<String>((ref) => ref.watch(activeTripProvider)?.id ?? '');

/// Convenience: members of the active trip.
final tripMembersProvider =
    Provider<List<AppTripMember>>((ref) => ref.watch(tripNotifierProvider).members);

/// Convenience: all trips the user belongs to.
final allTripsProvider =
    Provider<List<AppTrip>>((ref) => ref.watch(tripNotifierProvider).trips);
