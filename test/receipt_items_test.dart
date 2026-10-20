import 'package:flutter_test/flutter_test.dart';
import 'package:wabway/core/receipts_link_service.dart';
import 'package:wabway/data/money_data.dart';

// A dinner: 2× gyoza (shared by A and B), ramen (A), beer 3× (A 1, C 2),
// edamame (nobody), 10% tax, 5 tip, 3 discount.
ReceiptItemization dinner() {
  var it = const ReceiptItemization(items: [], tax: 0, tip: 0)
      .addItem(name: 'Gyoza', quantity: 2, totalPrice: 12)
      .addItem(name: 'Ramen', quantity: 1, totalPrice: 15)
      .addItem(name: 'Beer', quantity: 3, totalPrice: 21)
      .addItem(name: 'Edamame', quantity: 1, totalPrice: 4);
  it = it.toggle(0, 'a').toggle(0, 'b'); // equal: 1 each
  it = it.toggle(1, 'a');
  it = it.setWeight(2, 'a', 1).setWeight(2, 'c', 2);
  return it.copyWith(tax: 5.2, tip: 5, discount: 3);
}

void main() {
  group('ReceiptItemization', () {
    test('toggle splits equally, then hands leftovers to newcomers', () {
      var it = const ReceiptItemization(items: []).addItem(name: 'Beer', quantity: 3, totalPrice: 21);
      it = it.toggle(0, 'a');
      expect(it.weightsFor(0), {'a': 3});
      it = it.toggle(0, 'b');
      expect(it.weightsFor(0), {'a': 1.5, 'b': 1.5});
      // custom: a 1 of 3 → b joins and takes the remaining 2
      it = it.setWeight(0, 'a', 1).setWeight(0, 'b', 0);
      it = it.toggle(0, 'b');
      expect(it.weightsFor(0), {'a': 1, 'b': 2});
      // removing from a custom split leaves the part unclaimed
      it = it.toggle(0, 'b');
      expect(it.weightsFor(0), {'a': 1});
      expect(it.unclaimedTotal, closeTo(14, 1e-9));
    });

    test('person totals match the Receipts site formula', () {
      final it = dinner();
      final t = it.personTotals(['a', 'b', 'c']);
      // items: a = 6 + 15 + 7 = 28, b = 6, c = 14; itemsTotal = 52
      // extras = 5.2 + 5 − 3 = 7.2, shared by share of the full 52
      expect(t['a'], closeTo(28 + 7.2 * 28 / 52, 1e-9));
      expect(t['b'], closeTo(6 + 7.2 * 6 / 52, 1e-9));
      expect(t['c'], closeTo(14 + 7.2 * 14 / 52, 1e-9));
      // edamame (4 + its part of the extras) is unclaimed
      expect(it.unclaimedTotal, closeTo(4, 1e-9));
      expect(t.values.fold(0.0, (a, b) => a + b),
          closeTo(it.total - 4 - 7.2 * 4 / 52, 1e-9));
    });

    test('over-claimed items are shared proportionally', () {
      var it = const ReceiptItemization(items: []).addItem(name: 'Pizza', quantity: 1, totalPrice: 30);
      it = it.setWeight(0, 'a', 2).setWeight(0, 'b', 1);
      final t = it.personTotals(['a', 'b']);
      expect(t['a'], closeTo(20, 1e-9));
      expect(t['b'], closeTo(10, 1e-9));
      expect(it.unclaimed, isEmpty);
    });

    test('toSplits rounds per currency and drops zero shares', () {
      final splits = dinner().toSplits(['a', 'b', 'c', 'd'], 'JPY');
      expect(splits.map((s) => s.memberId), ['a', 'b', 'c']);
      for (final s in splits) {
        expect(s.amount, s.amount.roundToDouble());
      }
    });

    test('assignUnclaimed fills empty and partial items', () {
      final it = dinner().assignUnclaimed(['a', 'b']);
      expect(it.unclaimed, isEmpty);
      expect(it.weightsFor(3), {'a': 0.5, 'b': 0.5});
    });

    test('json round trip keeps items and claims', () {
      final it = dinner();
      final back = ReceiptItemization.fromJsonOrNull(it.toJson())!;
      expect(back.items.length, 4);
      expect(back.tax, 5.2);
      expect(back.personTotals(['a', 'b', 'c']), it.personTotals(['a', 'b', 'c']));
    });

    test('fromSplits reproduces an amount split exactly', () {
      final it = ReceiptItemization.fromSplits(title: 'Taxi', amount: 30, splits: const [
        ReceiptSplit(memberId: 'a', amount: 10),
        ReceiptSplit(memberId: 'b', amount: 20),
      ]);
      final t = it.personTotals(['a', 'b']);
      expect(t['a'], closeTo(10, 1e-9));
      expect(t['b'], closeTo(20, 1e-9));
    });

    test('scan response becomes an unassigned itemization', () {
      final it = ReceiptItemization.fromScan({
        'title': 'Ichiran',
        'items': [
          {'name': 'Ramen', 'quantity': 2, 'unit_price': 1000, 'total_price': 2000},
        ],
        'subtotal': 2000, 'discount': 0, 'tax': 200, 'tip': 0, 'total': 2200,
      });
      expect(it.title, 'Ichiran');
      expect(it.items.single.quantity, 2);
      expect(it.total, 2200);
      expect(it.unclaimedTotal, 2000);
      expect(it.subtotalMismatch, isFalse);
    });
  });

  group('balances', () {
    Receipt r(String id, String payer, List<ReceiptSplit> splits, {String currency = 'JPY'}) => Receipt(
          id: id, title: id, amount: 3000, currency: currency, homeAmount: 27,
          exchangeRate: 0.009, transactionFeePct: 0, paidById: payer, splits: splits,
          category: ReceiptCategory.food, date: DateTime(2026, 10, 1),
        );
    const members = [TripMember(id: 'me', name: 'Me'), TripMember(id: 'sam', name: 'Sam')];

    test('settled shares no longer count', () {
      final receipts = [
        r('1', 'me', const [ReceiptSplit(memberId: 'me', amount: 1500), ReceiptSplit(memberId: 'sam', amount: 1500)]),
        r('2', 'sam', const [ReceiptSplit(memberId: 'me', amount: 500, isSettled: true)]),
        r('3', 'sam', const [ReceiptSplit(memberId: 'me', amount: 200)]),
      ];
      final b = calculateBalancesGrouped(receipts, const [], myId: 'me', members: members);
      expect(b['JPY']!.single.net, 1300);
    });

    test('openSharesBetween finds both directions in one currency', () {
      final receipts = [
        r('1', 'me', const [ReceiptSplit(memberId: 'sam', amount: 1500)]),
        r('2', 'sam', const [ReceiptSplit(memberId: 'me', amount: 500)]),
        r('3', 'sam', const [ReceiptSplit(memberId: 'me', amount: 500, isSettled: true)]),
        r('4', 'sam', const [ReceiptSplit(memberId: 'me', amount: 5)], currency: 'CAD'),
      ];
      final open = openSharesBetween(receipts, const [], a: 'sam', b: 'me', currency: 'JPY');
      expect(open.receiptShares, [('1', 'sam'), ('2', 'me')]);
    });
  });

  group('Receipts link', () {
    const members = [
      TripMember(id: 'a', name: 'Alex'),
      TripMember(id: 'b', name: 'Blair'),
      TripMember(id: 'c', name: 'Cam'),
    ];
    Receipt receipt() => Receipt(
          id: 'r1', title: 'Dinner', amount: dinner().total, currency: 'CAD',
          homeAmount: dinner().total, exchangeRate: 1, transactionFeePct: 0,
          paidById: 'a', category: ReceiptCategory.food, date: DateTime(2026, 10, 1),
          items: dinner(),
          splits: [
            ...dinner().toSplits(['a', 'b'], 'CAD'),
            ReceiptSplit(memberId: 'c', amount: dinner().toSplits(['c'], 'CAD').single.amount, isSettled: true),
          ],
        );

    test('payload → remote parse round trip maps people back to members', () {
      final rc = receipt();
      final order = ReceiptsLinkService.memberOrder(rc, members);
      final payload = ReceiptsLinkService.buildPayload(receipt: rc, members: members, order: order);
      expect((payload['people'] as List).length, 3);
      expect(payload['paid'], {'0': true, '2': true}); // payer + settled share
      // The Receipts site formats amounts in it (¥8,570, not $8570.00).
      expect((payload['receipt'] as Map)['currency'], rc.currency);
      final linked = rc.copyWith(splitLinkId: 'x', splitLinkMembers: order,
          splitLinkHash: ReceiptsLinkService.hashOf(payload));
      final remote = ReceiptsLinkService.parseRemote(payload, linked, members);
      expect(remote.hash, linked.splitLinkHash);
      expect(remote.paidMemberIds, {'a', 'c'});
      expect(remote.items.personTotals(['a', 'b', 'c']), dinner().personTotals(['a', 'b', 'c']));
      expect(remote.unknownPeople, isEmpty);
    });

    test('hash ignores jsonb key order / number formatting but sees claim changes', () {
      final rc = receipt();
      final order = ReceiptsLinkService.memberOrder(rc, members);
      final payload = ReceiptsLinkService.buildPayload(receipt: rc, members: members, order: order);
      final h = ReceiptsLinkService.hashOf(payload);
      // As it comes back from Postgres: keys reordered, 1.0 → 1
      final reordered = {
        'paid': payload['paid'],
        'assignments': {
          for (final e in (payload['assignments'] as Map).entries)
            e.key: {for (final w in (e.value as Map).entries) w.key: (w.value as num) == (w.value as num).roundToDouble() ? (w.value as num).toInt() : w.value},
        },
        'people': payload['people'],
        'receipt': payload['receipt'],
      };
      expect(ReceiptsLinkService.hashOf(reordered), h);
      final claimed = {
        ...reordered,
        'assignments': {...reordered['assignments'] as Map, '3': {'1': 1}},
      };
      expect(ReceiptsLinkService.hashOf(claimed), isNot(h));
    });

    test('people added on the site map by name, strangers are reported', () {
      final rc = receipt().copyWith(splitLinkId: 'x', splitLinkMembers: ['a', 'b']);
      final raw = {
        'receipt': dinner().toJson(),
        'people': [
          {'id': 0, 'name': 'Alex'}, {'id': 1, 'name': 'Blair'},
          {'id': 2, 'name': 'cam'}, {'id': 3, 'name': 'Dana'},
        ],
        'assignments': {'3': {'2': 1}, '1': {'3': 1}},
        'paid': {'2': true},
      };
      final remote = ReceiptsLinkService.parseRemote(raw, rc, members);
      expect(remote.items.weightsFor(3), {'c': 1});
      expect(remote.items.weightsFor(1), isEmpty);
      expect(remote.paidMemberIds, {'c'});
      expect(remote.unknownPeople, ['Dana']);
    });
  });
}
