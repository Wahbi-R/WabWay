import '../../data/money_data.dart';
import 'client.dart';

abstract final class SettlementService {
  static Settlement _fromRow(Map<String, dynamic> row) => Settlement(
        id:             row['id'] as String,
        tripId:         row['trip_id'] as String,
        fromMemberId:   row['from_member_id'] as String,
        toMemberId:     row['to_member_id'] as String,
        amount:         (row['amount'] as num).toDouble(),
        currency:       row['currency'] as String,
        settledAt:      DateTime.parse(row['settled_at'] as String),
        settledBy:      row['settled_by'] as String,
        note:           row['note'] as String?,
      );

  static Future<List<Settlement>> loadSettlements(String tripId) async {
    final data = await supabase
        .from('settlements')
        .select()
        .eq('trip_id', tripId)
        .order('settled_at', ascending: false);
    return data.map(_fromRow).toList();
  }

  static Future<Settlement> createSettlement({
    required String tripId,
    required String fromMemberId,
    required String toMemberId,
    required double amount,
    required String currency,
    required String settledBy,
    String? note,
  }) async {
    final row = await supabase.from('settlements').insert({
      'trip_id':        tripId,
      'from_member_id': fromMemberId,
      'to_member_id':   toMemberId,
      'amount':         amount,
      'currency':       currency,
      'settled_by':     settledBy,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }).select().single();
    return _fromRow(row);
  }

  /// Record that [fromMemberId] paid [toMemberId] and mark every open share
  /// between them in [currency] (both directions, receipts and cash) as
  /// settled by this payment.
  static Future<Settlement> settleAll({
    required String tripId,
    required String fromMemberId,
    required String toMemberId,
    required double amount,
    required String currency,
    required String settledBy,
    required OpenShares shares,
    String? note,
  }) async {
    final settlement = await createSettlement(
      tripId:       tripId,
      fromMemberId: fromMemberId,
      toMemberId:   toMemberId,
      amount:       amount,
      currency:     currency,
      settledBy:    settledBy,
      note:         note,
    );
    final patch = {
      'is_settled':    true,
      'settled_at':    settlement.settledAt.toUtc().toIso8601String(),
      'settlement_id': settlement.id,
    };
    try {
      for (final (receiptId, memberId) in shares.receiptShares) {
        await supabase.from('receipt_splits').update(patch)
            .eq('receipt_id', receiptId).eq('user_id', memberId);
      }
      for (final (withdrawalId, memberId) in shares.cashShares) {
        await supabase.from('cash_distributions').update(patch)
            .eq('withdrawal_id', withdrawalId).eq('user_id', memberId);
      }
    } catch (e) {
      // Don't leave a payment on record that didn't clear anything.
      await undoSettlement(settlement.id);
      rethrow;
    }
    return settlement;
  }

  /// Undo a Settle Up payment: reopen the shares it settled, then delete it.
  static Future<void> undoSettlement(String settlementId) async {
    const reopen = {'is_settled': false, 'settled_at': null, 'settlement_id': null};
    await supabase.from('receipt_splits').update(reopen).eq('settlement_id', settlementId);
    await supabase.from('cash_distributions').update(reopen).eq('settlement_id', settlementId);
    await deleteSettlement(settlementId);
  }

  static Future<void> deleteSettlement(String settlementId) async {
    await supabase.from('settlements').delete().eq('id', settlementId);
  }
}
