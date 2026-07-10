import '../offline_cache.dart';
import '../../data/date_utils.dart';
import '../../data/money_data.dart';
import 'client.dart';

abstract final class MoneyService {
  // ── Category converters ──────────────────────────────────────────────────────

  static ReceiptCategory _catFrom(String s) => switch (s) {
        'food'          => ReceiptCategory.food,
        'transport'     => ReceiptCategory.transport,
        'accommodation' => ReceiptCategory.accommodation,
        'activity'      => ReceiptCategory.activity,
        'shopping'      => ReceiptCategory.shopping,
        _               => ReceiptCategory.other,
      };

  static String _catToDb(ReceiptCategory c) => switch (c) {
        ReceiptCategory.food          => 'food',
        ReceiptCategory.transport     => 'transport',
        ReceiptCategory.accommodation => 'accommodation',
        ReceiptCategory.activity      => 'activity',
        ReceiptCategory.shopping      => 'shopping',
        ReceiptCategory.other         => 'other',
      };

  // ── Row mappers ──────────────────────────────────────────────────────────────

  static Receipt _receiptFromRow(Map<String, dynamic> row) {
    final splitsRaw = row['receipt_splits'] as List? ?? [];
    final splits = splitsRaw.map((s) {
      final split = s as Map<String, dynamic>;
      return ReceiptSplit(
        memberId:  split['user_id'] as String,
        amount:    (split['amount'] as num).toDouble(),
        isSettled: split['is_settled'] as bool? ?? false,
      );
    }).toList();
    final rawAmount = (row['amount'] as num).toDouble();
    return Receipt(
      id:                row['id'] as String,
      title:             row['title'] as String,
      amount:            rawAmount,
      currency:          row['currency'] as String,
      homeAmount:        (row['home_amount'] as num?)?.toDouble() ?? rawAmount,
      exchangeRate:      (row['exchange_rate'] as num?)?.toDouble() ?? 1.0,
      transactionFeePct: (row['transaction_fee_pct'] as num?)?.toDouble() ?? 0.0,
      paidById:          row['paid_by'] as String,
      category:          _catFrom(row['category'] as String),
      date:              DateTime.parse(row['date'] as String),
      notes:             row['notes'] as String?,
      storagePath:       row['storage_path'] as String?,
      splits:            splits,
    );
  }

  static CashWithdrawal _withdrawalFromRow(Map<String, dynamic> row) {
    final distsRaw = row['cash_distributions'] as List? ?? [];
    final dists = distsRaw.map((d) {
      final dist = d as Map<String, dynamic>;
      return CashDistribution(
        memberId: dist['user_id'] as String,
        amount:   (dist['amount'] as num).toDouble(),
      );
    }).toList();
    return CashWithdrawal(
      id:           row['id'] as String,
      withdrawnById: row['withdrawn_by'] as String,
      amount:       (row['amount'] as num).toDouble(),
      currency:     row['currency'] as String,
      atmFee:       (row['atm_fee'] as num?)?.toDouble() ?? 0,
      date:         DateTime.parse(row['date'] as String),
      notes:        row['notes'] as String?,
      distributions: dists,
    );
  }

  // ── Queries ──────────────────────────────────────────────────────────────────

  static Future<List<Receipt>> loadReceipts(String tripId) async {
    final data = await supabase
        .from('receipts')
        .select('*, receipt_splits(*)')
        .eq('trip_id', tripId)
        .order('date', ascending: false);
    final receipts = data.map<Receipt>((r) => _receiptFromRow(r)).toList();
    await OfflineCache.write(
      OfflineCache.moneyReceiptsKey(tripId),
      data,
    );
    return receipts;
  }

  static Future<List<Receipt>?> loadReceiptsFromCache(String tripId) {
    return OfflineCache.read<List<Receipt>>(
      OfflineCache.moneyReceiptsKey(tripId),
      (json) => (json as List)
          .map<Receipt>((r) => _receiptFromRow(Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }

  static Future<List<CashWithdrawal>> loadWithdrawals(String tripId) async {
    final data = await supabase
        .from('cash_withdrawals')
        .select('*, cash_distributions(*)')
        .eq('trip_id', tripId)
        .order('date', ascending: false);
    final withdrawals = data.map<CashWithdrawal>((r) => _withdrawalFromRow(r)).toList();
    await OfflineCache.write(
      OfflineCache.moneyWithdrawalsKey(tripId),
      data,
    );
    return withdrawals;
  }

  static Future<List<CashWithdrawal>?> loadWithdrawalsFromCache(String tripId) {
    return OfflineCache.read<List<CashWithdrawal>>(
      OfflineCache.moneyWithdrawalsKey(tripId),
      (json) => (json as List)
          .map<CashWithdrawal>((r) => _withdrawalFromRow(Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }

  // ── Mutations ─────────────────────────────────────────────────────────────────

  static Future<Receipt> createReceipt({
    required String tripId,
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
    final receipt = await supabase.from('receipts').insert({
      'trip_id':              tripId,
      'title':                title.trim(),
      'amount':               amount,
      'currency':             currency,
      'home_amount':          homeAmount,
      'exchange_rate':        exchangeRate,
      'transaction_fee_pct':  transactionFeePct,
      'paid_by':              paidBy,
      'category':             _catToDb(category),
      'date':                 isoDate(date),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }).select().single();

    final receiptId = receipt['id'] as String;
    final validSplits = splits.where((s) => s.amount > 0).toList();
    if (validSplits.isNotEmpty) {
      await supabase.from('receipt_splits').insert(
        validSplits.map((s) => {
          'receipt_id': receiptId,
          'user_id':    s.memberId,
          'amount':     s.amount,
        }).toList(),
      );
    }

    final full = await supabase
        .from('receipts')
        .select('*, receipt_splits(*)')
        .eq('id', receiptId)
        .single();
    return _receiptFromRow(full);
  }

  static Future<CashWithdrawal> createWithdrawal({
    required String tripId,
    required String withdrawnBy,
    required double amount,
    required String currency,
    required double atmFee,
    required DateTime date,
    required List<CashDistribution> distributions,
    String? notes,
  }) async {
    final withdrawal = await supabase.from('cash_withdrawals').insert({
      'trip_id':      tripId,
      'withdrawn_by': withdrawnBy,
      'amount':       amount,
      'currency':     currency,
      'atm_fee':      atmFee,
      'date':         isoDate(date),
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }).select().single();

    final withdrawalId = withdrawal['id'] as String;
    final validDists = distributions.where((d) => d.amount > 0).toList();
    if (validDists.isNotEmpty) {
      await supabase.from('cash_distributions').insert(
        validDists.map((d) => {
          'withdrawal_id': withdrawalId,
          'user_id':       d.memberId,
          'amount':        d.amount,
        }).toList(),
      );
    }

    final full = await supabase
        .from('cash_withdrawals')
        .select('*, cash_distributions(*)')
        .eq('id', withdrawalId)
        .single();
    return _withdrawalFromRow(full);
  }

  static Future<Receipt> updateReceipt({
    required String receiptId,
    required String title,
    required double amount,
    required String currency,
    required double homeAmount,
    required double exchangeRate,
    required double transactionFeePct,
    required ReceiptCategory category,
    required String paidBy,
    required DateTime date,
    required List<ReceiptSplit> splits,
    String? notes,
  }) async {
    await supabase.from('receipts').update({
      'title':               title.trim(),
      'amount':              amount,
      'currency':            currency,
      'home_amount':         homeAmount,
      'exchange_rate':       exchangeRate,
      'transaction_fee_pct': transactionFeePct,
      'paid_by':             paidBy,
      'category':            _catToDb(category),
      'date':                isoDate(date),
      'notes':               (notes != null && notes.isNotEmpty) ? notes : null,
    }).eq('id', receiptId);

    for (final split in splits) {
      await supabase
          .from('receipt_splits')
          .update({'amount': split.amount})
          .eq('receipt_id', receiptId)
          .eq('user_id', split.memberId);
    }

    final full = await supabase
        .from('receipts')
        .select('*, receipt_splits(*)')
        .eq('id', receiptId)
        .single();
    return _receiptFromRow(full);
  }

  static Future<void> deleteReceipt(String receiptId) async {
    await supabase.from('receipt_splits').delete().eq('receipt_id', receiptId);
    await supabase.from('receipts').delete().eq('id', receiptId);
  }

  static Future<void> deleteWithdrawal(String withdrawalId) async {
    await supabase.from('cash_distributions').delete().eq('withdrawal_id', withdrawalId);
    await supabase.from('cash_withdrawals').delete().eq('id', withdrawalId);
  }

}
