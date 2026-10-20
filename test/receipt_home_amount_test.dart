import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wabway/data/member_data.dart';
import 'package:wabway/data/money_data.dart';
import 'package:wabway/screens/money/add_receipt_sheet.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test("each share's home amount uses the rate actually paid", () {
    final r = Receipt(
      id: 'r', title: 'Shinkansen', amount: 34280, currency: 'JPY', homeAmount: 307.76,
      exchangeRate: 0.00889, transactionFeePct: 0, paidById: 'me', splits: const [],
      category: ReceiptCategory.transport, date: DateTime(2026, 10, 20),
    );
    // C$307.76 over ¥34,280 (overridden), not the fetched 0.00889.
    expect(fmtAmount(8570 * r.homeRate, 'CAD'), r'C$76.94');
  });

  testWidgets('typing the CAD amount works out the exchange rate', (tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final receipt = Receipt(
      id: 'r1', title: 'Shinkansen', amount: 38680, currency: 'JPY',
      homeAmount: 343.87, exchangeRate: 0.00889, transactionFeePct: 0, paidById: 'me',
      splits: const [ReceiptSplit(memberId: 'me', amount: 38680)],
      category: ReceiptCategory.transport, date: DateTime(2026, 10, 20),
    );
    await tester.pumpWidget(MaterialApp(home: Builder(
      builder: (context) => Scaffold(body: Center(child: ElevatedButton(
        onPressed: () => showAddReceiptSheet(context, userId: 'me',
            members: const [TripMember(id: 'me', name: 'Wahbi', isMe: true)],
            homeCurrency: 'CAD', existingReceipt: receipt),
        child: const Text('open'),
      ))),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('0.008890'), findsOneWidget);
    await tester.tap(find.text('Override'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '343.87'), '340');
    await tester.pump();
    // 340 / 38,680 = 0.008790 — the rate follows the amount actually charged.
    expect(find.text('0.008790'), findsOneWidget);
  });
}
