import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline_cache.dart';
import '../trip/app_trip.dart';
import '../trip/app_trip_member.dart';
import '../supabase/trip_service.dart';
import '../sync_queue.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class TripData {
  const TripData({
    this.trips          = const [],
    this.members        = const [],
    this.selectedIndex  = 0,
    this.loading        = true,
    this.error          = false,
    this.offline        = false,
  });

  final List<AppTrip>       trips;
  final List<AppTripMember> members;
  final int                 selectedIndex;
  final bool                loading;
  final bool                error;
  /// True when trips/members were loaded from local cache (no network).
  final bool                offline;

  AppTrip? get activeTrip =>
      trips.isEmpty ? null : trips[selectedIndex];

  TripData copyWith({
    List<AppTrip>?       trips,
    List<AppTripMember>? members,
    int?                 selectedIndex,
    bool?                loading,
    bool?                error,
    bool?                offline,
  }) => TripData(
    trips:         trips         ?? this.trips,
    members:       members       ?? this.members,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    loading:       loading       ?? this.loading,
    error:         error         ?? this.error,
    offline:       offline       ?? this.offline,
  );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class TripNotifier extends StateNotifier<TripData> {
  TripNotifier() : super(const TripData());

  Future<void> load({bool silent = false}) async {
    if (!silent) state = state.copyWith(loading: true, error: false, offline: false);
    try {
      final trips = await TripService.loadUserTrips();
      if (trips.isEmpty) {
        state = state.copyWith(trips: [], members: [], loading: false, offline: false);
        return;
      }
      try {
        await OfflineCache.write(
          OfflineCache.userTripsKey,
          trips.map((t) => t.toMap()).toList(),
        );
      } catch (_) {}
      final idx     = state.selectedIndex.clamp(0, trips.length - 1);
      final members = await TripService.loadTripMembers(trips[idx].id);
      try {
        await OfflineCache.write(
          OfflineCache.membersKey(trips[idx].id),
          members.map((m) => m.toMap()).toList(),
        );
      } catch (_) {}
      // If switchTrip() completed while we were fetching members, don't revert it.
      if (state.selectedIndex != idx) {
        state = state.copyWith(trips: trips, loading: false, offline: false);
        return;
      }
      state = state.copyWith(
        trips:        trips,
        members:      members,
        selectedIndex: idx,
        loading:      false,
        offline:      false,
      );
    } catch (_) {
      if (silent) {
        state = state.copyWith(loading: false, offline: true);
        return;
      }
      List<AppTrip>? cachedTrips;
      try {
        cachedTrips = await OfflineCache.read<List<AppTrip>>(
          OfflineCache.userTripsKey,
          (json) => (json as List)
              .map((m) => AppTrip.fromMap(m as Map<String, dynamic>))
              .toList(),
        );
      } catch (_) {}
      if (cachedTrips != null && cachedTrips.isNotEmpty) {
        final idx = state.selectedIndex.clamp(0, cachedTrips.length - 1);
        List<AppTripMember> cachedMembers = const [];
        try {
          cachedMembers = await OfflineCache.read<List<AppTripMember>>(
            OfflineCache.membersKey(cachedTrips[idx].id),
            (json) => (json as List)
                .map((m) => AppTripMember.fromMap(m as Map<String, dynamic>))
                .toList(),
          ) ?? const [];
        } catch (_) {}
        state = state.copyWith(
          trips:         cachedTrips,
          members:       cachedMembers,
          selectedIndex: idx,
          loading:       false,
          error:         false,
          offline:       true,
        );
      } else {
        state = state.copyWith(loading: false, error: true);
      }
    }
  }

  /// Called when connectivity is restored. Reloads silently and drains queues.
  Future<void> onReconnect(String userId) async {
    await load(silent: true);
    final tripId = state.activeTrip?.id;
    if (tripId != null) await SyncQueue.drain(tripId, userId);
  }

  bool _switching = false;

  Future<void> switchTrip(AppTrip trip) async {
    if (_switching) return;
    final idx = state.trips.indexWhere((t) => t.id == trip.id);
    if (idx < 0 || idx == state.selectedIndex) return;
    _switching = true;
    state = state.copyWith(loading: true, error: false);
    try {
      final members = await TripService.loadTripMembers(trip.id);
      try {
        await OfflineCache.write(
          OfflineCache.membersKey(trip.id),
          members.map((m) => m.toMap()).toList(),
        );
      } catch (_) {}
      state = state.copyWith(
        selectedIndex: idx,
        members:       members,
        loading:       false,
        offline:       false,
        error:         false,
      );
    } catch (_) {
      List<AppTripMember>? cached;
      try {
        cached = await OfflineCache.read<List<AppTripMember>>(
          OfflineCache.membersKey(trip.id),
          (json) => (json as List)
              .map((e) => AppTripMember.fromMap(e as Map<String, dynamic>))
              .toList(),
        );
      } catch (_) {}
      if (cached != null) {
        state = state.copyWith(
          selectedIndex: idx,
          members:       cached,
          loading:       false,
          offline:       true,
        );
      } else {
        state = state.copyWith(selectedIndex: idx, members: const [], loading: false, offline: true);
      }
    } finally {
      _switching = false;
    }
  }

  Future<void> reloadMembers() async {
    if (state.trips.isEmpty) return;
    try {
      final members =
          await TripService.loadTripMembers(state.trips[state.selectedIndex].id);
      state = state.copyWith(members: members, offline: false);
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
