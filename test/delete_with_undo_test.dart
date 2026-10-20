import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/widgets/wabway_snack.dart';

// Swipe-to-delete everywhere goes through deleteWithUndo: hidden at once,
// deleted only when the toast closes without Undo.
void main() {
  late List<String> items;
  late List<String> deleted;
  late BuildContext ctx;

  Future<void> pump(WidgetTester tester) async {
    items = ['NICO Hotel', 'Hikari 704'];
    deleted = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
  }

  Future<void> swipe(WidgetTester tester, {bool fail = false}) async {
    deleteWithUndo(
      ctx,
      id: 'nico',
      message: '"NICO Hotel" deleted.',
      hide: () => items.remove('NICO Hotel'),
      restore: () => items.insert(0, 'NICO Hotel'),
      commit: () async {
        if (fail) throw Exception('offline');
        deleted.add('nico');
      },
    );
    await tester.pump();
  }

  testWidgets('Undo puts it back and never deletes', (tester) async {
    await pump(tester);
    await swipe(tester);
    expect(items, ['Hikari 704']);
    expect(withoutPendingDeletes(['nico', 'hikari'], (s) => s), ['hikari'],
        reason: 'a reload during the Undo window keeps it hidden');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(items, ['NICO Hotel', 'Hikari 704']);
    expect(deleted, isEmpty);
    expect(withoutPendingDeletes(['nico'], (s) => s), ['nico']);
  });

  testWidgets('without Undo it is deleted when the toast closes', (tester) async {
    await pump(tester);
    await swipe(tester);
    expect(deleted, isEmpty, reason: 'nothing deleted while Undo is still offered');
    await tester.pumpAndSettle(); // the toast's timer starts once it's shown
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(deleted, ['nico']);
    expect(items, ['Hikari 704']);
  });

  testWidgets('a failed delete brings it back', (tester) async {
    await pump(tester);
    await swipe(tester, fail: true);
    await tester.pumpAndSettle(); // the toast's timer starts once it's shown
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(items, ['NICO Hotel', 'Hikari 704']);
    expect(find.textContaining("it's back"), findsOneWidget);
  });
}
