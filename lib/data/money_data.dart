import 'package:flutter/material.dart';
import 'member_data.dart';
import 'receipt_items.dart';
export 'member_data.dart';
export 'receipt_items.dart';
export 'date_utils.dart' show fmtDate;

// ─── Receipt ──────────────────────────────────────────────────────────────────

enum ReceiptCategory {
  food, transport, accommodation, activity, shopping, other;

  String get label => switch (this) {
    ReceiptCategory.food          => 'Food',
    ReceiptCategory.transport     => 'Transport',
    ReceiptCategory.accommodation => 'Stay',
    ReceiptCategory.activity      => 'Activity',
    ReceiptCategory.shopping      => 'Shopping',
    ReceiptCategory.other         => 'Other',
  };

  IconData get icon => switch (this) {
    ReceiptCategory.food          => Icons.restaurant_rounded,
    ReceiptCategory.transport     => Icons.train_rounded,
    ReceiptCategory.accommodation => Icons.hotel_rounded,
    ReceiptCategory.activity      => Icons.local_activity_rounded,
    ReceiptCategory.shopping      => Icons.shopping_bag_rounded,
    ReceiptCategory.other         => Icons.receipt_long_rounded,
  };

  Color get color => switch (this) {
    ReceiptCategory.food          => const Color(0xFFC96F4A),
    ReceiptCategory.transport     => const Color(0xFF7D9A75),
    ReceiptCategory.accommodation => const Color(0xFFD6A84F),
    ReceiptCategory.activity      => const Color(0xFF7B8EC8),
    ReceiptCategory.shopping      => const Color(0xFFA97BB5),
    ReceiptCategory.other         => const Color(0xFF6F665D),
  };

  Color get softColor => switch (this) {
    ReceiptCategory.food          => const Color(0xFFF7EDE7),
    ReceiptCategory.transport     => const Color(0xFFEEF4EC),
    ReceiptCategory.accommodation => const Color(0xFFF8F0E2),
    ReceiptCategory.activity      => const Color(0xFFEEF0F8),
    ReceiptCategory.shopping      => const Color(0xFFF5EEF7),
    ReceiptCategory.other         => const Color(0xFFEEEAE3),
  };
}

/// One person's share of a receipt, in the receipt's currency.
///
/// Shares are the source of truth for who owes whom: an open share counts in
/// balances, a settled one doesn't. [settlementId] is set when the share was
/// settled as part of a Settle Up payment (undoing that payment reopens it).
class ReceiptSplit {
  const ReceiptSplit({
    required this.memberId,
    required this.amount,
    this.isSettled = false,
    this.settledAt,
    this.settlementId,
  });
  final String memberId;
  final double amount;
  final bool isSettled;
  final DateTime? settledAt;
  final String? settlementId;

  ReceiptSplit copyWith({bool? isSettled, DateTime? settledAt, String? settlementId}) =>
      ReceiptSplit(
        memberId:     memberId,
        amount:       amount,
        isSettled:    isSettled ?? this.isSettled,
        settledAt:    (isSettled ?? this.isSettled) ? (settledAt ?? this.settledAt) : null,
        settlementId: (isSettled ?? this.isSettled) ? (settlementId ?? this.settlementId) : null,
      );
}

class Receipt {
  const Receipt({
    required this.id,
    required this.title,
    required this.amount,
    required this.currency,
    required this.homeAmount,
    required this.exchangeRate,
    required this.transactionFeePct,
    required this.paidById,
    required this.splits,
    required this.category,
    required this.date,
    this.notes,
    this.storagePath,
    this.items,
    this.splitLinkId,
    this.splitLinkMembers = const [],
    this.splitLinkHash,
    this.createdById,
  });

  final String id;
  final String title;
  /// Original amount in [currency] (the foreign/local currency paid).
  final double amount;
  final String currency;
  /// Locked equivalent in the trip's home currency. Set at creation time.
  final double homeAmount;
  /// 1 unit of [currency] expressed in home currency (stored for auditability).
  final double exchangeRate;
  /// Card foreign transaction fee % applied on top of the exchange rate.
  final double transactionFeePct;
  final String paidById;
  /// Split amounts are in the receipt's [currency] (like [amount]).
  final List<ReceiptSplit> splits;
  final ReceiptCategory category;
  final DateTime date;
  final String? notes;
  final String? storagePath;
  /// The itemized bill and who had what — null when split by amount.
  final ReceiptItemization? items;
  /// The receipts.wabble.ca split published from this receipt.
  final String? splitLinkId;
  /// Member ids in the link's person order (person id = index).
  final List<String> splitLinkMembers;
  /// Hash of the link's content when WabWay last wrote or read it — a
  /// different hash on the link means someone changed it there.
  final String? splitLinkHash;
  final String? createdById;

  bool get isItemized => items != null && !items!.isEmpty;

  /// Saved offline on this phone and not uploaded yet (see SyncQueue).
  bool get isPending => id.startsWith('pending-');

  Receipt copyWith({
    List<ReceiptSplit>? splits,
    ReceiptItemization? items,
    String? splitLinkId,
    List<String>? splitLinkMembers,
    String? splitLinkHash,
  }) =>
      Receipt(
        id:                id,
        title:             title,
        amount:            amount,
        currency:          currency,
        homeAmount:        homeAmount,
        exchangeRate:      exchangeRate,
        transactionFeePct: transactionFeePct,
        paidById:          paidById,
        splits:            splits ?? this.splits,
        category:          category,
        date:              date,
        notes:             notes,
        storagePath:       storagePath,
        items:             items ?? this.items,
        splitLinkId:       splitLinkId ?? this.splitLinkId,
        splitLinkMembers:  splitLinkMembers ?? this.splitLinkMembers,
        splitLinkHash:     splitLinkHash ?? this.splitLinkHash,
        createdById:       createdById,
      );

  /// Open (unsettled) shares owed to the payer by other people.
  Iterable<ReceiptSplit> get openDebts =>
      splits.where((s) => s.memberId != paidById && !s.isSettled);

  bool get isFullySettled =>
      splits.any((s) => s.memberId != paidById) && openDebts.isEmpty;

  /// True when the receipt was entered in a foreign currency and a real rate was applied.
  bool get isForeignCurrency => exchangeRate != 1.0;

  double get myShare => myShareFor(kYouId);
  double get myNet   => myNetFor(kYouId);

  double myShareFor(String myId) =>
      splits.where((s) => s.memberId == myId).fold(0.0, (a, s) => a + s.amount);

  // Still outstanding: positive = owed to you, negative = you owe someone.
  double myNetFor(String myId) {
    if (paidById == myId) {
      return openDebts.fold(0.0, (a, s) => a + s.amount);
    }
    final yours = splits.where((s) => s.memberId == myId && !s.isSettled);
    return yours.isEmpty ? 0.0 : -yours.first.amount;
  }
}

// ─── Cash withdrawal ──────────────────────────────────────────────────────────

class CashDistribution {
  const CashDistribution({
    required this.memberId,
    required this.amount,
    this.isSettled = false,
    this.settlementId,
  });
  final String memberId;
  final double amount;
  final bool isSettled;
  final String? settlementId;
}

class CashWithdrawal {
  const CashWithdrawal({
    required this.id,
    required this.withdrawnById,
    required this.amount,
    required this.currency,
    required this.date,
    this.atmFee = 0,
    this.notes,
    this.distributions = const [],
  });

  final String id;
  final String withdrawnById;
  final double amount;
  final double atmFee;
  final String currency;
  final DateTime date;
  final String? notes;
  final List<CashDistribution> distributions;

  double get totalDistributed =>
      distributions.fold(0.0, (a, d) => a + d.amount);

  double get myNet => myNetFor(kYouId);

  double myNetFor(String myId) {
    if (withdrawnById == myId) {
      return distributions
          .where((d) => d.memberId != myId && !d.isSettled)
          .fold(0.0, (a, d) => a + d.amount);
    }
    final yours = distributions.where((d) => d.memberId == myId && !d.isSettled);
    return yours.isEmpty ? 0.0 : -yours.first.amount;
  }
}

// ─── Balances ─────────────────────────────────────────────────────────────────

class MemberBalance {
  const MemberBalance({required this.member, required this.net});
  final TripMember member;
  final double net; // positive = they owe you, negative = you owe them
}

/// Computes per-member net balances relative to the current user.
///
/// Pass [myId] and [members] for live Supabase data. When omitted they default
/// to the mock-only fallbacks [kYouId] and [kMockMembers].
List<MemberBalance> calculateBalances(
  List<Receipt> receipts,
  List<CashWithdrawal> withdrawals, {
  String? myId,
  List<TripMember>? members,
}) {
  final me = myId ?? kYouId;
  final peers = members ?? kMockMembers;
  final Map<String, double> net = {};

  for (final r in receipts) {
    for (final split in r.splits) {
      if (split.isSettled) continue;
      if (r.paidById == me && split.memberId != me) {
        net[split.memberId] = (net[split.memberId] ?? 0) + split.amount;
      } else if (r.paidById != me && split.memberId == me) {
        net[r.paidById] = (net[r.paidById] ?? 0) - split.amount;
      }
    }
  }

  for (final w in withdrawals) {
    if (w.withdrawnById == me) {
      for (final d in w.distributions) {
        if (d.memberId != me && !d.isSettled) {
          net[d.memberId] = (net[d.memberId] ?? 0) + d.amount;
        }
      }
    } else {
      for (final d in w.distributions) {
        if (d.memberId == me && !d.isSettled) {
          net[w.withdrawnById] = (net[w.withdrawnById] ?? 0) - d.amount;
        }
      }
    }
  }

  return peers
      .where((m) => m.id != me)
      .map((m) => MemberBalance(member: m, net: net[m.id] ?? 0))
      .toList();
}

/// Grouped version of [calculateBalances] — groups by currency.
///
/// Each entry in the returned map is `currency → List<MemberBalance>` using
/// only the receipts/withdrawals denominated in that currency. This prevents
/// cross-currency amounts from being summed as if they were equal.
Map<String, List<MemberBalance>> calculateBalancesGrouped(
  List<Receipt> receipts,
  List<CashWithdrawal> withdrawals, {
  String? myId,
  List<TripMember>? members,
}) {
  final me = myId ?? kYouId;
  final peers = members ?? kMockMembers;

  // net[currency][memberId] = amount they owe you (positive) / you owe them (negative)
  final Map<String, Map<String, double>> net = {};

  void add(String currency, String memberId, double delta) {
    net.putIfAbsent(currency, () => {})[memberId] =
        (net[currency]![memberId] ?? 0) + delta;
  }

  for (final r in receipts) {
    for (final split in r.splits) {
      if (split.isSettled) continue;
      if (r.paidById == me && split.memberId != me) {
        add(r.currency, split.memberId, split.amount);
      } else if (r.paidById != me && split.memberId == me) {
        add(r.currency, r.paidById, -split.amount);
      }
    }
  }

  for (final w in withdrawals) {
    if (w.withdrawnById == me) {
      for (final d in w.distributions) {
        if (d.memberId != me && !d.isSettled) add(w.currency, d.memberId, d.amount);
      }
    } else {
      for (final d in w.distributions) {
        if (d.memberId == me && !d.isSettled) add(w.currency, w.withdrawnById, -d.amount);
      }
    }
  }

  final result = <String, List<MemberBalance>>{};
  for (final entry in net.entries) {
    final currency = entry.key;
    final byMember = entry.value;
    result[currency] = peers
        .where((m) => m.id != me && (byMember[m.id] ?? 0).abs() > 0.01)
        .map((m) => MemberBalance(member: m, net: byMember[m.id] ?? 0))
        .toList();
  }
  return result;
}

// ─── Persisted settlement ─────────────────────────────────────────────────────

class Settlement {
  const Settlement({
    required this.id,
    required this.tripId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.currency,
    required this.settledAt,
    required this.settledBy,
    this.note,
  });

  final String id;
  final String tripId;
  final String fromMemberId;
  final String toMemberId;
  final double amount;
  final String currency;
  final DateTime settledAt;
  final String settledBy;
  final String? note;
}

/// The open shares between two people in one currency, both directions —
/// what a Settle Up payment between them clears.
class OpenShares {
  const OpenShares({this.receiptShares = const [], this.cashShares = const []});
  /// (receiptId, memberId)
  final List<(String, String)> receiptShares;
  /// (withdrawalId, memberId)
  final List<(String, String)> cashShares;
  bool get isEmpty => receiptShares.isEmpty && cashShares.isEmpty;
}

OpenShares openSharesBetween(
  List<Receipt> receipts,
  List<CashWithdrawal> withdrawals, {
  required String a,
  required String b,
  required String currency,
}) {
  bool pair(String payer, String debtor) =>
      (payer == a && debtor == b) || (payer == b && debtor == a);
  return OpenShares(
    receiptShares: [
      for (final r in receipts)
        if (r.currency == currency)
          for (final s in r.splits)
            if (!s.isSettled && pair(r.paidById, s.memberId)) (r.id, s.memberId),
    ],
    cashShares: [
      for (final w in withdrawals)
        if (w.currency == currency)
          for (final d in w.distributions)
            if (!d.isSettled && pair(w.withdrawnById, d.memberId)) (w.id, d.memberId),
    ],
  );
}

// ─── Settlement suggestions ───────────────────────────────────────────────────

class SettlementSuggestion {
  SettlementSuggestion({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.currency,
    this.isSettled = false,
  });
  final String fromMemberId;
  final String toMemberId;
  final double amount;
  final String currency;
  bool isSettled;
}

/// Turns balances into concrete payment suggestions.
///
/// Pass [myId] for live Supabase data; defaults to [kYouId] for mock paths.
List<SettlementSuggestion> suggestSettlements(
  List<MemberBalance> balances,
  String currency, {
  String? myId,
}) {
  final me = myId ?? kYouId;
  return balances
      .where((b) => b.net.abs() > 0.5)
      .map((b) => b.net > 0
          ? SettlementSuggestion(
              fromMemberId: b.member.id,
              toMemberId:   me,
              amount:       b.net,
              currency:     currency,
            )
          : SettlementSuggestion(
              fromMemberId: me,
              toMemberId:   b.member.id,
              amount:       -b.net,
              currency:     currency,
            ))
      .toList();
}

// ─── Formatting ───────────────────────────────────────────────────────────────

String fmtAmount(double amount, String currency) {
  return switch (currency) {
    'JPY' || 'KRW' || 'IDR' || 'VND' => '${_currencySymbol(currency)}${amount.toStringAsFixed(0)}',
    'USD' => '\$${amount.toStringAsFixed(2)}',
    'EUR' => '€${amount.toStringAsFixed(2)}',
    'GBP' => '£${amount.toStringAsFixed(2)}',
    'CAD' => 'C\$${amount.toStringAsFixed(2)}',
    'AUD' => 'A\$${amount.toStringAsFixed(2)}',
    _     => '$currency ${amount.toStringAsFixed(2)}',
  };
}

String _currencySymbol(String code) => switch (code) {
  'JPY' => '¥',
  'KRW' => '₩',
  'IDR' => 'Rp',
  'VND' => '₫',
  _     => code,
};

// ─── Mock data ────────────────────────────────────────────────────────────────

Receipt _split4(
  String id,
  String title,
  double amount,
  String currency,
  String paidById,
  ReceiptCategory category,
  DateTime date, {
  String? notes,
}) {
  final share = (amount / 4 * 100).roundToDouble() / 100;
  return Receipt(
    id:                  id,
    title:               title,
    amount:              amount,
    currency:            currency,
    homeAmount:          amount,
    exchangeRate:        1,
    transactionFeePct:   0,
    paidById:            paidById,
    category:            category,
    date:                date,
    notes:               notes,
    splits:              kMockMembers
        .map((m) => ReceiptSplit(memberId: m.id, amount: share))
        .toList(),
  );
}

final kMockReceipts = <Receipt>[
  _split4('r1', 'Ramen Ichiran', 4800, 'JPY', 'alex',
      ReceiptCategory.food, DateTime(2024, 11, 12)),
  Receipt(
    id:                'r2',
    title:             'Shinkansen Tokyo → Kyoto',
    amount:            27400,
    currency:          'JPY',
    homeAmount:        27400,
    exchangeRate:      1,
    transactionFeePct: 0,
    paidById:          'you',
    category:          ReceiptCategory.transport,
    date:              DateTime(2024, 11, 15),
    notes:             'Reserved seats, non-reserved section.',
    splits: const [
      ReceiptSplit(memberId: 'you',    amount: 6850),
      ReceiptSplit(memberId: 'jordan', amount: 6850),
      ReceiptSplit(memberId: 'sam',    amount: 6850),
      ReceiptSplit(memberId: 'alex',   amount: 6850, isSettled: true),
    ],
  ),
  Receipt(
    id:                'r3',
    title:             'Hotel Shinjuku (2 nights)',
    amount:            36000,
    currency:          'JPY',
    homeAmount:        36000,
    exchangeRate:      1,
    transactionFeePct: 0,
    paidById:          'jordan',
    category:          ReceiptCategory.accommodation,
    date:              DateTime(2024, 11, 12),
    splits: const [
      ReceiptSplit(memberId: 'you',    amount: 9000),
      ReceiptSplit(memberId: 'alex',   amount: 9000),
      ReceiptSplit(memberId: 'jordan', amount: 9000),
      ReceiptSplit(memberId: 'sam',    amount: 9000),
    ],
  ),
  _split4('r4', 'Tsukiji Breakfast', 3200, 'JPY', 'you',
      ReceiptCategory.food, DateTime(2024, 11, 13)),
  _split4('r5', 'Convenience Store Run', 1450, 'JPY', 'sam',
      ReceiptCategory.food, DateTime(2024, 11, 13)),
  _split4('r6', 'teamLab Borderless Tickets', 14000, 'JPY', 'you',
      ReceiptCategory.activity, DateTime(2024, 11, 14),
      notes: '4 × ¥3,500. Book in advance next time.'),
  Receipt(
    id:                'r7',
    title:             'Kyoto Ryokan (1 night)',
    amount:            52000,
    currency:          'JPY',
    homeAmount:        52000,
    exchangeRate:      1,
    transactionFeePct: 0,
    paidById:          'you',
    category:          ReceiptCategory.accommodation,
    date:              DateTime(2024, 11, 16),
    splits: const [
      ReceiptSplit(memberId: 'you',    amount: 13000),
      ReceiptSplit(memberId: 'alex',   amount: 13000),
      ReceiptSplit(memberId: 'jordan', amount: 13000),
      ReceiptSplit(memberId: 'sam',    amount: 13000),
    ],
  ),
  _split4('r8', 'Dotonbori Street Food', 2800, 'JPY', 'alex',
      ReceiptCategory.food, DateTime(2024, 11, 18)),
];

final kMockWithdrawals = <CashWithdrawal>[
  CashWithdrawal(
    id: 'w1',
    withdrawnById: 'you',
    amount: 50000,
    currency: 'JPY',
    atmFee: 220,
    date: DateTime(2024, 11, 12),
    notes: '7-Eleven ATM. No foreign-transaction fee card.',
    distributions: const [
      CashDistribution(memberId: 'you',    amount: 10000),
      CashDistribution(memberId: 'alex',   amount: 15000),
      CashDistribution(memberId: 'jordan', amount: 15000),
      CashDistribution(memberId: 'sam',    amount: 10000),
    ],
  ),
  CashWithdrawal(
    id: 'w2',
    withdrawnById: 'you',
    amount: 30000,
    currency: 'JPY',
    date: DateTime(2024, 11, 16),
    distributions: const [
      CashDistribution(memberId: 'you',    amount: 10000),
      CashDistribution(memberId: 'alex',   amount: 10000),
      CashDistribution(memberId: 'jordan', amount: 5000),
      CashDistribution(memberId: 'sam',    amount: 5000),
    ],
  ),
  CashWithdrawal(
    id: 'w3',
    withdrawnById: 'alex',
    amount: 20000,
    currency: 'JPY',
    atmFee: 110,
    date: DateTime(2024, 11, 14),
    notes: 'For Kyoto spending money.',
    distributions: const [
      CashDistribution(memberId: 'you',    amount: 5000),
      CashDistribution(memberId: 'alex',   amount: 5000),
      CashDistribution(memberId: 'jordan', amount: 5000),
      CashDistribution(memberId: 'sam',    amount: 5000),
    ],
  ),
];
