import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/data/money_data.dart';

// Settle Up with a typed-in CAD amount: that receipt is paid back in CAD,
// and the yen section shows roughly what each balance is in CAD.
void main() {
  const members = [
    TripMember(id: 'me', name: 'Me'),
    TripMember(id: 'ber', name: 'Ber'),
  ];

  Receipt r(String id, double amount, double home, {bool set = false, String payer = 'me', String currency = 'JPY'}) =>
      Receipt(
        id: id, title: id, amount: amount, currency: currency, homeAmount: home,
        exchangeRate: currency == 'CAD' ? 1 : home / amount, transactionFeePct: 0,
        paidById: payer, category: ReceiptCategory.transport, date: DateTime(2026, 11, 14),
        homeAmountSet: set,
        splits: [
          ReceiptSplit(memberId: 'me', amount: amount / 2),
          ReceiptSplit(memberId: 'ber', amount: amount / 2),
        ],
      );

  // Hakata: CAD typed in. Hikari: rate only. Nintendo Museum: paid in CAD.
  final receipts = [
    r('hakata', 34280, 307.76, set: true),
    r('hikari', 49720, 446.37),
    r('museum', 117.72, 117.72, currency: 'CAD'),
  ];

  test('a receipt with a typed-in CAD amount settles in CAD', () {
    final b = calculateBalancesGrouped(receipts, const [],
        myId: 'me', members: members, homeCurrency: 'CAD');
    expect(b['CAD']!.single.net, closeTo(307.76 / 2 + 117.72 / 2, 0.001));
    expect(b['CAD']!.single.homeNet, isNull);
    expect(b['JPY']!.single.net, 49720 / 2);
  });

  test('the yen section shows the CAD amount at the receipt rate', () {
    final b = calculateBalancesGrouped(receipts, const [],
        myId: 'me', members: members, homeCurrency: 'CAD');
    expect(b['JPY']!.single.homeNet, closeTo(446.37 / 2, 0.001));
  });

  test('cash uses the rate of the receipts in its currency', () {
    final cash = [
      CashWithdrawal(
        id: 'atm', withdrawnById: 'me', amount: 10000, atmFee: 0, currency: 'JPY',
        date: DateTime(2026, 11, 14),
        distributions: const [CashDistribution(memberId: 'ber', amount: 5000)],
      ),
    ];
    final b = calculateBalancesGrouped([receipts[1]], cash,
        myId: 'me', members: members, homeCurrency: 'CAD');
    expect(b['JPY']!.single.net, 49720 / 2 + 5000);
    expect(b['JPY']!.single.homeNet, closeTo((49720 / 2 + 5000) * 446.37 / 49720, 0.001));
  });

  test('without a home currency everything stays in its own currency', () {
    final b = calculateBalancesGrouped(receipts, const [], myId: 'me', members: members);
    expect(b['JPY']!.single.net, (34280 + 49720) / 2);
    expect(b['JPY']!.single.homeNet, isNull);
  });

  test('Mark settled in CAD clears the typed-in receipt, not the yen ones', () {
    final cad = openSharesBetween(receipts, const [],
        a: 'ber', b: 'me', currency: 'CAD', homeCurrency: 'CAD');
    expect(cad.receiptShares, [('hakata', 'ber'), ('museum', 'ber')]);
    final jpy = openSharesBetween(receipts, const [],
        a: 'ber', b: 'me', currency: 'JPY', homeCurrency: 'CAD');
    expect(jpy.receiptShares, [('hikari', 'ber')]);
  });
}
