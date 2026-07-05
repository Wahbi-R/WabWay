import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase/money_service.dart';
import '../data/money_data.dart';

/// Queues failed receipt creates so they can be replayed when connectivity returns.
abstract final class SyncQueue {
  static const _prefix = 'sync_queue_receipts_';

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

  static Future<void> enqueueReceipt(String tripId, Map<String, dynamic> payload) async {
    final list = await _pending(tripId);
    list.add(payload);
    await _save(tripId, list);
  }

  /// Drain queued receipts for [tripId]. Removes successfully replayed entries.
  static Future<void> drain(String tripId, String userId) async {
    final list = await _pending(tripId);
    if (list.isEmpty) return;

    final failed = <Map<String, dynamic>>[];
    for (final item in list) {
      try {
        await MoneyService.createReceipt(
          tripId:   tripId,
          paidBy:   userId,
          title:    item['title'] as String,
          amount:   (item['amount'] as num).toDouble(),
          currency: item['currency'] as String? ?? 'USD',
          category: ReceiptCategory.other,
          date:     DateTime.tryParse(item['date'] as String? ?? '') ?? DateTime.now(),
          splits:   [ReceiptSplit(memberId: userId, amount: (item['amount'] as num).toDouble())],
        );
      } catch (_) {
        failed.add(item);
      }
    }
    await _save(tripId, failed);
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
