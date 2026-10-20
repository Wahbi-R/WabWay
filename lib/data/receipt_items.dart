import 'dart:convert';
import 'money_data.dart';

// ─── Itemized receipt ─────────────────────────────────────────────────────────
//
// Mirrors the receipts.wabble.ca split model (src/store/useSplitStore.ts) so a
// receipt can be published there as a link and read back without losing
// anything. Keep [ReceiptItemization.personTotals] in step with
// `calcPersonTotals` in that repo.
//
// Weights are portions of the item's quantity: on a 2× item, a weight of 1
// means "one of the two". Weights summing to less than the quantity leave the
// rest unclaimed; summing to more shares the item proportionally.

class ReceiptItem {
  const ReceiptItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.totalPrice,
  });

  final int id;
  final String name;
  final double quantity;
  /// The line total as printed (already quantity × unit price).
  final double totalPrice;

  double get unitPrice => quantity > 0 ? totalPrice / quantity : totalPrice;

  ReceiptItem copyWith({String? name, double? quantity, double? totalPrice}) =>
      ReceiptItem(
        id:         id,
        name:       name ?? this.name,
        quantity:   quantity ?? this.quantity,
        totalPrice: totalPrice ?? this.totalPrice,
      );

  Map<String, dynamic> toJson() => {
        'id':          id,
        'name':        name,
        'quantity':    quantity,
        'unit_price':  _round2(unitPrice),
        'total_price': totalPrice,
      };

  factory ReceiptItem.fromJson(Map<String, dynamic> j, {int? fallbackId}) {
    final qty = (j['quantity'] as num?)?.toDouble() ?? 1;
    return ReceiptItem(
      id:         (j['id'] as num?)?.toInt() ?? fallbackId ?? 0,
      name:       (j['name'] as String?)?.trim().isNotEmpty == true ? (j['name'] as String).trim() : 'Item',
      quantity:   qty > 0 ? qty : 1,
      totalPrice: (j['total_price'] as num?)?.toDouble() ?? 0,
    );
  }
}

class UnclaimedItem {
  const UnclaimedItem({required this.item, required this.claimed, required this.amount});
  final ReceiptItem item;
  /// Units claimed so far.
  final double claimed;
  /// Pre-tax amount nobody is paying for.
  final double amount;
}

class PersonItemShare {
  const PersonItemShare({required this.item, required this.share});
  final ReceiptItem item;
  final double share;
}

class ReceiptItemization {
  const ReceiptItemization({
    required this.items,
    this.title,
    this.subtotal = 0,
    this.discount = 0,
    this.tax = 0,
    this.tip = 0,
    this.printedTotal = 0,
    this.assignments = const {},
  });

  /// Business name read from the receipt (scan only).
  final String? title;
  final List<ReceiptItem> items;
  /// Subtotal / total as printed on the receipt (0 when unknown). Only used to
  /// warn about a misread line — amounts always come from the items.
  final double subtotal;
  final double printedTotal;
  final double discount;
  final double tax;
  final double tip;
  /// itemId → memberId → weight.
  final Map<int, Map<String, double>> assignments;

  static const empty = ReceiptItemization(items: []);

  bool get isEmpty => items.isEmpty;
  double get itemsTotal => items.fold(0.0, (a, i) => a + i.totalPrice);
  double get extras => tax + tip - discount;
  /// What the bill comes to from its lines: items + tax + tip − discount.
  double get total => itemsTotal + extras;

  /// True when the lines don't add up to the printed subtotal (a misread line).
  bool get subtotalMismatch => subtotal > 0 && (itemsTotal - subtotal).abs() > 0.01;

  int get nextItemId => items.isEmpty ? 0 : items.map((i) => i.id).reduce((a, b) => a > b ? a : b) + 1;

  Map<String, double> weightsFor(int itemId) => assignments[itemId] ?? const {};

  static double _claimed(Map<String, double> w) => w.values.fold(0.0, (a, b) => a + b);

  /// Portions are units of the item: 1 of 2 means paying half. If more than
  /// the quantity is claimed, it's shared proportionally.
  static double portionDivisor(ReceiptItem item, double claimed) =>
      claimed > (item.quantity > 0 ? item.quantity : claimed)
          ? claimed
          : (item.quantity > 0 ? item.quantity : claimed);

  /// Items (or parts of items) nobody has claimed yet.
  List<UnclaimedItem> get unclaimed => [
        for (final item in items)
          if (_unclaimedAmount(item) > 0.005)
            UnclaimedItem(
              item: item,
              claimed: _claimed(weightsFor(item.id)),
              amount: _unclaimedAmount(item),
            ),
      ];

  double _unclaimedAmount(ReceiptItem item) {
    final claimed = _claimed(weightsFor(item.id));
    if (claimed <= 0) return item.totalPrice;
    return item.totalPrice * (1 - claimed / portionDivisor(item, claimed));
  }

  double get unclaimedTotal => unclaimed.fold(0.0, (a, u) => a + u.amount);

  /// Item shares per member (pre-tax).
  Map<String, List<PersonItemShare>> itemSharesByMember() {
    final out = <String, List<PersonItemShare>>{};
    for (final item in items) {
      final weights = weightsFor(item.id);
      final totalWeight = _claimed(weights);
      if (totalWeight <= 0) continue;
      final divisor = portionDivisor(item, totalWeight);
      weights.forEach((memberId, w) {
        (out[memberId] ??= []).add(
            PersonItemShare(item: item, share: w / divisor * item.totalPrice));
      });
    }
    return out;
  }

  /// What each member owes in the receipt's currency: their items plus a
  /// proportional part of tax/tip/discount. Members who had nothing get 0.
  Map<String, double> personTotals(Iterable<String> memberIds) {
    final subtotals = <String, double>{for (final id in memberIds) id: 0.0};
    // People not in [memberIds] (e.g. left the trip) owe nothing here — their
    // part stays unpaid, like an unclaimed item.
    itemSharesByMember().forEach((id, shares) {
      if (!subtotals.containsKey(id)) return;
      subtotals[id] = subtotals[id]! + shares.fold(0.0, (a, s) => a + s.share);
    });
    final grandSub = itemsTotal > 0
        ? itemsTotal
        : subtotals.values.fold(0.0, (a, b) => a + b);
    final n = subtotals.length;
    return {
      for (final e in subtotals.entries)
        e.key: e.value + extras * (grandSub > 0 ? e.value / grandSub : (n > 0 ? 1 / n : 0)),
    };
  }

  /// Splits for saving, rounded to the currency's decimals. Zero shares dropped.
  List<ReceiptSplit> toSplits(Iterable<String> memberIds, String currency) {
    final decimals = currencyDecimals(currency);
    return [
      for (final e in personTotals(memberIds).entries)
        if (_roundTo(e.value, decimals) > 0)
          ReceiptSplit(memberId: e.key, amount: _roundTo(e.value, decimals)),
    ];
  }

  // ── Editing (immutable — every method returns a new itemization) ──────────

  ReceiptItemization copyWith({
    String? title,
    List<ReceiptItem>? items,
    double? subtotal,
    double? discount,
    double? tax,
    double? tip,
    double? printedTotal,
    Map<int, Map<String, double>>? assignments,
  }) =>
      ReceiptItemization(
        title:        title ?? this.title,
        items:        items ?? this.items,
        subtotal:     subtotal ?? this.subtotal,
        discount:     discount ?? this.discount,
        tax:          tax ?? this.tax,
        tip:          tip ?? this.tip,
        printedTotal: printedTotal ?? this.printedTotal,
        assignments:  assignments ?? this.assignments,
      );

  ReceiptItemization _withWeights(int itemId, Map<String, double> weights) =>
      copyWith(assignments: {...assignments, itemId: weights});

  static Map<String, double> _equal(double quantity, Iterable<String> ids) {
    final list = ids.toList();
    if (list.isEmpty) return {};
    return {for (final id in list) id: quantity / list.length};
  }

  /// Tap a person on an item. Same behaviour as the Receipts site: adding
  /// someone to an equally-split item re-splits it equally; adding someone to
  /// a partly-claimed item gives them what's left; removing someone from a
  /// custom split leaves their part unclaimed.
  ReceiptItemization toggle(int itemId, String memberId) {
    final item = items.where((i) => i.id == itemId).firstOrNull;
    if (item == null) return this;
    final qty = item.quantity;
    final weights = Map<String, double>.of(weightsFor(itemId));
    final vals = weights.values.toList();
    final wasEqual = vals.every((v) => (v - vals.first).abs() < 1e-9);
    final claimed = _claimed(weights);
    if (weights.containsKey(memberId)) {
      weights.remove(memberId);
      if (!wasEqual) return _withWeights(itemId, weights);
    } else if (claimed > 0 && qty - claimed > 1e-6) {
      weights[memberId] = qty - claimed;
      return _withWeights(itemId, weights);
    } else {
      weights[memberId] = 1;
    }
    return _withWeights(itemId, _equal(qty, weights.keys));
  }

  /// Set someone's portion directly (0 removes them).
  ReceiptItemization setWeight(int itemId, String memberId, double weight) {
    final weights = Map<String, double>.of(weightsFor(itemId));
    if (weight <= 0) {
      weights.remove(memberId);
    } else {
      weights[memberId] = weight;
    }
    return _withWeights(itemId, weights);
  }

  ReceiptItemization splitItemEqually(int itemId) {
    final item = items.where((i) => i.id == itemId).firstOrNull;
    final weights = weightsFor(itemId);
    if (item == null || weights.isEmpty) return this;
    return _withWeights(itemId, _equal(item.quantity, weights.keys));
  }

  /// Everyone shares everything equally.
  ReceiptItemization assignAll(Iterable<String> memberIds) => copyWith(assignments: {
        for (final item in items) item.id: _equal(item.quantity, memberIds),
      });

  /// Give every unclaimed part to these people, equally.
  ReceiptItemization assignUnclaimed(Iterable<String> memberIds) {
    var next = this;
    for (final u in unclaimed) {
      final weights = Map<String, double>.of(weightsFor(u.item.id));
      if (weights.isEmpty) {
        next = next._withWeights(u.item.id, _equal(u.item.quantity, memberIds));
      } else {
        final left = u.item.quantity - u.claimed;
        final ids = memberIds.toList();
        if (ids.isEmpty || left <= 0) continue;
        for (final id in ids) {
          weights[id] = (weights[id] ?? 0) + left / ids.length;
        }
        next = next._withWeights(u.item.id, weights);
      }
    }
    return next;
  }

  ReceiptItemization updateItem(ReceiptItem item) {
    final old = items.where((i) => i.id == item.id).firstOrNull;
    var next = copyWith(items: [for (final i in items) i.id == item.id ? item : i]);
    // A quantity change keeps an equal split equal.
    if (old != null && old.quantity != item.quantity) {
      final w = weightsFor(item.id);
      final vals = w.values.toList();
      if (vals.isNotEmpty && vals.every((v) => (v - vals.first).abs() < 1e-9) &&
          (_claimed(w) - old.quantity).abs() < 1e-6) {
        next = next._withWeights(item.id, _equal(item.quantity, w.keys));
      }
    }
    return next;
  }

  ReceiptItemization addItem({String name = 'New item', double quantity = 1, double totalPrice = 0}) {
    final id = nextItemId;
    return copyWith(
      items: [...items, ReceiptItem(id: id, name: name, quantity: quantity, totalPrice: totalPrice)],
      assignments: {...assignments, id: {}},
    );
  }

  ReceiptItemization removeItem(int itemId) => copyWith(
        items: items.where((i) => i.id != itemId).toList(),
        assignments: Map.of(assignments)..remove(itemId),
      );

  /// Drop people who are no longer in the trip.
  ReceiptItemization keepMembers(Set<String> memberIds) => copyWith(assignments: {
        for (final e in assignments.entries)
          e.key: {
            for (final w in e.value.entries)
              if (memberIds.contains(w.key)) w.key: w.value,
          },
      });

  // ── Building ──────────────────────────────────────────────────────────────

  /// A one-line itemization reproducing existing splits exactly — used to
  /// publish a receipt that was split by amount (not by item) as a link.
  factory ReceiptItemization.fromSplits({
    required String title,
    required double amount,
    required List<ReceiptSplit> splits,
  }) {
    final total = splits.fold(0.0, (a, s) => a + s.amount);
    final price = amount > 0 ? amount : total;
    return ReceiptItemization(
      items: [ReceiptItem(id: 0, name: title, quantity: 1, totalPrice: price)],
      assignments: {
        0: {
          for (final s in splits)
            if (s.amount > 0 && price > 0) s.memberId: s.amount / price,
        },
      },
    );
  }

  /// From the `/receipt/scan` response. Nothing is assigned yet.
  factory ReceiptItemization.fromScan(Map<String, dynamic> j) {
    final raw = (j['items'] as List?) ?? const [];
    final items = <ReceiptItem>[
      for (var i = 0; i < raw.length; i++)
        ReceiptItem.fromJson({...(raw[i] as Map).cast<String, dynamic>(), 'id': i}),
    ];
    return ReceiptItemization(
      title:        (j['title'] as String?)?.trim(),
      items:        items,
      subtotal:     (j['subtotal'] as num?)?.toDouble() ?? 0,
      discount:     (j['discount'] as num?)?.toDouble() ?? 0,
      tax:          (j['tax'] as num?)?.toDouble() ?? 0,
      tip:          (j['tip'] as num?)?.toDouble() ?? 0,
      printedTotal: (j['total'] as num?)?.toDouble() ?? 0,
      assignments:  {for (final it in items) it.id: <String, double>{}},
    );
  }

  // ── Storage (receipts.items jsonb) ────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        if (title != null && title!.isNotEmpty) 'title': title,
        'items':       [for (final i in items) i.toJson()],
        'subtotal':    subtotal,
        'discount':    discount,
        'tax':         tax,
        'tip':         tip,
        'total':       printedTotal,
        'assignments': {
          for (final e in assignments.entries)
            '${e.key}': {for (final w in e.value.entries) w.key: w.value},
        },
      };

  static ReceiptItemization? fromJsonOrNull(Object? raw) {
    if (raw == null) return null;
    try {
      final j = raw is String
          ? jsonDecode(raw) as Map<String, dynamic>
          : Map<String, dynamic>.from(raw as Map);
      final rawItems = (j['items'] as List?) ?? const [];
      final items = <ReceiptItem>[
        for (var i = 0; i < rawItems.length; i++)
          ReceiptItem.fromJson(Map<String, dynamic>.from(rawItems[i] as Map), fallbackId: i),
      ];
      final rawAssign = (j['assignments'] as Map?) ?? const {};
      final assignments = <int, Map<String, double>>{};
      rawAssign.forEach((k, v) {
        final id = int.tryParse('$k');
        if (id == null || v is! Map) return;
        assignments[id] = {
          for (final w in v.entries)
            if (w.value is num) '${w.key}': (w.value as num).toDouble(),
        };
      });
      return ReceiptItemization(
        title:        j['title'] as String?,
        items:        items,
        subtotal:     (j['subtotal'] as num?)?.toDouble() ?? 0,
        discount:     (j['discount'] as num?)?.toDouble() ?? 0,
        tax:          (j['tax'] as num?)?.toDouble() ?? 0,
        tip:          (j['tip'] as num?)?.toDouble() ?? 0,
        printedTotal: (j['total'] as num?)?.toDouble() ?? 0,
        assignments:  assignments,
      );
    } catch (_) {
      return null;
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Decimal places a currency is entered and shown with.
int currencyDecimals(String currency) =>
    const {'JPY', 'KRW', 'IDR', 'VND'}.contains(currency) ? 0 : 2;

double _round2(double v) => (v * 100).roundToDouble() / 100;

double _roundTo(double v, int decimals) {
  final f = decimals == 0 ? 1 : 100;
  return (v * f).roundToDouble() / f;
}

/// Quantity without a trailing ".0" (2 → "2", 0.5 → "0.5").
String fmtQty(double q) =>
    q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
