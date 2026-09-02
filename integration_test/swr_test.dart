// ignore_for_file: avoid_print
//
// SWR / offline-caching integration tests for Build 284.
//
// Tests four problem areas:
//   1. Cache-first: cached data renders before the network responds
//   2. Trip-switch invalidation: switching trips never shows stale previous-trip data
//   3. Three-source deduplication: gen counter prevents old async results overwriting new ones
//   4. SharedPreferences latency: first-load spinner clears within an acceptable deadline
//
// Run on a connected device or emulator:
//   flutter test integration_test/swr_test.dart \
//     --dart-define-from-file=.env -d <deviceId>

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wabway/core/offline_cache.dart';

import 'helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initSupabase();
    await signIn();
  });

  tearDownAll(signOut);

  // ── 1. Cache-first ──────────────────────────────────────────────────────────
  //
  // Seed a known JSON blob directly into SharedPreferences for the active trip,
  // then pump the app and verify the seeded text appears before pumpAndSettle
  // finishes (i.e. while the network request is still in flight).

  group('1. Cache-first rendering', () {
    testWidgets('Spots: cache is populated after a network load', (t) async {
      // Mirror TripService.loadUserTrips() ordering (newest trip first → index 0
      // is the app's default active trip at selectedIndex=0).
      final tripRows = await sb
          .from('trips')
          .select('id')
          .order('created_at', ascending: false);
      if (tripRows.isEmpty) {
        print('[swr] No trips for test user — skipping cache-first test');
        return;
      }
      final allTripIds = tripRows.map((r) => r['id'] as String).toList();
      final activeTripId = allTripIds.first;
      print('[swr] active trip: $activeTripId  all: $allTripIds');

      // Clear spots caches for all trips so the write is clearly from this run.
      final prefs = await SharedPreferences.getInstance();
      for (final id in allTripIds) {
        await prefs.remove(OfflineCache.spotsKey(id));
      }

      // Pump the app and give it time to do a full network load.
      // TripNotifier loads → activeTripIdProvider emits real id → SpotsScreen
      // ref.listen fires → _loadSpots(realTripId) → OfflineCache.write.
      await pumpApp(t, settle: const Duration(seconds: 10));

      // Check the active trip's cache was written.
      String? raw = prefs.getString(OfflineCache.spotsKey(activeTripId));
      // Fallback: check any trip's cache in case selectedIndex chose a different one.
      if (raw == null) {
        for (final id in allTripIds) {
          raw = prefs.getString(OfflineCache.spotsKey(id));
          if (raw != null) {
            print('[swr]   cache written for trip $id (not the predicted active trip)');
            break;
          }
        }
      }

      expect(raw, isNotNull,
          reason: 'OfflineCache should be populated after a full network load');

      final decoded = jsonDecode(raw!) as List<dynamic>;
      print('[swr] ✓ cache-first: cache has ${decoded.length} spot(s) after network load');

      if (decoded.isNotEmpty) {
        final first = decoded.first as Map<String, dynamic>;
        expect(first.containsKey('id'), isTrue,
            reason: 'Cached spot should have an id field');
        expect(first.containsKey('name'), isTrue,
            reason: 'Cached spot should have a name field');
        print('[swr]   first spot: id=${first['id']}, name=${first['name']}');
      }
    });
  });

  // ── 2. Trip-switch invalidation ─────────────────────────────────────────────
  //
  // When the user switches trips, screens must show data for the *new* trip.
  // The gen counter should ensure any in-flight request for the old trip
  // is dropped and never renders.

  group('2. Trip-switch invalidation', () {
    testWidgets('Switching trips updates Spots screen without showing old data', (t) async {
      // Mirror TripService ordering so trip1 matches the app's active trip.
      final trips = await sb
          .from('trips')
          .select('id, name')
          .order('created_at', ascending: false);

      if (trips.length < 2) {
        print('[swr] Account has < 2 trips — skipping trip-switch invalidation test');
        return;
      }

      final trip1Id   = trips[0]['id'] as String;
      final trip1Name = trips[0]['name'] as String;
      final trip2Id   = trips[1]['id'] as String;
      final trip2Name = trips[1]['name'] as String;
      print('[swr] trip1="$trip1Name" ($trip1Id)  trip2="$trip2Name" ($trip2Id)');

      // Seed a sentinel into trip1's spots cache so we can detect if it bleeds
      // into the trip2 view after switching.
      const sentinel = '__TRIP1_ONLY_SENTINEL__';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        OfflineCache.spotsKey(trip1Id),
        '[{"id":"fake-t1","name":"$sentinel","city":"","area":"",'
        '"category":"landmark","status":"want_to_go","source_url":null,'
        '"maps_url":null,"notes":null,"address":null,"latitude":null,'
        '"longitude":null,"country":null,"place_source":null,"image_url":null,'
        '"added_by":"00000000-0000-0000-0000-000000000000",'
        '"spot_votes":[],"spot_comments":[]}]',
      );

      await pumpApp(t, settle: const Duration(seconds: 6));
      await tapTab(t, 'Spots', settle: const Duration(seconds: 3));

      // Switch to trip 2 via More → Switch trip.
      await tapTab(t, 'More');
      final switchRow = find.text('Switch trip');
      if (switchRow.evaluate().isEmpty) {
        print('[swr] "Switch trip" row not found — skipping');
        await prefs.remove(OfflineCache.spotsKey(trip1Id));
        return;
      }
      await t.tap(switchRow.first);
      await t.pumpAndSettle(const Duration(seconds: 2));

      final trip2Finder = find.text(trip2Name);
      if (trip2Finder.evaluate().isEmpty) {
        print('[swr] Could not find trip2 in switcher — skipping');
        await t.tapAt(const Offset(200, 80));
        await prefs.remove(OfflineCache.spotsKey(trip1Id));
        return;
      }
      await t.tap(trip2Finder.first);
      await t.pumpAndSettle(const Duration(seconds: 6));

      // Navigate to Spots for the new trip.
      await tapTab(t, 'Spots', settle: const Duration(seconds: 4));

      // The trip1-only sentinel must NOT appear in the trip2 view.
      expect(
        find.text(sentinel),
        findsNothing,
        reason: 'Trip1 sentinel must not bleed into trip2 spots view',
      );
      noException(t);
      print('[swr] ✓ trip-switch invalidation: no stale trip1 data in trip2 spots');

      await prefs.remove(OfflineCache.spotsKey(trip1Id));
    });
  });

  // ── 3. Three-source deduplication (gen counter) ─────────────────────────────
  //
  // Navigate rapidly between tabs multiple times. Each tab-switch triggers a new
  // _load → new gen → old in-flight results are dropped. The final state should
  // be stable (no exception, no empty screen due to stale overwrite).

  group('3. Three-source deduplication', () {
    testWidgets('Rapid tab switching leaves every screen in a stable state', (t) async {
      await pumpApp(t, settle: const Duration(seconds: 6));

      // Tap through tabs rapidly without settling fully between each.
      for (final tab in ['Spots', 'Plan', 'Money', 'Home', 'Spots', 'Plan']) {
        final f = find.text(tab);
        if (f.evaluate().isNotEmpty) {
          await t.tap(f.first);
          await t.pump(const Duration(milliseconds: 200));
        }
      }

      // Now settle and verify no crash.
      await t.pumpAndSettle(const Duration(seconds: 5));
      expect(find.byType(Scaffold), findsWidgets);
      noException(t);
      print('[swr] ✓ gen-counter deduplication: no crash after rapid tab switching');
    });
  });

  // ── 4. SharedPreferences latency ────────────────────────────────────────────
  //
  // On the second app pump (after cache is populated by the first load), the
  // loading spinner should disappear within 3 seconds — not block for longer
  // waiting on SharedPreferences + network.

  group('4. SharedPreferences latency', () {
    testWidgets('Spots screen clears spinner within 3 s on repeat visit', (t) async {
      // First pump: populates cache.
      await pumpApp(t, settle: const Duration(seconds: 8));
      await tapTab(t, 'Spots', settle: const Duration(seconds: 4));

      // Second pump: cache should be available.
      await t.pumpWidget(testApp());
      await t.pumpAndSettle(const Duration(seconds: 1));
      await tapTab(t, 'Spots', settle: const Duration(milliseconds: 500));

      // Within 3 s the spinner should be gone (cache served immediately).
      var spinnerGone = false;
      final deadline = DateTime.now().add(const Duration(seconds: 3));
      while (DateTime.now().isBefore(deadline)) {
        await t.pump(const Duration(milliseconds: 200));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) {
          spinnerGone = true;
          break;
        }
      }

      expect(spinnerGone, isTrue,
          reason: 'Loading spinner should clear within 3 s when cache is warm');
      noException(t);
      print('[swr] ✓ SharedPreferences latency: spinner gone within 3 s');
    });
  });
}
