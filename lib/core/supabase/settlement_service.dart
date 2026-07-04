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

  static Future<void> deleteSettlement(String settlementId) async {
    await supabase.from('settlements').delete().eq('id', settlementId);
  }
}
