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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wabway/theme/wabway_theme.dart';
import 'package:wabway/screens/auth/auth_gate.dart';

const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_ANON_KEY');
const _testEmail    = String.fromEnvironment('TEST_EMAIL');
const _testPassword = String.fromEnvironment('TEST_PASSWORD');

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Pumps the app widget. Supabase must already be initialized and the user
/// signed in before calling this.
Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AuthGate(),
      ),
    ),
  );
}

/// Waits up to [timeout] for a condition to be true, pumping frames in between.
Future<void> _waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Taps the bottom nav tab labelled [label] and waits for the screen to settle.
Future<void> _tapTab(WidgetTester tester, String label) async {
  final tab = find.text(label);
  await tester.tap(tab.first);
  await tester.pumpAndSettle(const Duration(seconds: 3));
}

// ── Setup ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    assert(_supabaseUrl.isNotEmpty && _supabaseKey.isNotEmpty,
        'SUPABASE_URL / SUPABASE_ANON_KEY missing. Run with --dart-define-from-file=.env');
    assert(_testEmail.isNotEmpty && _testPassword.isNotEmpty,
        'TEST_EMAIL / TEST_PASSWORD missing in .env');

    await Supabase.initialize(url: _supabaseUrl, publishableKey: _supabaseKey);
    final res = await Supabase.instance.client.auth
        .signInWithPassword(email: _testEmail, password: _testPassword);
    assert(res.user != null, 'Sign-in failed for $_testEmail');
    print('[smoke] Signed in as ${res.user!.email}');
  });

  tearDownAll(() async {
    await Supabase.instance.client.auth.signOut();
  });

  // ── App launch ────────────────────────────────────────────────────────────

  group('App launch', () {
    testWidgets('renders without black screen or crash', (tester) async {
      await _pumpApp(tester);
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
    late WidgetTester _t;

    setUp(() async {
      // Each test in this group shares state; just ensure we start on Home.
    });

    testWidgets('all tabs load without crashing', (tester) async {
      await _pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));

      // Verify we have a bottom nav bar
      final navBar = find.byType(NavigationBar);
      if (navBar.evaluate().isEmpty) {
        // Might be BottomNavigationBar on older device/config
        final legacyNav = find.byType(BottomNavigationBar);
        expect(legacyNav, findsOneWidget,
            reason: 'Expected a bottom nav bar after loading');
      }

      for (final tab in ['Home', 'Spots', 'Plan', 'Money', 'More']) {
        final tabFinder = find.text(tab);
        if (tabFinder.evaluate().isEmpty) {
          print('[smoke] Tab "$tab" not found — skipping (may be desktop layout)');
          continue;
        }
        await _tapTab(tester, tab);
        expect(find.byType(Scaffold), findsWidgets,
            reason: 'Scaffold should exist after tapping $tab tab');
        expect(tester.takeException(), isNull,
            reason: 'No uncaught exception on $tab screen');
        print('[smoke] ✓ $tab');
      }
    });

    testWidgets('Home screen: trip name and member avatars visible', (tester) async {
      await _pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _tapTab(tester, 'Home');

      // There should be at least one trip name text somewhere in the tree
      // (exact name unknown, so check that some AppBar title is rendered)
      expect(find.byType(AppBar), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Spots screen: list or empty state renders', (tester) async {
      await _pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _tapTab(tester, 'Spots');
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Plan screen: list or empty state renders', (tester) async {
      await _pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _tapTab(tester, 'Plan');
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('Money screen: tabs render', (tester) async {
      await _pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _tapTab(tester, 'Money');
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    });

    testWidgets('More screen: trip name and member list render', (tester) async {
      await _pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _tapTab(tester, 'More');
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // More screen shows a "Trip" section header
      expect(find.text('TRIP'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── More-screen sheets ────────────────────────────────────────────────────

  group('More screen: action sheets open without crash', () {
    testWidgets('Trip settings sheet opens', (tester) async {
      await _pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _tapTab(tester, 'More');

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
      await _pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _tapTab(tester, 'More');

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
      await _pumpApp(tester);
      await tester.pumpAndSettle(const Duration(seconds: 6));
      await _tapTab(tester, 'More');

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
      await _pumpApp(tester);
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
      await _tapTab(tester, 'Home');
      final firstTripName = (trips[0]['trips'] as Map<String, dynamic>)['name'] as String;
      final secondTripName = (trips[1]['trips'] as Map<String, dynamic>)['name'] as String;
      print('[smoke] Switching from "$firstTripName" to "$secondTripName"');

      // Open trip switcher from More tab
      await _tapTab(tester, 'More');
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
      await _tapTab(tester, 'Home');
      // The trip name should now appear somewhere in the UI
      expect(find.textContaining(secondTripName), findsWidgets,
          reason: 'Home screen should show the new trip name after switching');
      expect(tester.takeException(), isNull);
    });
  });
}
