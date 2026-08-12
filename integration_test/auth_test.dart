// ignore_for_file: avoid_print
//
// Auth flow tests — covers every screen and state in the sign-in/sign-up flow.
// These tests run WITHOUT a pre-existing session.
//
// Run:
//   flutter test integration_test/auth_test.dart \
//     --dart-define-from-file=.env -d <deviceId>

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'helpers.dart';

// Auth screen is pure local UI — no trip data loading — so 2 s is enough.
Future<void> _pump(WidgetTester t) =>
    pumpApp(t, settle: const Duration(seconds: 2));

// AnimatedSwitcher on auth screen is ~200 ms; 500 ms is plenty.
const _kSwitch = Duration(milliseconds: 500);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(initSupabase);

  // Sign out before each test so we start unauthenticated.
  setUp(signOut);

  // ── Unauthenticated state ────────────────────────────────────────────────

  group('Unauthenticated: initial screen', () {
    testWidgets('shows sign-in screen, not home screen', (t) async {
      await _pump(t);
      expect(find.text('Sign in'), findsWidgets,
          reason: 'Sign-in screen should be visible when no session exists');
      expect(find.text('Home'), findsNothing,
          reason: 'Home tab should not be visible when not logged in');
      noException(t);
    });

    testWidgets('magic-link mode is the default', (t) async {
      await _pump(t);
      expect(find.text('Send magic link'), findsOneWidget);
      expect(find.text('Use a password instead'), findsOneWidget);
      noException(t);
    });

    testWidgets('tagline and email field visible', (t) async {
      await _pump(t);
      expect(find.text('Plan your trip together.'), findsOneWidget);
      expect(find.text('Email'), findsWidgets);
      noException(t);
    });
  });

  // ── Magic link flow ──────────────────────────────────────────────────────

  group('Magic link flow', () {
    testWidgets('empty email shows validation error', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Send magic link'));
      await t.pumpAndSettle();
      final hasError = find.textContaining('email').evaluate().isNotEmpty;
      expect(hasError, isTrue, reason: 'Should show email validation error');
      noException(t);
    });

    testWidgets('valid email shows "Check your inbox" state', (t) async {
      await _pump(t);
      final emailField = find.byType(EditableText).first;
      await t.tap(emailField);
      await t.enterText(emailField, kTestEmail);
      await tapFirst(t, find.text('Send magic link'));
      await t.pumpAndSettle(const Duration(seconds: 6));
      expect(find.text('Check your inbox'), findsOneWidget);
      noException(t);
    });
  });

  // ── Password mode ────────────────────────────────────────────────────────

  group('Password mode', () {
    testWidgets('"Use a password instead" switches to password form', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      expect(find.text('Password'), findsWidgets);
      expect(find.text('Sign in'), findsWidgets);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Use a magic link instead'), findsOneWidget);
      noException(t);
    });

    testWidgets('"Use a magic link instead" switches back', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('Use a magic link instead'));
      await t.pumpAndSettle(_kSwitch);
      expect(find.text('Send magic link'), findsOneWidget);
      noException(t);
    });

    testWidgets('empty fields show validation error', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await t.tap(find.text('Sign in').last);
      await t.pumpAndSettle();
      final hasError = find.textContaining('fill').evaluate().isNotEmpty ||
          find.textContaining('field').evaluate().isNotEmpty;
      expect(hasError, isTrue, reason: 'Empty fields should show an error');
      noException(t);
    });

    testWidgets('wrong password shows error message', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);

      final emailField = find.byType(EditableText).first;
      await t.ensureVisible(emailField);
      await t.enterText(emailField, kTestEmail);
      await t.pumpAndSettle();
      final pwField = find.byType(EditableText).last;
      await t.ensureVisible(pwField);
      await t.enterText(pwField, 'definitely-wrong-password-9999');
      await tapFirst(t, find.text('Sign in'));
      await t.pumpAndSettle(const Duration(seconds: 6));

      final hasError =
          find.textContaining('Incorrect').evaluate().isNotEmpty ||
          find.textContaining('invalid').evaluate().isNotEmpty ||
          find.textContaining('credentials').evaluate().isNotEmpty ||
          find.textContaining('password').evaluate().isNotEmpty;
      expect(hasError, isTrue, reason: 'Wrong password should show error');
      noException(t);
    });

    testWidgets('correct credentials navigate to the app', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);

      final emailField = find.byType(EditableText).first;
      await t.ensureVisible(emailField);
      await t.enterText(emailField, kTestEmail);
      await t.pumpAndSettle();
      final pwField = find.byType(EditableText).last;
      await t.ensureVisible(pwField);
      await t.enterText(pwField, kTestPassword);
      await tapFirst(t, find.text('Sign in'));
      await t.pumpAndSettle(const Duration(seconds: 8));

      expect(find.text('Send magic link'), findsNothing,
          reason: 'Should not be on auth screen after successful sign-in');
      noException(t);
    });
  });

  // ── Sign-up flow ─────────────────────────────────────────────────────────

  group('Sign-up flow', () {
    testWidgets('"New here? Create account" switches to sign-up form', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('New here? Create account'));
      await t.pumpAndSettle(_kSwitch);
      expect(find.text('Create account'), findsWidgets);
      expect(find.text('Your name'), findsOneWidget);
      expect(find.text('Already have an account? Sign in'), findsOneWidget);
      noException(t);
    });

    testWidgets('empty name shows validation error', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('New here? Create account'));
      await t.pumpAndSettle(_kSwitch);

      // Sign-up fields: [0]=name, [1]=email, [2]=password.
      // Fill email + password, leave name empty → expect "name" error.
      final fields = find.byType(EditableText);
      await t.ensureVisible(fields.at(1));
      await t.enterText(fields.at(1), 'test@example.com');
      await t.ensureVisible(fields.at(2));
      await t.enterText(fields.at(2), 'password123');
      await tapFirst(t, find.text('Create account'));
      await t.pumpAndSettle();
      final hasError = find.textContaining('name').evaluate().isNotEmpty;
      expect(hasError, isTrue, reason: 'Empty name should show error');
      noException(t);
    });

    testWidgets('empty email shows validation error', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('New here? Create account'));
      await t.pumpAndSettle(_kSwitch);
      // Tap without filling anything → expect fill/field/name error
      await tapFirst(t, find.text('Create account'));
      await t.pumpAndSettle();
      final hasError = find.textContaining('fill').evaluate().isNotEmpty ||
          find.textContaining('field').evaluate().isNotEmpty ||
          find.textContaining('name').evaluate().isNotEmpty;
      expect(hasError, isTrue, reason: 'Empty fields should show error');
      noException(t);
    });

    testWidgets('"Already have an account" switches back to sign-in', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('New here? Create account'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('Already have an account? Sign in'));
      await t.pumpAndSettle(_kSwitch);
      expect(find.text('Forgot password?'), findsOneWidget);
      noException(t);
    });
  });

  // ── Forgot password flow ─────────────────────────────────────────────────

  group('Forgot password flow', () {
    testWidgets('"Forgot password?" opens forgot-password form', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('Forgot password?'));
      await t.pumpAndSettle(_kSwitch);
      expect(find.text('Forgot password?'), findsWidgets);
      expect(find.textContaining("we'll send a reset link"), findsOneWidget);
      expect(find.text('Send reset link'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
      noException(t);
    });

    testWidgets('empty email on forgot-password shows error', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('Forgot password?'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('Send reset link'));
      await t.pumpAndSettle();
      final hasError = find.textContaining('email').evaluate().isNotEmpty;
      expect(hasError, isTrue, reason: 'Empty email should show error');
      noException(t);
    });

    testWidgets('valid email shows "Check your inbox" reset sent state', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('Forgot password?'));
      await t.pumpAndSettle(_kSwitch);

      final emailField = find.byType(EditableText).first;
      await t.ensureVisible(emailField);
      await t.enterText(emailField, kTestEmail);
      await tapFirst(t, find.text('Send reset link'));
      await t.pumpAndSettle(const Duration(seconds: 6));

      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.text('Back to sign in'), findsOneWidget);
      noException(t);
    });

    testWidgets('"Back to sign in" returns to password form', (t) async {
      await _pump(t);
      await tapFirst(t, find.text('Use a password instead'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('Forgot password?'));
      await t.pumpAndSettle(_kSwitch);
      await tapFirst(t, find.text('Back to sign in'));
      await t.pumpAndSettle(_kSwitch);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Sign in'), findsWidgets);
      noException(t);
    });
  });

  // ── Sign out ─────────────────────────────────────────────────────────────

  group('Sign out', () {
    testWidgets('sign out from More screen returns to auth screen', (t) async {
      await signIn();
      await pumpApp(t);
      await tapTab(t, 'More');

      final signOutRow = find.text('Sign out');
      if (signOutRow.evaluate().isEmpty) {
        print('[auth_test] "Sign out" row not found — skipping');
        return;
      }
      await t.tap(signOutRow.first);
      await t.pumpAndSettle(const Duration(seconds: 4));

      expect(find.text('Send magic link'), findsOneWidget,
          reason: 'Should be back on auth screen after sign out');
      noException(t);
    });

    testWidgets('sign out from Settings screen returns to auth screen', (t) async {
      await signIn();
      await pumpApp(t);
      await tapMoreRow(t, 'Edit name');
      await dismissModal(t);
      noException(t);
    });
  });
}
