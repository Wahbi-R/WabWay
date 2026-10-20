import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/core/stay_receipt_sync.dart';
import 'package:wabway/data/money_data.dart';

void main() {
  Receipt receipt({bool settled = false}) => Receipt(
        id: 'r', title: 'NICO Hotel', amount: 88509, currency: 'JPY', homeAmount: 791.70,
        exchangeRate: 0.008945, transactionFeePct: 0, paidById: 'me',
        category: ReceiptCategory.accommodation, date: DateTime(2026, 10, 20), homeAmountSet: true,
        splits: [
          for (final m in ['me', 'ber', 'shams', 'anojan'])
            ReceiptSplit(memberId: m, amount: 88509 / 4, isSettled: settled && m == 'ber'),
        ],
      );

  test('prices agree up to the currency\'s rounding', () {
    expect(pricesAgree(919.36, 919.37, 'CAD'), isTrue);
    expect(pricesAgree(919.37, 1086.21, 'CAD'), isFalse, reason: 'a refund is a real difference');
    expect(pricesAgree(88509, 88509.4, 'JPY'), isTrue);
    expect(pricesAgree(88509, 90000, 'JPY'), isFalse);
  });

  test('re-pricing scales every share and they add up exactly', () {
    final s = rescaledSplits(receipt(), 90001);
    expect(s.map((x) => x.memberId), ['me', 'ber', 'shams', 'anojan']);
    expect(s.fold(0.0, (a, x) => a + x.amount), 90001);
    expect(s.every((x) => x.amount % 1 == 0), isTrue, reason: 'whole yen');
  });

  test('a receipt with paid-back shares or items is changed by hand', () {
    expect(rescaleBlocker(receipt()), isNull);
    expect(rescaleBlocker(receipt(settled: true)), contains('paid back'));
  });
}
