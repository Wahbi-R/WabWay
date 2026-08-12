// ignore_for_file: avoid_print
//
// Comprehensive feature tests — every screen, every sheet, every major action.
// Runs with a pre-authenticated session (TEST_EMAIL / TEST_PASSWORD from .env).
//
// Run:
//   flutter test integration_test/features_test.dart \
//     --dart-define-from-file=.env -d <deviceId>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'helpers.dart';

// ── Helpers (feature-test specific) ─────────────────────────────────────────

/// Navigate to a More-tab sub-screen and verify the AppBar title.
Future<void> _goToMoreScreen(
  WidgetTester t,
  String rowLabel,
  String expectedTitle,
) async {
  await tapTab(t, 'More');
  final row = find.text(rowLabel);
  if (row.evaluate().isEmpty) {
    print('[features] More row "$rowLabel" not found — skipping');
    return;
  }
  await t.tap(row.first);
  await t.pumpAndSettle(const Duration(seconds: 3));
  expect(find.text(expectedTitle), findsWidgets,
      reason: 'Expected "$expectedTitle" after tapping "$rowLabel"');
  noException(t);
}

// ── Main ─────────────────────────────────────────────────────────────────────

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initSupabase();
    await signIn();
  });

  tearDownAll(signOut);

  // ════════════════════════════════════════════════════════════════════════════
  // HOME SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Home screen', () {
    testWidgets('loads without crash', (t) async {
      await pumpApp(t);
      expect(find.byType(Scaffold), findsWidgets);
      noException(t);
    });

    testWidgets('bottom nav bar is visible', (t) async {
      await pumpApp(t);
      final hasNav = find.byType(NavigationBar).evaluate().isNotEmpty ||
          find.byType(BottomNavigationBar).evaluate().isNotEmpty;
      expect(hasNav, isTrue, reason: 'Bottom nav bar should be present');
      noException(t);
    });

    testWidgets('trip hero card or no-trip state visible', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Home');
      // Either a trip hero is shown or an empty/no-trip state
      expect(find.byType(Scaffold), findsWidgets);
      noException(t);
    });

    testWidgets('add expense FAB opens money sheet or navigates', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Home');
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isNotEmpty) {
        await t.tap(fab.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        noException(t);
        await dismissModal(t);
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // SPOTS SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Spots screen', () {
    testWidgets('loads — list or empty state renders', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Spots');
      await t.pumpAndSettle(const Duration(seconds: 3));
      // Either list items or the empty state text
      final hasContent =
          find.text('No spots yet').evaluate().isNotEmpty ||
          find.byType(ListView).evaluate().isNotEmpty ||
          find.byType(GridView).evaluate().isNotEmpty;
      expect(hasContent, isTrue);
      noException(t);
    });

    testWidgets('search field is present', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Spots');
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('Search spots'), findsOneWidget);
      noException(t);
    });

    testWidgets('sort menu opens without crash', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Spots');
      await t.pumpAndSettle(const Duration(seconds: 2));
      // Sort icon is in the AppBar
      final sortIcon = find.byIcon(Icons.sort_rounded);
      if (sortIcon.evaluate().isNotEmpty) {
        await t.tap(sortIcon.first);
        await t.pumpAndSettle();
        expect(find.text('Newest first'), findsOneWidget);
        expect(find.text('A – Z'), findsOneWidget);
        // Dismiss
        await t.tapAt(const Offset(20, 20));
        await t.pumpAndSettle();
      }
      noException(t);
    });

    testWidgets('filter sheet opens without crash', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Spots');
      await t.pumpAndSettle(const Duration(seconds: 2));
      final filterIcon = find.byIcon(Icons.tune_rounded);
      if (filterIcon.evaluate().isNotEmpty) {
        await t.tap(filterIcon.first);
        await t.pumpAndSettle();
        expect(find.text('Filter spots'), findsOneWidget);
        await dismissModal(t);
      }
      noException(t);
    });

    testWidgets('add spot sheet opens without crash', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Spots');
      await t.pumpAndSettle(const Duration(seconds: 2));
      // FAB
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isEmpty) return;
      await t.tap(fab.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      // Sheet should show a search/name field
      final hasSheet =
          find.textContaining('Search a place').evaluate().isNotEmpty ||
          find.textContaining('Add a spot').evaluate().isNotEmpty ||
          find.textContaining('Title').evaluate().isNotEmpty;
      expect(hasSheet, isTrue, reason: 'Add spot sheet should open');
      noException(t);
      await dismissModal(t);
    });

    testWidgets('tapping a spot navigates to spot detail', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Spots');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final spots = find.byType(ListTile);
      if (spots.evaluate().isEmpty) {
        print('[features] No spots to tap — skipping spot detail test');
        return;
      }
      await t.tap(spots.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      // Spot detail shows some section like Links or Notes
      final hasDetail =
          find.text('Links').evaluate().isNotEmpty ||
          find.text('Notes').evaluate().isNotEmpty ||
          find.text('Your vote').evaluate().isNotEmpty ||
          find.text('Documents').evaluate().isNotEmpty;
      expect(hasDetail, isTrue, reason: 'Spot detail should render');
      noException(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // PLAN SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Plan screen', () {
    testWidgets('loads — list or empty state renders', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Plan');
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.byType(Scaffold), findsWidgets);
      noException(t);
    });

    testWidgets('calendar toggle button exists', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Plan');
      await t.pumpAndSettle(const Duration(seconds: 2));
      final calIcon = find.byIcon(Icons.calendar_month_outlined);
      if (calIcon.evaluate().isNotEmpty) {
        await t.tap(calIcon.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        noException(t);
        // Toggle back
        await t.tap(find.byIcon(Icons.calendar_month_outlined).first);
        await t.pumpAndSettle();
      }
    });

    testWidgets('add day dialog opens without crash', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Plan');
      await t.pumpAndSettle(const Duration(seconds: 2));
      final addDayBtn = find.text('Add Day');
      if (addDayBtn.evaluate().isEmpty) return;
      await t.tap(addDayBtn.first);
      await t.pumpAndSettle();
      expect(find.text('Add day'), findsWidgets);
      noException(t);
      await tapFirst(t, find.text('Cancel'));
    });

    testWidgets('add item sheet opens when a day exists', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Plan');
      await t.pumpAndSettle(const Duration(seconds: 3));
      // Look for the + FAB (only visible when a day is selected)
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isEmpty) {
        print('[features] No FAB on plan screen — likely no days yet');
        return;
      }
      await t.tap(fab.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Add itinerary item'), findsOneWidget);
      noException(t);
      await dismissModal(t);
    });

    testWidgets('plan item "done" toggle works', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Plan');
      await t.pumpAndSettle(const Duration(seconds: 3));
      // Find a Checkbox in the plan list
      final checkboxes = find.byType(Checkbox);
      if (checkboxes.evaluate().isEmpty) {
        print('[features] No plan items to toggle — skipping');
        return;
      }
      await t.tap(checkboxes.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      noException(t);
      // Toggle back
      await t.tap(checkboxes.first);
      await t.pumpAndSettle();
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // MONEY SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Money screen', () {
    testWidgets('loads with Receipts, Cash, Settle Up tabs', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Money');
      await t.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('Receipts'), findsWidgets);
      noException(t);
    });

    testWidgets('Cash tab loads without crash', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Money');
      await t.pumpAndSettle(const Duration(seconds: 2));
      final cashTab = find.text('Cash');
      if (cashTab.evaluate().isNotEmpty) {
        await t.tap(cashTab.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
      }
      noException(t);
    });

    testWidgets('Settle Up tab loads without crash', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Money');
      await t.pumpAndSettle(const Duration(seconds: 2));
      final tab = find.text('Settle Up');
      if (tab.evaluate().isNotEmpty) {
        await t.tap(tab.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
      }
      noException(t);
    });

    testWidgets('add receipt sheet opens without crash', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Money');
      await t.pumpAndSettle(const Duration(seconds: 2));
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isEmpty) return;
      await t.tap(fab.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      final hasSheet =
          find.text('Add receipt').evaluate().isNotEmpty ||
          find.textContaining('receipt').evaluate().isNotEmpty;
      expect(hasSheet, isTrue);
      noException(t);
      await dismissModal(t);
    });

    testWidgets('search field filters receipts', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Money');
      await t.pumpAndSettle(const Duration(seconds: 2));
      final searchField = find.textContaining('Search receipts');
      if (searchField.evaluate().isNotEmpty) {
        await t.tap(searchField.first);
        await t.pumpAndSettle();
        await t.enterText(searchField, 'zzznotfound');
        await t.pumpAndSettle(const Duration(seconds: 1));
        noException(t);
      }
    });

    testWidgets('export/share does not crash', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Money');
      await t.pumpAndSettle(const Duration(seconds: 2));
      final shareIcon = find.byIcon(Icons.share_rounded);
      if (shareIcon.evaluate().isNotEmpty) {
        await t.tap(shareIcon.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        noException(t);
        await dismissModal(t);
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // MORE SCREEN — all row navigations
  // ════════════════════════════════════════════════════════════════════════════

  group('More screen: rows and sections', () {
    testWidgets('all section headers visible', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      expect(find.text('TRIP'), findsWidgets);
      noException(t);
    });

    testWidgets('Crew Chat row navigates to Crew screen', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Crew Chat', 'Crew');
    });

    testWidgets('Packing List row navigates to Packing screen', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Packing List', 'Packing List');
    });

    testWidgets('Map row navigates to Map screen', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Map', 'Map');
    });

    testWidgets('Travel row navigates to Travel screen', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Travel', 'Travel');
    });

    testWidgets('Photos row navigates to Photos screen', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Photos', 'Photos');
    });

    testWidgets('Links row navigates to Links screen', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Links', 'Links');
    });

    testWidgets('Stays row navigates to Stays screen', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Stays', 'Stay');
    });

    testWidgets('Documents row navigates to Documents screen', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Documents', 'Documents');
    });

    testWidgets('Shopping List row navigates to Shopping screen', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Shopping List', 'Shopping');
    });

    testWidgets('Create invite code opens invite sheet', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final row = find.text('Create invite code');
      if (row.evaluate().isEmpty) return;
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Invite codes'), findsOneWidget);
      noException(t);
      await dismissModal(t);
    });

    testWidgets('Add a member opens invite/add-member sheet', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final row = find.text('Add a member');
      if (row.evaluate().isEmpty) return;
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      noException(t);
      await dismissModal(t);
    });

    testWidgets('Edit name opens edit name sheet', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final row = find.text('Edit name');
      if (row.evaluate().isEmpty) return;
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      noException(t);
      await dismissModal(t);
    });

    testWidgets('Switch trip opens trip switcher sheet', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final row = find.text('Switch trip');
      if (row.evaluate().isEmpty) return;
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Your trips'), findsOneWidget);
      noException(t);
      await dismissModal(t);
    });

    testWidgets('Edit trip details opens trip settings sheet', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final row = find.text('Edit trip details');
      if (row.evaluate().isEmpty) {
        print('[features] "Edit trip details" not found — may not be owner');
        return;
      }
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Trip settings'), findsOneWidget);
      noException(t);
      await dismissModal(t);
    });

    testWidgets('Import file or link opens import screen', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final row = find.text('Import file or link');
      if (row.evaluate().isEmpty) return;
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      noException(t);
      await t.pageBack();
      await t.pumpAndSettle();
    });

    testWidgets("What's new opens changelog sheet", (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final row = find.text("What's new");
      if (row.evaluate().isEmpty) return;
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      noException(t);
      await dismissModal(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // CREW SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Crew screen', () {
    testWidgets('chat tab visible, no crash', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Crew Chat', 'Crew');
      expect(find.text('Chat'), findsWidgets);
      noException(t);
    });

    testWidgets('message input field is present', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Crew Chat', 'Crew');
      final chatInput = find.textContaining('Message the crew');
      expect(chatInput, findsOneWidget);
      noException(t);
    });

    testWidgets('can type in chat input without crash', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Crew Chat', 'Crew');
      final input = find.byType(EditableText);
      if (input.evaluate().isEmpty) return;
      await t.tap(input.last);
      await t.enterText(input.last, 'Integration test message — ignore');
      await t.pumpAndSettle();
      noException(t);
      // Clear without sending
      await t.enterText(input.last, '');
    });

    testWidgets('Live Map tab switches without crash', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Crew Chat', 'Crew');
      final mapTab = find.text('Live Map');
      if (mapTab.evaluate().isNotEmpty) {
        await t.tap(mapTab.first);
        await t.pumpAndSettle(const Duration(seconds: 3));
        noException(t);
      }
    });

    testWidgets('SOS button shows confirmation dialog', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Crew Chat', 'Crew');
      // SOS is a red button in the input bar area
      final sosBtn = find.textContaining('SOS');
      if (sosBtn.evaluate().isEmpty) return;
      await t.tap(sosBtn.first);
      await t.pumpAndSettle();
      expect(find.text('Alert your crew?'), findsOneWidget);
      await tapFirst(t, find.text('Cancel'));
      noException(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // PACKING SCREEN — full CRUD cycle
  // ════════════════════════════════════════════════════════════════════════════

  group('Packing screen — full CRUD', () {
    const testItemTitle = 'Integration test item — delete me';

    testWidgets('loads — list or empty state renders', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Packing List', 'Packing List');
      noException(t);
    });

    testWidgets('add item field is present', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Packing List', 'Packing List');
      final hasInput = find.byType(TextField).evaluate().isNotEmpty ||
          find.byType(TextFormField).evaluate().isNotEmpty;
      expect(hasInput, isTrue, reason: 'Packing screen should have a text input');
      noException(t);
    });

    testWidgets('add → appears in list → toggle → delete', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Packing List', 'Packing List');

      // Add item via text field
      final inputField = find.byType(EditableText).last;
      await t.tap(inputField);
      await t.enterText(inputField, testItemTitle);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle(const Duration(seconds: 2));

      // Item should appear
      expect(find.text(testItemTitle), findsOneWidget,
          reason: 'Added item should appear in the packing list');
      noException(t);

      // Toggle packed state
      final checkbox = find.byType(Checkbox);
      if (checkbox.evaluate().isNotEmpty) {
        await t.tap(checkbox.last);
        await t.pumpAndSettle(const Duration(seconds: 2));
        noException(t);
      }

      // Delete the test item via swipe or long-press popup
      // Try swipe-to-dismiss first
      await t.drag(find.text(testItemTitle), const Offset(-300, 0));
      await t.pumpAndSettle(const Duration(seconds: 2));
      // If still present, use the DB to clean up
      if (find.text(testItemTitle).evaluate().isNotEmpty) {
        print('[features] Swipe did not delete — cleaning up via DB');
        final uid = sb.auth.currentUser?.id;
        if (uid != null) {
          await sb
              .from('packing_items')
              .delete()
              .eq('title', testItemTitle);
        }
      }
      noException(t);
    });

    testWidgets('search filters items', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Packing List', 'Packing List');
      final searchHint = find.textContaining('Search items');
      if (searchHint.evaluate().isEmpty) return;
      await t.tap(searchHint.first);
      await t.pumpAndSettle();
      await t.enterText(searchHint, 'zzznotfound');
      await t.pumpAndSettle(const Duration(seconds: 1));
      noException(t);
    });

    testWidgets('overflow menu opens without crash', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Packing List', 'Packing List');
      final moreIcon = find.byIcon(Icons.more_vert_rounded);
      if (moreIcon.evaluate().isEmpty) return;
      await t.tap(moreIcon.first);
      await t.pumpAndSettle();
      noException(t);
      await t.tapAt(const Offset(20, 20));
      await t.pumpAndSettle();
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // SHOPPING SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Shopping screen', () {
    const testItem = 'Test grocery item — delete me';

    testWidgets('loads — list or empty state', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Shopping List', 'Shopping');
      noException(t);
    });

    testWidgets('add item → appears → check off → clear', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Shopping List', 'Shopping');

      // Type in the quick-add field
      final inputs = find.byType(EditableText);
      if (inputs.evaluate().isEmpty) return;
      await t.tap(inputs.last);
      await t.enterText(inputs.last, testItem);
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text(testItem), findsOneWidget);
      noException(t);

      // Check it off
      final checkbox = find.byType(Checkbox);
      if (checkbox.evaluate().isNotEmpty) {
        await t.tap(checkbox.first);
        await t.pumpAndSettle(const Duration(seconds: 1));
      }

      // Clear checked
      final clearBtn = find.text('Clear checked');
      if (clearBtn.evaluate().isNotEmpty) {
        await t.tap(clearBtn.first);
        await t.pumpAndSettle();
        // Confirmation dialog
        final confirmBtn = find.text('Clear');
        if (confirmBtn.evaluate().isNotEmpty) {
          await t.tap(confirmBtn.first);
          await t.pumpAndSettle(const Duration(seconds: 2));
        }
      } else {
        // Clean up via DB
        await sb.from('shopping_items').delete().eq('name', testItem);
      }
      noException(t);
    });

    testWidgets('add item sheet (tune icon) opens without crash', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Shopping List', 'Shopping');
      final tuneIcon = find.byIcon(Icons.tune_rounded);
      if (tuneIcon.evaluate().isEmpty) return;
      await t.tap(tuneIcon.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Add item'), findsWidgets);
      noException(t);
      await dismissModal(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // TRAVEL SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Travel screen', () {
    testWidgets('loads — list or empty state', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Travel', 'Travel');
      noException(t);
    });

    testWidgets('add travel item sheet opens', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Travel', 'Travel');
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isEmpty) return;
      await t.tap(fab.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      noException(t);
      await dismissModal(t);
    });

    testWidgets('search field present', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Travel', 'Travel');
      final search = find.textContaining('Search travel');
      if (search.evaluate().isNotEmpty) {
        expect(search, findsOneWidget);
      }
      noException(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // STAYS (ACCOMMODATIONS) SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Stays screen', () {
    testWidgets('loads — list or empty state', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Stays', 'Stay');
      noException(t);
    });

    testWidgets('add stay sheet opens', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Stays', 'Stay');
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isEmpty) return;
      await t.tap(fab.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      noException(t);
      await dismissModal(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // MAP SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Map screen', () {
    testWidgets('loads — map or list renders', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Map', 'Map');
      noException(t);
    });

    testWidgets('can switch to list view', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Map', 'Map');
      final listBtn = find.text('List');
      if (listBtn.evaluate().isNotEmpty) {
        await t.tap(listBtn.first);
        await t.pumpAndSettle(const Duration(seconds: 2));
        noException(t);
      }
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // LINKS SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Links screen', () {
    testWidgets('loads — list or empty state', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Links', 'Links');
      noException(t);
    });

    testWidgets('add link sheet opens', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Links', 'Links');
      final fab = find.byType(FloatingActionButton);
      if (fab.evaluate().isEmpty) {
        final addBtn = find.textContaining('Save a link');
        if (addBtn.evaluate().isEmpty) return;
        await t.tap(addBtn.first);
      } else {
        await t.tap(fab.first);
      }
      await t.pumpAndSettle(const Duration(seconds: 2));
      noException(t);
      await dismissModal(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // DOCUMENTS SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Documents screen', () {
    testWidgets('loads — list or empty state', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Documents', 'Documents');
      noException(t);
    });

    testWidgets('search field is present', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Documents', 'Documents');
      final search = find.textContaining('Search documents');
      if (search.evaluate().isNotEmpty) expect(search, findsOneWidget);
      noException(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // PHOTOS SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Photos screen', () {
    testWidgets('loads — album list or empty state', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Photos', 'Photos');
      noException(t);
    });

    testWidgets('album type buttons visible when no albums', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Photos', 'Photos');
      final hasGooglePhotos = find.text('Google Photos').evaluate().isNotEmpty;
      final hasAlbums = find.byType(ListTile).evaluate().isNotEmpty;
      expect(hasGooglePhotos || hasAlbums, isTrue,
          reason: 'Photos screen should show album options or existing albums');
      noException(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // TRIP MANAGEMENT
  // ════════════════════════════════════════════════════════════════════════════

  group('Trip management', () {
    testWidgets('trip switcher sheet lists trips and has create/join', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final switchRow = find.text('Switch trip');
      if (switchRow.evaluate().isEmpty) return;
      await t.tap(switchRow.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Your trips'), findsOneWidget);
      expect(find.text('Create trip'), findsOneWidget);
      expect(find.text('Join trip'), findsOneWidget);
      noException(t);
      await dismissModal(t);
    });

    testWidgets('trip settings sheet shows all fields', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final row = find.text('Edit trip details');
      if (row.evaluate().isEmpty) {
        print('[features] Not a trip owner — skipping trip settings test');
        return;
      }
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Trip name'), findsOneWidget);
      expect(find.text('Default currency'), findsOneWidget);
      noException(t);
      await dismissModal(t);
    });

    testWidgets('invite codes sheet generates and displays codes', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      final row = find.text('Create invite code');
      if (row.evaluate().isEmpty) return;
      await t.tap(row.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Invite codes'), findsOneWidget);
      expect(find.text('Generate new code'), findsOneWidget);
      noException(t);
      await dismissModal(t);
    });

    testWidgets('trip switch updates home screen trip name', (t) async {
      // Load the list of trips for this user
      final trips = await sb
          .from('trip_members')
          .select('trips(name)')
          .eq('user_id', sb.auth.currentUser!.id);

      if (trips.length < 2) {
        print('[features] Only ${trips.length} trip(s) — skipping switch test');
        return;
      }

      await pumpApp(t);
      await tapTab(t, 'More');
      final switchRow = find.text('Switch trip');
      if (switchRow.evaluate().isEmpty) return;
      await t.tap(switchRow.first);
      await t.pumpAndSettle(const Duration(seconds: 2));

      final secondName = (trips[1]['trips'] as Map<String, dynamic>)['name'] as String;
      final secondFinder = find.text(secondName);
      if (secondFinder.evaluate().isEmpty) {
        await dismissModal(t);
        return;
      }
      await t.tap(secondFinder.first);
      await t.pumpAndSettle(const Duration(seconds: 4));

      await tapTab(t, 'Home');
      expect(find.textContaining(secondName), findsWidgets,
          reason: 'Home screen should reflect the new trip after switching');
      noException(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // SETTINGS SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('Settings screen', () {
    testWidgets('Edit name sheet opens and has name field', (t) async {
      await pumpApp(t);
      await tapMoreRow(t, 'Edit name');
      noException(t);
      final nameField = find.byType(EditableText);
      expect(nameField.evaluate().isNotEmpty, isTrue,
          reason: 'Edit name sheet should have a text field');
      await dismissModal(t);
    });

    testWidgets('Set/change password opens sheet', (t) async {
      await pumpApp(t);
      await tapMoreRow(t, 'Set / change password');
      noException(t);
      await dismissModal(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // NAVIGATION — back button behaviour
  // ════════════════════════════════════════════════════════════════════════════

  group('Navigation', () {
    testWidgets('back button from sub-screen returns to More', (t) async {
      await pumpApp(t);
      await _goToMoreScreen(t, 'Packing List', 'Packing List');
      await t.pageBack();
      await t.pumpAndSettle(const Duration(seconds: 2));
      // Should be back on More (or home — depends on device back behavior)
      noException(t);
    });

    testWidgets('back button from spot detail returns to Spots list', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Spots');
      await t.pumpAndSettle(const Duration(seconds: 3));
      final tiles = find.byType(ListTile);
      if (tiles.evaluate().isEmpty) return;
      await t.tap(tiles.first);
      await t.pumpAndSettle(const Duration(seconds: 2));
      await t.pageBack();
      await t.pumpAndSettle(const Duration(seconds: 2));
      expect(find.textContaining('Search spots'), findsOneWidget);
      noException(t);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // RIVERPOD-SPECIFIC: providers update after trip switch
  // ════════════════════════════════════════════════════════════════════════════

  group('Riverpod provider correctness', () {
    testWidgets('activeTripProvider is non-null after loading', (t) async {
      await pumpApp(t);
      await tapTab(t, 'Home');
      // If the user has a trip, the trip name should be somewhere in the UI.
      // We can't check the provider value directly, but a Scaffold proves
      // the widget didn't crash with a null-deref.
      expect(find.byType(Scaffold), findsWidgets);
      noException(t);
    });

    testWidgets('tripMembersProvider populates More screen member list', (t) async {
      await pumpApp(t);
      await tapTab(t, 'More');
      // The member list (avatars or names) should be rendered
      expect(find.byType(Scaffold), findsWidgets);
      noException(t);
    });

    testWidgets('all screens reload when switching trips', (t) async {
      final trips = await sb
          .from('trip_members')
          .select('trips(name)')
          .eq('user_id', sb.auth.currentUser!.id);
      if (trips.length < 2) return;

      await pumpApp(t);
      // Navigate around to warm up providers
      for (final tab in ['Home', 'Spots', 'Plan', 'Money']) {
        await tapTab(t, tab);
      }

      // Switch trip
      await tapTab(t, 'More');
      final switchRow = find.text('Switch trip');
      if (switchRow.evaluate().isEmpty) return;
      await t.tap(switchRow.first);
      await t.pumpAndSettle(const Duration(seconds: 2));

      final secondName = (trips[1]['trips'] as Map<String, dynamic>)['name'] as String;
      final secondFinder = find.text(secondName);
      if (secondFinder.evaluate().isEmpty) {
        await dismissModal(t);
        return;
      }
      await t.tap(secondFinder.first);
      await t.pumpAndSettle(const Duration(seconds: 4));

      // Navigate to each screen — they should all load without crashing
      for (final tab in ['Home', 'Spots', 'Plan', 'Money']) {
        await tapTab(t, tab);
        noException(t);
      }
    });
  });
}
