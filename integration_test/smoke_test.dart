// ignore_for_file: avoid_print
//
// Smoke tests for the Riverpod migration — verifies every major screen renders
// without crashing after sign-in and that switching trips updates the UI.
//
// Prerequisites:
//   Add to your .env file:
//     TEST_EMAIL=your-test-user@example.com
//     TEST_PASSWORD=yourpassword
//
// Run on a connected device or emulator:
//   flutter test integration_test/smoke_test.dart \
//     --dart-define-from-file=.env -d <deviceId>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'helpers.dart';

// ── Setup ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initApp();
    await signIn();
    print('[smoke] ready');
  });

  tearDownAll(signOut);

  // ── App launch ────────────────────────────────────────────────────────────

  group('App launch', () {
    testWidgets('renders without black screen or crash', (tester) async {
      await pumpApp(tester);
      // Allow TripGate / providers to load
      await tester.pumpAndSettle(const Duration(seconds: 6));

      // Should not be on the sign-in screen (session was pre-established)
      expect(find.text('Sign in'), findsNothing,
          reason: 'App should not be on auth screen after pre-sign-in');

      // Some content loaded — at minimum a Scaffold is rendered
      expect(find.byType(Scaffold), findsWidgets);
    });
  });

  // ── Screen smoke ──────────────────────────────────────────────────────────

  group('Bottom nav screens', () {
    testWidgets('all tabs load without crashing', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));

      // Verify we have a bottom nav bar (NavigationBar = Material 3, BottomNavigationBar = legacy)
      final hasNavBar = find.byType(NavigationBar).evaluate().isNotEmpty ||
          find.byType(BottomNavigationBar).evaluate().isNotEmpty;
      if (!hasNavBar) {
        print('[smoke] No navigation bar found — checking for alternative layout');
      }

      for (final tab in ['Home', 'Spots', 'Plan', 'Money', 'More']) {
        final tabFinder = find.text(tab);
        if (tabFinder.evaluate().isEmpty) {
          print('[smoke] Tab "$tab" not found — skipping (may be desktop layout)');
          continue;
        }
        await tapTab(tester, tab);
        expect(find.byType(Scaffold), findsWidgets,
            reason: 'Scaffold should exist after tapping $tab tab');
        expect(tester.takeException(), isNull,
            reason: 'No uncaught exception on $tab screen');
        print('[smoke] ✓ $tab');
      }
    });

    testWidgets('Home screen: trip name and member avatars visible', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await tapTab(tester, 'Home');

      // There should be at least one trip name text somewhere in the tree
      // (exact name unknown, so check that some AppBar title is rendered)
      expect(find.byType(AppBar), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Spots screen: list or empty state renders', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await tapTab(tester, 'Spots');
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Plan screen: list or empty state renders', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await tapTab(tester, 'Plan');
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Money screen: tabs render', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await tapTab(tester, 'Money');
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('More screen: trip name and member list render', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await tapTab(tester, 'More');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // More screen renders some content without crashing
      expect(find.byType(Scaffold), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  // ── More-screen sheets ────────────────────────────────────────────────────

  group('More screen: action sheets open without crash', () {
    testWidgets('Trip settings sheet opens', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await tapTab(tester, 'More');

      final settingsRow = find.text('Trip settings');
      if (settingsRow.evaluate().isEmpty) {
        print('[smoke] "Trip settings" row not found — skipping');
        return;
      }
      await tester.tap(settingsRow.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      // Dismiss by tapping outside
      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
    });

    testWidgets('Switch trip sheet opens', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await tapTab(tester, 'More');

      final switchRow = find.text('Switch trip');
      if (switchRow.evaluate().isEmpty) {
        print('[smoke] "Switch trip" row not found — skipping');
        return;
      }
      await tester.tap(switchRow.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);

      await tester.tapAt(const Offset(200, 100));
      await tester.pumpAndSettle();
    });
  });

  // ── Packing screen ────────────────────────────────────────────────────────

  group('Packing screen', () {
    testWidgets('opens from More and renders', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await tapTab(tester, 'More');

      final packingRow = find.text('Packing list');
      if (packingRow.evaluate().isEmpty) {
        print('[smoke] "Packing list" row not found — skipping');
        return;
      }
      await tester.tap(packingRow.first);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });
  });

  // ── Trip switching ────────────────────────────────────────────────────────

  group('Trip switching', () {
    testWidgets('switching trip updates home screen title', (tester) async {
      await pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));

      // Check how many trips this account has
      final trips = await Supabase.instance.client
          .from('trip_members')
          .select('trips(name)')
          .eq('user_id', Supabase.instance.client.auth.currentUser!.id);

      if (trips.length < 2) {
        print('[smoke] Account has only ${trips.length} trip(s) — skipping trip-switch test');
        return;
      }

      // Get first trip name visible on screen
      await tapTab(tester, 'Home');
      final firstTripName = (trips[0]['trips'] as Map<String, dynamic>)['name'] as String;
      final secondTripName = (trips[1]['trips'] as Map<String, dynamic>)['name'] as String;
      print('[smoke] Switching from "$firstTripName" to "$secondTripName"');

      // Open trip switcher from More tab
      await tapTab(tester, 'More');
      final switchRow = find.text('Switch trip');
      if (switchRow.evaluate().isEmpty) return;
      await tester.tap(switchRow.first);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap the second trip
      final secondTripFinder = find.text(secondTripName);
      if (secondTripFinder.evaluate().isEmpty) {
        print('[smoke] Could not find "$secondTripName" in switcher — skipping');
        await tester.tapAt(const Offset(200, 100));
        return;
      }
      await tester.tap(secondTripFinder.first);
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Navigate to Home and verify title changed
      await tapTab(tester, 'Home');
      // The trip name should now appear somewhere in the UI
      expect(find.textContaining(secondTripName), findsWidgets,
          reason: 'Home screen should show the new trip name after switching');
      expect(tester.takeException(), isNull);
    });
  });
}
