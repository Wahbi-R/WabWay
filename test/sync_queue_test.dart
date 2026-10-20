import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wabway/core/sync_queue.dart';
import 'package:wabway/data/money_data.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> queue(String title) => SyncQueue.enqueueReceipt(
        'trip1',
        paidBy: 'me',
        title: title,
        amount: 3000,
        currency: 'JPY',
        homeAmount: 27,
        exchangeRate: 0.009,
        transactionFeePct: 0,
        category: ReceiptCategory.food,
        date: DateTime(2026, 10, 20),
        splits: const [
          ReceiptSplit(memberId: 'me', amount: 1500),
          ReceiptSplit(memberId: 'sam', amount: 1500),
        ],
        createLink: true,
      );

  test('receipts saved offline are listed, count in balances, and can be discarded', () async {
    final before = SyncQueue.changes.value;
    await queue('Ramen');
    await queue('Taxi');
    expect(SyncQueue.changes.value, greaterThan(before));

    final pending = await SyncQueue.pendingReceipts('trip1');
    expect(pending.map((r) => r.title), ['Ramen', 'Taxi']);
    expect(pending.every((r) => r.isPending), isTrue);
    expect(await SyncQueue.pendingTripIds(), {'trip1'});

    final balances = calculateBalancesGrouped(pending, const [], myId: 'me',
        members: const [TripMember(id: 'me', name: 'Me'), TripMember(id: 'sam', name: 'Sam')]);
    expect(balances['JPY']!.single.net, 3000);

    await SyncQueue.discardPending('trip1', pending.first.id);
    expect((await SyncQueue.pendingReceipts('trip1')).map((r) => r.title), ['Taxi']);
    expect(await SyncQueue.pendingCountFor('trip1'), 1);
  });
}
