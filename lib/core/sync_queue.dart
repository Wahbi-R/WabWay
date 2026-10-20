import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/notification_settings_screen.dart' show kPrefNotifMoney;
import 'notifications/push_notifier.dart';
import 'platform/platform_file.dart';
import 'receipt_followups.dart';
import 'receipt_scan_service.dart';
import 'receipts_link_service.dart';
import 'supabase/money_service.dart';
import 'supabase/trip_service.dart';
import 'trip_data_changes.dart';
import '../data/connection_data.dart' show EntityType;
import '../data/money_data.dart';

/// Offline queue for money: receipts created without a connection (with their
/// items, photos and "create link" choice), plus small follow-up operations —
/// publishing a Receipts link and marking shares paid. Replayed on reconnect.
abstract final class SyncQueue {
  static const _prefix = 'sync_queue_receipts_';
  static const _opsPrefix = 'sync_queue_money_ops_';
  static final Set<String> _drainingTrips = {};

  /// The queue changed (something queued, synced or discarded): screens
  /// showing queued receipts refresh via [TripDataChanges].
  static void _changed() => TripDataChanges.touch(const [EntityType.receipt]);

  /// Id prefix of queued (not yet uploaded) receipts — see [pendingReceipts].
  static const pendingIdPrefix = 'pending-';

  static String _key(String tripId) => '$_prefix$tripId';
  static String _opsKey(String tripId) => '$_opsPrefix$tripId';

  static Future<List<Map<String, dynamic>>> _read(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _write(String key, List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (items.isEmpty) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, jsonEncode(items));
      }
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> _pending(String tripId) => _read(_key(tripId));

  static Future<void> enqueueReceipt(String tripId, {
    required String paidBy,
    required String title,
    required double amount,
    required String currency,
    required double homeAmount,
    required double exchangeRate,
    required double transactionFeePct,
    required ReceiptCategory category,
    required DateTime date,
    required List<ReceiptSplit> splits,
    String? notes,
    ReceiptItemization? items,
    List<ScanImage> photos = const [],
    Iterable<String> docIds = const [],
    bool createLink = false,
    bool homeAmountSet = false,
  }) async {
    // Photos go to files (not prefs) so they survive a restart.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final photoFiles = <Map<String, String>>[];
    for (var i = 0; i < photos.length; i++) {
      final path = await writeAppFile(
          'pending_receipt_photos/${stamp}_$i.${photos[i].ext}', photos[i].bytes);
      if (path != null) photoFiles.add({'path': path, 'ext': photos[i].ext});
    }
    final list = await _pending(tripId);
    list.add({
      'localId': '$stamp',
      'paidBy': paidBy,
      'title': title,
      'amount': amount,
      'currency': currency,
      'homeAmount': homeAmount,
      'exchangeRate': exchangeRate,
      'transactionFeePct': transactionFeePct,
      if (homeAmountSet) 'homeAmountSet': true,
      'category': category.name,
      'date': date.toIso8601String(),
      'notes': notes,
      'splits': splits.map((s) => {'memberId': s.memberId, 'amount': s.amount}).toList(),
      if (items != null && !items.isEmpty) 'items': items.toJson(),
      if (photoFiles.isNotEmpty) 'photos': photoFiles,
      if (docIds.isNotEmpty) 'docIds': docIds.toList(),
      'createLink': createLink,
    });
    await _write(_key(tripId), list);
    _changed();
  }

  static String _localIdOf(Map<String, dynamic> item, int index) =>
      item['localId'] as String? ?? 'legacy$index';

  /// Receipts saved offline on this phone, as [Receipt]s for the list (ids
  /// start with [pendingIdPrefix]). They count in balances straight away.
  static Future<List<Receipt>> pendingReceipts(String tripId) async {
    final list = await _pending(tripId);
    final out = <Receipt>[];
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      try {
        final paidBy = item['paidBy'] as String? ?? '';
        final amount = (item['amount'] as num).toDouble();
        out.add(Receipt(
          id:                '$pendingIdPrefix${_localIdOf(item, i)}',
          title:             item['title'] as String? ?? 'Receipt',
          amount:            amount,
          currency:          item['currency'] as String? ?? 'USD',
          homeAmount:        (item['homeAmount'] as num?)?.toDouble() ?? amount,
          exchangeRate:      (item['exchangeRate'] as num?)?.toDouble() ?? 1.0,
          transactionFeePct: (item['transactionFeePct'] as num?)?.toDouble() ?? 0.0,
          homeAmountSet:     item['homeAmountSet'] as bool? ?? false,
          paidById:          paidBy,
          category:          ReceiptCategory.values.firstWhere(
            (c) => c.name == item['category'],
            orElse: () => ReceiptCategory.other,
          ),
          date:              DateTime.tryParse(item['date'] as String? ?? '') ?? DateTime.now(),
          notes:             item['notes'] as String?,
          items:             ReceiptItemization.fromJsonOrNull(item['items']),
          splits: [
            for (final s in (item['splits'] as List?) ?? const [])
              if (((s as Map)['amount'] as num) > 0)
                ReceiptSplit(memberId: s['memberId'] as String, amount: (s['amount'] as num).toDouble()),
          ],
        ));
      } catch (_) {}
    }
    return out;
  }

  /// Throw away a receipt that was saved offline and hasn't synced yet.
  static Future<void> discardPending(String tripId, String receiptId) async {
    final localId = receiptId.replaceFirst(pendingIdPrefix, '');
    final list = await _pending(tripId);
    final keep = <Map<String, dynamic>>[];
    for (var i = 0; i < list.length; i++) {
      if (_localIdOf(list[i], i) == localId) {
        for (final p in (list[i]['photos'] as List?) ?? const []) {
          await deleteAppFile((p as Map)['path'] as String);
        }
      } else {
        keep.add(list[i]);
      }
    }
    await _write(_key(tripId), keep);
    _changed();
  }

  /// Publish a Receipts link for an already-saved receipt when back online.
  static Future<void> enqueueLink(String tripId, String receiptId) async {
    final ops = await _read(_opsKey(tripId));
    if (ops.any((o) => o['op'] == 'link' && o['receiptId'] == receiptId)) return;
    ops.add({'op': 'link', 'receiptId': receiptId});
    await _write(_opsKey(tripId), ops);
    _changed();
  }

  /// Mark a share paid / open again when back online. A later toggle of the
  /// same share replaces an earlier one.
  static Future<void> enqueueSettleShare(String tripId, {
    required String receiptId,
    required String memberId,
    required bool settled,
  }) async {
    final ops = (await _read(_opsKey(tripId)))
      ..removeWhere((o) => o['op'] == 'settle' && o['receiptId'] == receiptId && o['memberId'] == memberId);
    ops.add({
      'op': 'settle',
      'receiptId': receiptId,
      'memberId': memberId,
      'settled': settled,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    await _write(_opsKey(tripId), ops);
    _changed();
  }

  /// Receipt ids waiting for a Receipts link.
  static Future<Set<String>> pendingLinkIds(String tripId) async => {
        for (final o in await _read(_opsKey(tripId)))
          if (o['op'] == 'link') o['receiptId'] as String,
      };

  /// Queued share toggles: receiptId → memberId → settled.
  static Future<Map<String, Map<String, bool>>> pendingSettles(String tripId) async {
    final out = <String, Map<String, bool>>{};
    for (final o in await _read(_opsKey(tripId))) {
      if (o['op'] != 'settle') continue;
      (out[o['receiptId'] as String] ??= {})[o['memberId'] as String] = o['settled'] as bool;
    }
    return out;
  }

  /// [receipts] with shares toggled offline shown as they will be once synced.
  static Future<List<Receipt>> withPendingSettles(String tripId, List<Receipt> receipts) async {
    final pending = await pendingSettles(tripId);
    if (pending.isEmpty) return receipts;
    return [
      for (final r in receipts)
        pending[r.id] == null
            ? r
            : r.copyWith(splits: [
                for (final sp in r.splits)
                  pending[r.id]![sp.memberId] == null
                      ? sp
                      : sp.copyWith(
                          isSettled: pending[r.id]![sp.memberId],
                          settledAt: DateTime.now(),
                        ),
              ]),
    ];
  }

  static Future<bool> hasPendingOps(String tripId) async =>
      (await _read(_opsKey(tripId))).isNotEmpty;

  /// Replay everything queued for [tripId]. Successful entries are removed.
  /// [members] are needed to publish Receipts links (names on the link).
  static Future<void> drain(String tripId, String userId, {List<TripMember> members = const []}) async {
    if (_drainingTrips.contains(tripId)) return;
    _drainingTrips.add(tripId);
    try {
      final home = await _homeCurrency(tripId);
      await _drainReceipts(tripId, userId, members, home);
      await _drainOps(tripId, members, home);
    } finally {
      _drainingTrips.remove(tripId);
      _changed();
    }
  }

  /// The trip's home currency, for the Receipts link's "≈ C\$…" (null if
  /// it can't be looked up — the link then shows one currency).
  static Future<String?> _homeCurrency(String tripId) async {
    try {
      return (await TripService.loadUserTrips())
          .where((t) => t.id == tripId)
          .firstOrNull
          ?.homeCurrency;
    } catch (_) {
      return null;
    }
  }

  /// Trips with anything queued on this phone.
  static Future<Set<String>> pendingTripIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        for (final key in prefs.getKeys())
          if (key.startsWith(_prefix) && (prefs.getString(key) ?? '[]') != '[]')
            key.substring(_prefix.length)
          else if (key.startsWith(_opsPrefix) && (prefs.getString(key) ?? '[]') != '[]')
            key.substring(_opsPrefix.length),
      };
    } catch (_) {
      return {};
    }
  }

  /// Replay the queues of EVERY trip (not just the open one) — called when
  /// the app starts with a connection and whenever it comes back online.
  static Future<void> drainAll(String userId) async {
    if (userId.isEmpty) return;
    for (final tripId in await pendingTripIds()) {
      var members = const <TripMember>[];
      try {
        members = [
          for (final m in await TripService.loadTripMembers(tripId))
            TripMember(id: m.userId, name: m.profile.displayName, isMe: m.userId == userId),
        ];
      } catch (_) {
        continue; // still offline (or not a member any more) — try next time
      }
      await drain(tripId, userId, members: members);
    }
  }

  static Future<void> _drainReceipts(
      String tripId, String userId, List<TripMember> members, String? homeCurrency) async {
    final list = await _pending(tripId);
    if (list.isEmpty) return;

    for (final item in list) {
      final Receipt receipt;
      try {
        final paidBy     = item['paidBy'] as String? ?? userId;
        final homeAmount = (item['homeAmount'] as num?)?.toDouble()
            ?? (item['amount'] as num).toDouble();
        var rawSplits = (item['splits'] as List?)
            ?.map((s) => ReceiptSplit(
                  memberId: s['memberId'] as String,
                  amount: (s['amount'] as num).toDouble(),
                ))
            .toList() ?? [];
        // Guard against empty splits (older payloads or corrupted cache) by
        // falling back to a single split covering the full amount for the payer.
        if (rawSplits.isEmpty) {
          rawSplits = [ReceiptSplit(memberId: paidBy, amount: (item['amount'] as num).toDouble())];
        }
        final category = ReceiptCategory.values.firstWhere(
          (c) => c.name == item['category'],
          orElse: () => ReceiptCategory.other,
        );
        receipt = await MoneyService.createReceipt(
          tripId:            tripId,
          paidBy:            paidBy,
          title:             item['title'] as String,
          amount:            (item['amount'] as num).toDouble(),
          currency:          item['currency'] as String? ?? 'USD',
          homeAmount:        homeAmount,
          exchangeRate:      (item['exchangeRate'] as num?)?.toDouble() ?? 1.0,
          transactionFeePct: (item['transactionFeePct'] as num?)?.toDouble() ?? 0.0,
          category:          category,
          date:              DateTime.tryParse(item['date'] as String? ?? '') ?? DateTime.now(),
          splits:            rawSplits,
          notes:             item['notes'] as String?,
          items:             ReceiptItemization.fromJsonOrNull(item['items']),
          homeAmountSet:     item['homeAmountSet'] as bool? ?? false,
        );
      } catch (_) {
        continue; // stays queued
      }
      // Uploaded: take it off the queue right away (not after the whole
      // batch) so the list never shows it twice and a crash can't re-upload it.
      final remaining = (await _pending(tripId))
        ..removeWhere((q) => jsonEncode(q) == jsonEncode(item));
      await _write(_key(tripId), remaining);
      _changed();
      // Same notification the form sends when a receipt is added online.
      unawaited(pushNotify(
        tripId: tripId,
        title: 'New receipt added',
        body: '${receipt.title} · ${receipt.currency} ${receipt.amount.toStringAsFixed(2)}',
        excludeUserId: userId,
        data: {'screen': 'money', 'trip_id': tripId},
        prefKey: kPrefNotifMoney,
      ));
      // The receipt exists now — follow-ups are best-effort and never re-create it.
      final photoFiles = ((item['photos'] as List?) ?? const [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
      final photos = <ScanImage>[];
      for (final p in photoFiles) {
        try {
          final bytes = await readFileAsBytes(p['path'] as String);
          if (bytes.isNotEmpty) photos.add(ScanImage(bytes, p['ext'] as String? ?? 'jpg'));
        } catch (_) {}
      }
      try {
        await runReceiptFollowups(
          tripId:     tripId,
          userId:     userId,
          receipt:    receipt,
          members:    members,
          photos:     photos,
          docIds:     ((item['docIds'] as List?) ?? const []).cast<String>(),
          createLink: item['createLink'] == true && members.isNotEmpty,
          homeCurrency: homeCurrency,
        );
        if (item['createLink'] == true && members.isEmpty) await enqueueLink(tripId, receipt.id);
      } catch (_) {}
      for (final p in photoFiles) {
        await deleteAppFile(p['path'] as String);
      }
    }
  }

  static Future<void> _drainOps(String tripId, List<TripMember> members, String? homeCurrency) async {
    final ops = await _read(_opsKey(tripId));
    if (ops.isEmpty) return;
    final failed = <Map<String, dynamic>>[];
    for (final o in ops) {
      try {
        switch (o['op']) {
          case 'settle':
            await MoneyService.setShareSettled(
              receiptId: o['receiptId'] as String,
              memberId:  o['memberId'] as String,
              settled:   o['settled'] as bool,
              at:        DateTime.tryParse(o['at'] as String? ?? ''),
            );
          case 'link':
            if (members.isEmpty) { failed.add(o); continue; }
            final receipt = await MoneyService.loadReceipt(o['receiptId'] as String);
            if (receipt != null) {
              await ReceiptsLinkService.create(receipt, members, homeCurrency: homeCurrency);
            }
        }
      } catch (_) {
        failed.add(o);
      }
    }
    // Anything queued while draining is kept too.
    final now = await _read(_opsKey(tripId));
    final extra = now.where((o) => !ops.any((x) => jsonEncode(x) == jsonEncode(o)));
    await _write(_opsKey(tripId), [...failed, ...extra]);
  }

  static Future<int> pendingCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int total = 0;
      for (final key in prefs.getKeys()) {
        if (key.startsWith(_prefix)) {
          final raw = prefs.getString(key);
          if (raw != null) {
            total += (jsonDecode(raw) as List).length;
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  static Future<int> pendingCountFor(String tripId) async {
    return (await _pending(tripId)).length;
  }
}
