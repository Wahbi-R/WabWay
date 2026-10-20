// Mobile More and desktop Settings must offer the same settings rows — they
// drifted before (AI access, Pinboard, Emergency info and Transfer ownership
// were each missing from one of them). Both build from
// `screens/shared/settings_sections.dart`; this guards that.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wabway/core/auth/app_profile.dart';
import 'package:wabway/core/providers/profile_provider.dart';
import 'package:wabway/core/providers/trip_provider.dart';
import 'package:wabway/core/trip/app_trip.dart';
import 'package:wabway/core/trip/app_trip_member.dart';
import 'package:wabway/screens/more_screen.dart';
import 'package:wabway/screens/placeholder_screen.dart';

const _me = AppProfile(id: 'me', displayName: 'Wahbi Test', email: 'w@example.com');
const _trip = AppTrip(id: 't1', name: 'Japan', defaultCurrency: 'JPY', homeCurrency: 'CAD');

const _settingsRows = [
  'Edit name', 'Set / change password', 'AI access', 'Sign out',
  'Emergency info', 'Pinboard', 'Notifications',
  'Import file or link', "What's new", 'Diagnostics',
];
const _organiserRows = ['Edit trip details', 'Transfer ownership', 'Delete trip'];

Future<void> _pump(WidgetTester tester, Widget screen, {required bool organiser}) async {
  tester.view.physicalSize = const Size(1400, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      profileProvider.overrideWith((ref) => ProfileNotifier()..set(_me)),
      activeTripProvider.overrideWithValue(_trip),
      tripMembersProvider.overrideWithValue([
        AppTripMember(userId: 'me', role: organiser ? 'owner' : 'member', profile: _me),
      ]),
      isOrganiserProvider.overrideWithValue(organiser),
    ],
    child: MaterialApp(home: screen),
  ));
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final organiser in [true, false]) {
    final who = organiser ? 'organiser' : 'member';
    for (final entry in {'mobile More': const MoreScreen(), 'desktop Settings': const SettingsScreen()}.entries) {
      testWidgets('${entry.key} has every settings row ($who)', (tester) async {
        await _pump(tester, entry.value, organiser: organiser);
        for (final label in _settingsRows) {
          expect(find.text(label), findsOneWidget, reason: '${entry.key} is missing "$label"');
        }
        for (final label in _organiserRows) {
          expect(find.text(label), organiser ? findsOneWidget : findsNothing, reason: label);
        }
        expect(find.text('Leave trip'), organiser ? findsNothing : findsOneWidget);
      });
    }
  }

  for (final entry in {'mobile More': const MoreScreen(), 'desktop Settings': const SettingsScreen()}.entries) {
    testWidgets('${entry.key} opens Transfer ownership', (tester) async {
      await _pump(tester, entry.value, organiser: true);
      await tester.tap(find.text('Transfer ownership'));
      await tester.pumpAndSettle();
      expect(find.text('No other members to transfer to.'), findsOneWidget);
    });
  }
}
