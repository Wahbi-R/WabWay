import 'package:flutter/material.dart';
import 'member_data.dart';
export 'member_data.dart';

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

class ReceiptSplit {
  const ReceiptSplit({
    required this.memberId,
    required this.amount,
    this.isSettled = false,
  });
  final String memberId;
  final double amount;
  final bool isSettled;
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
  /// Split amounts are in home currency.
  final List<ReceiptSplit> splits;
  final ReceiptCategory category;
  final DateTime date;
  final String? notes;
  final String? storagePath;

  /// True when the receipt was entered in a foreign currency and a real rate was applied.
  bool get isForeignCurrency => exchangeRate != 1.0;

  double get myShare => myShareFor(kYouId);
  double get myNet   => myNetFor(kYouId);

  double myShareFor(String myId) =>
      splits.where((s) => s.memberId == myId).fold(0.0, (a, s) => a + s.amount);

  // Positive = net owed to you, Negative = you owe someone.
  double myNetFor(String myId) {
    if (paidById == myId) {
      return splits.where((s) => s.memberId != myId).fold(0.0, (a, s) => a + s.amount);
    }
    final yours = splits.where((s) => s.memberId == myId);
    return yours.isEmpty ? 0.0 : -yours.first.amount;
  }
}

// ─── Cash withdrawal ──────────────────────────────────────────────────────────

class CashDistribution {
  const CashDistribution({required this.memberId, required this.amount});
  final String memberId;
  final double amount;
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
      return distributions.where((d) => d.memberId != myId).fold(0.0, (a, d) => a + d.amount);
    }
    final yours = distributions.where((d) => d.memberId == myId);
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
        if (d.memberId != me) {
          net[d.memberId] = (net[d.memberId] ?? 0) + d.amount;
        }
      }
    } else {
      for (final d in w.distributions) {
        if (d.memberId == me) {
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
        if (d.memberId != me) add(w.currency, d.memberId, d.amount);
      }
    } else {
      for (final d in w.distributions) {
        if (d.memberId == me) add(w.currency, w.withdrawnById, -d.amount);
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

  bool matches(String fromId, String toId) =>
      fromMemberId == fromId && toMemberId == toId;
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

String fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${months[d.month - 1]} ${d.day}';
}

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
