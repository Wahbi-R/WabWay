import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/data/money_data.dart';

// Several people paid one receipt — the Yakiniku Rengaya bill (¥14,795, four
// people, three put in cash) and "Ber gave ¥10,000 and I gave ¥1,000".
void main() {
  const members = [
    TripMember(id: 'me', name: 'Me'),
    TripMember(id: 'ber', name: 'Ber'),
    TripMember(id: 'shams', name: 'Shams'),
    TripMember(id: 'anojan', name: 'Anojan'),
  ];

  Receipt receipt(double amount, List<ReceiptSplit> shares, Map<String, double> paid) => Receipt(
        id: 'r', title: 'Yakiniku', amount: amount, currency: 'JPY', homeAmount: amount / 100,
        exchangeRate: 0.01, transactionFeePct: 0,
        paidById: mainPayerOf(paid, 'me'),
        category: ReceiptCategory.food, date: DateTime(2026, 11, 8),
        splits: withContributions(shares, paid),
      );

  final equal4 = [
    for (final m in members) ReceiptSplit(memberId: m.id, amount: 14795 / 4),
  ];
  final rengaya = receipt(14795, equal4, {'ber': 10000, 'me': 4000, 'shams': 795});

  test('whoever put in the most is the main payer', () {
    expect(rengaya.paidById, 'ber');
    expect(rengaya.hasSeveralPayers, isTrue);
    expect(rengaya.payers, {'ber': 10000, 'me': 4000, 'shams': 795});
    expect(rengaya.contributionOf('ber'), 10000);
  });

  test('each share minus what they put in is settled with the main payer', () {
    double owes(String id) => rengaya.owes(rengaya.splits.firstWhere((s) => s.memberId == id));
    expect(owes('ber'), 0);
    expect(owes('me'), closeTo(3698.75 - 4000, 0.001)); // Ber owes me 301.25
    expect(owes('shams'), closeTo(3698.75 - 795, 0.001));
    expect(owes('anojan'), closeTo(3698.75, 0.001));
  });

  test('balances: Ber is owed exactly what they paid beyond their share', () {
    final fromBer = calculateBalancesGrouped([rengaya], const [], myId: 'ber', members: members)['JPY']!;
    double net(String id) => fromBer.firstWhere((b) => b.member.id == id).net;
    expect(net('me'), closeTo(-301.25, 0.001));
    expect(net('shams'), closeTo(2903.75, 0.001));
    expect(net('anojan'), closeTo(3698.75, 0.001));
    expect(fromBer.fold(0.0, (a, b) => a + b.net), closeTo(10000 - 3698.75, 0.001));

    final fromMe = calculateBalancesGrouped([rengaya], const [], myId: 'me', members: members)['JPY']!;
    expect(fromMe.single.member.id, 'ber');
    expect(fromMe.single.net, closeTo(301.25, 0.001)); // Ber owes me
    expect(rengaya.myNetFor('me'), closeTo(301.25, 0.001));
    expect(rengaya.myNetFor('ber'), closeTo(10000 - 3698.75, 0.001));
  });

  test('Ber gave ¥10,000 and I gave ¥1,000 for ¥11,000 split two ways', () {
    final r = receipt(11000, [
      const ReceiptSplit(memberId: 'me', amount: 5500),
      const ReceiptSplit(memberId: 'ber', amount: 5500),
    ], {'ber': 10000, 'me': 1000});
    expect(r.myNetFor('me'), -4500);
    expect(r.myNetFor('ber'), 4500);
  });

  test('someone can chip in without sharing the cost', () {
    final r = receipt(3000, [
      const ReceiptSplit(memberId: 'me', amount: 1500),
      const ReceiptSplit(memberId: 'ber', amount: 1500),
    ], {'me': 2000, 'shams': 1000});
    final shams = r.splits.firstWhere((s) => s.memberId == 'shams');
    expect(shams.amount, 0);
    expect(shams.contributed, 1000);
    expect(r.paidById, 'me');
    expect(r.owes(shams), -1000); // I owe Shams 1000
    expect(r.myNetFor('me'), closeTo(1500 - 1000, 0.001));
  });

  test('settling a share clears that person and nobody else', () {
    final settled = rengaya.copyWith(splits: [
      for (final s in rengaya.splits) s.memberId == 'shams' ? s.copyWith(isSettled: true) : s,
    ]);
    final open = openSharesBetween([settled], const [], a: 'ber', b: 'shams', currency: 'JPY');
    expect(open.isEmpty, isTrue);
    final withMe = openSharesBetween([settled], const [], a: 'ber', b: 'me', currency: 'JPY');
    expect(withMe.receiptShares, [('r', 'me')]);
    expect(settled.isFullySettled, isFalse);
  });

  test('one payer works exactly as before', () {
    final r = receipt(1000, [
      const ReceiptSplit(memberId: 'me', amount: 500),
      const ReceiptSplit(memberId: 'ber', amount: 500),
    ], const {});
    expect(r.hasSeveralPayers, isFalse);
    expect(r.payers, {'me': 1000});
    expect(r.myNetFor('me'), 500);
    expect(r.splits.every((s) => s.contributed == 0), isTrue);
  });

  group('translated item names', () {
    test('scan keeps both names, and the title reads in English first', () {
      final it = ReceiptItemization.fromScan({
        'title': '焼肉れんが屋',
        'title_en': 'Yakiniku Rengaya',
        'items': [
          {'name': '梅酒【本坊酒造】(ロック)', 'name_en': 'Plum wine (Hombo Shuzo, on the rocks)', 'quantity': 2, 'total_price': 1000},
          {'name': 'Calpis highball', 'quantity': 1, 'total_price': 600},
        ],
      });
      expect(it.title, 'Yakiniku Rengaya (焼肉れんが屋)');
      expect(it.items[0].displayName(), 'Plum wine (Hombo Shuzo, on the rocks)');
      expect(it.items[0].displayName(english: false), '梅酒【本坊酒造】(ロック)');
      expect(it.items[1].displayName(), 'Calpis highball');
      expect(it.hasTranslations, isTrue);
      expect(it.needsTranslation, isFalse);
      final back = ReceiptItemization.fromJsonOrNull(it.toJson())!;
      expect(back.items[0].nameEn, 'Plum wine (Hombo Shuzo, on the rocks)');
    });

    test('Translate fills in names that need it; renaming drops a stale one', () {
      final it = ReceiptItemization.fromScan({
        'items': [
          {'name': 'ロック/たんかん酒', 'quantity': 9, 'total_price': 5850},
          {'name': 'Coke', 'quantity': 1, 'total_price': 300},
        ],
      });
      expect(it.needsTranslation, isTrue);
      final t = it.withTranslations(['Tankan citrus liquor (on the rocks)', '']);
      expect(t.needsTranslation, isFalse);
      expect(t.items[0].nameEn, 'Tankan citrus liquor (on the rocks)');
      expect(t.items[1].nameEn, isNull);
      expect(t.items[0].copyWith(totalPrice: 6000).nameEn, isNotNull);
      expect(t.items[0].copyWith(name: 'ロック').nameEn, isNull);
    });

    test('isProbablyEnglish', () {
      expect(isProbablyEnglish('Café latte x2'), isTrue);
      expect(isProbablyEnglish('サービスカルビ'), isFalse);
      expect(isProbablyEnglish('メガ2倍/こだわり酒場レモ'), isFalse);
      expect(isProbablyEnglish('1,100'), isTrue);
    });
  });
}
