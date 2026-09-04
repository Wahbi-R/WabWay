import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase/money_service.dart';
import '../data/money_data.dart';

/// Queues failed receipt creates so they can be replayed when connectivity returns.
abstract final class SyncQueue {
  static const _prefix = 'sync_queue_receipts_';
  static bool _draining = false;

  static String _key(String tripId) => '$_prefix$tripId';

  static Future<List<Map<String, dynamic>>> _pending(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(tripId));
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _save(String tripId, List<Map<String, dynamic>> items) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (items.isEmpty) {
        await prefs.remove(_key(tripId));
      } else {
        await prefs.setString(_key(tripId), jsonEncode(items));
      }
    } catch (_) {}
  }

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
  }) async {
    final list = await _pending(tripId);
    list.add({
      'paidBy': paidBy,
      'title': title,
      'amount': amount,
      'currency': currency,
      'homeAmount': homeAmount,
      'exchangeRate': exchangeRate,
      'transactionFeePct': transactionFeePct,
      'category': category.name,
      'date': date.toIso8601String(),
      'notes': notes,
      'splits': splits.map((s) => {'memberId': s.memberId, 'amount': s.amount}).toList(),
    });
    await _save(tripId, list);
  }

  /// Drain queued receipts for [tripId]. Removes successfully replayed entries.
  static Future<void> drain(String tripId, String userId) async {
    if (_draining) return;
    _draining = true;
    try {
    final list = await _pending(tripId);
    if (list.isEmpty) { _draining = false; return; }

    final failed = <Map<String, dynamic>>[];
    for (final item in list) {
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
          rawSplits = [ReceiptSplit(memberId: paidBy, amount: homeAmount)];
        }
        final category = ReceiptCategory.values.firstWhere(
          (c) => c.name == item['category'],
          orElse: () => ReceiptCategory.other,
        );
        await MoneyService.createReceipt(
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
        );
      } catch (_) {
        failed.add(item);
      }
    }
    await _save(tripId, failed);
    } finally {
      _draining = false;
    }
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
