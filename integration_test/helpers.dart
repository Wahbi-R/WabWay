// Shared utilities for WabWay integration tests.
// ignore_for_file: avoid_print
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wabway/screens/auth/auth_gate.dart';

// ── Dart-define constants ────────────────────────────────────────────────────
const kSupabaseUrl  = String.fromEnvironment('SUPABASE_URL');
const kSupabaseKey  = String.fromEnvironment('SUPABASE_ANON_KEY');
const kTestEmail    = String.fromEnvironment('TEST_EMAIL');
const kTestPassword = String.fromEnvironment('TEST_PASSWORD');
const kTestEmail2   = String.fromEnvironment('TEST_EMAIL_2');
const kTestPassword2 = String.fromEnvironment('TEST_PASSWORD_2');

// ── App widget ───────────────────────────────────────────────────────────────

/// The full app widget. Supabase must be initialized before pumping this.
Widget testApp() => const ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AuthGate(),
      ),
    );

// ── Supabase ─────────────────────────────────────────────────────────────────

/// Full app initialization matching main.dart: Firebase + Supabase.
/// Safe to call multiple times — both are idempotent.
Future<void> initApp() async {
  assert(kSupabaseUrl.isNotEmpty && kSupabaseKey.isNotEmpty,
      'SUPABASE_URL / SUPABASE_ANON_KEY missing — run with --dart-define-from-file=.env');
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') rethrow;
    }
  }
  await Supabase.initialize(url: kSupabaseUrl, publishableKey: kSupabaseKey);
}

/// Alias kept for back-compat with older test files.
Future<void> initSupabase() => initApp();

SupabaseClient get sb => Supabase.instance.client;

Future<void> signIn({String? email, String? password}) async {
  final e = email ?? kTestEmail;
  final p = password ?? kTestPassword;
  assert(e.isNotEmpty && p.isNotEmpty, 'TEST_EMAIL / TEST_PASSWORD missing in .env');
  final res = await sb.auth.signInWithPassword(email: e, password: p);
  assert(res.user != null, 'Sign-in failed for $e');
  print('[test] signed in as $e (${res.user!.id})');
}

Future<void> signOut() async {
  try { await sb.auth.signOut(); } catch (_) {}
}

// ── Widget helpers ───────────────────────────────────────────────────────────

/// Pumps the app and waits for initial load (auth + providers).
/// Also dismisses the onboarding dialog if it appears (first install on a fresh emulator).
Future<void> pumpApp(WidgetTester t, {Duration settle = const Duration(seconds: 6)}) async {
  await t.pumpWidget(testApp());
  await t.pumpAndSettle(settle);
  await dismissOnboarding(t);
}

/// Taps the Skip button on the onboarding wizard if it is visible.
Future<void> dismissOnboarding(WidgetTester t) async {
  final skip = find.text('Skip');
  if (skip.evaluate().isNotEmpty) {
    print('[test] onboarding visible — tapping Skip');
    await t.tap(skip.first, warnIfMissed: false);
    await t.pumpAndSettle(const Duration(seconds: 2));
  }
}

/// Taps the bottom nav tab with [label] and waits to settle.
Future<void> tapTab(WidgetTester t, String label, {Duration settle = const Duration(seconds: 3)}) async {
  final f = find.text(label);
  if (f.evaluate().isEmpty) {
    print('[test] tab "$label" not found — skipping');
    return;
  }
  await t.tap(f.first, warnIfMissed: false);
  await t.pumpAndSettle(settle);
}

/// Taps the first widget found by [finder] and settles.
/// Scrolls the widget into view first so off-screen or partially-covered
/// widgets (e.g. those below the soft keyboard) are reliably tappable.
Future<void> tapFirst(WidgetTester t, Finder finder, {Duration settle = const Duration(seconds: 2)}) async {
  final target = finder.first;
  try {
    await t.ensureVisible(target);
    await t.pumpAndSettle();
  } catch (_) {
    // ensureVisible throws if the widget is not in a Scrollable; ignore.
  }
  await t.tap(target);
  await t.pumpAndSettle(settle);
}

/// Dismiss a modal/sheet by tapping at the top of the screen.
Future<void> dismissModal(WidgetTester t) async {
  await t.tapAt(const Offset(200, 60));
  await t.pumpAndSettle(const Duration(seconds: 1));
}

/// Taps a More-tab row by [rowLabel] and waits to settle.
Future<void> tapMoreRow(WidgetTester t, String rowLabel) async {
  await tapTab(t, 'More');
  final row = find.text(rowLabel);
  if (row.evaluate().isEmpty) {
    print('[test] More row "$rowLabel" not found — skipping');
    return;
  }
  await t.tap(row.first);
  await t.pumpAndSettle(const Duration(seconds: 3));
}

/// Waits up to [timeout] for [condition] to be true, pumping frames.
Future<void> waitFor(
  WidgetTester t,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('Condition not met within $timeout');
    }
    await t.pump(const Duration(milliseconds: 300));
  }
}

/// Asserts no uncaught exception was thrown in the current frame.
void noException(WidgetTester t) {
  expect(t.takeException(), isNull, reason: 'Unexpected exception on screen');
}
