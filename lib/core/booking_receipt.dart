import '../data/money_data.dart';
import '../data/plan_data.dart';
import '../data/travel_data.dart';
import 'ocr/parsed_booking.dart';
import 'text_utils.dart';

// A paid booking becomes a receipt in Money — the same kind of receipt as a
// scanned bill, so it splits, settles and publishes to receipts.wabble.ca
// like any other. These decide what that receipt looks like; the review
// screen saves it.

/// What the receipt for a booking will be, before it's saved.
class BookingReceiptDraft {
  const BookingReceiptDraft({
    required this.title,
    required this.amount,
    required this.currency,
    required this.category,
    required this.paidById,
    required this.splitWith,
    this.items,
    this.notes,
  });

  final String title;
  final double amount;
  final String currency;
  final ReceiptCategory category;
  final String paidById;

  /// Members sharing the cost (equally, or by [items]).
  final List<String> splitWith;

  /// The printed price lines as receipt items, shared by [splitWith], when
  /// they add up to the total.
  final ReceiptItemization? items;
  final String? notes;

  /// Everyone's share, in [currency].
  List<ReceiptSplit> get splits {
    if (items case final i?) return i.toSplits(splitWith, currency);
    if (splitWith.isEmpty) return const [];
    final decimals = currencyDecimals(currency);
    final share = _round(amount / splitWith.length, decimals);
    return [for (final id in splitWith) ReceiptSplit(memberId: id, amount: share)];
  }

  static double _round(double v, int decimals) {
    var f = 1.0;
    for (var i = 0; i < decimals; i++) {
      f *= 10;
    }
    return (v * f).round() / f;
  }
}

/// The receipt a [booking] would make, or null when there's nothing to put
/// in Money (no price, nothing paid yet, or free). Also returned when the
/// booking doesn't say whether it's paid (a bare "Total cost") — the review
/// screen then offers it switched off ([BookingPrice.isPaid] decides).
///
/// Paid by [payerId] (whoever shared it). Split between the booking's
/// travellers / guests when every one is a trip member, else between
/// [memberIds] (everyone in the trip).
BookingReceiptDraft? receiptForBooking(
  ParsedBooking booking, {
  required String payerId,
  required List<String> memberIds,
}) {
  final price = booking.price;
  if (price == null || price.status == PaidStatus.due || price.paidAmount <= 0) return null;

  final travellers = switch (booking) {
    ParsedTravel(:final item) => item.travellers,
    ParsedStay(:final guests) => guests,
    ParsedPlan() => const <TravelTraveller>[],
  };
  final assigned = travellers.map((t) => t.userId).nonNulls.toSet().toList();
  final people = booking.passengerCount ?? travellers.length;
  final splitWith = assigned.isNotEmpty && assigned.length == people && travellers.every((t) => t.userId != null)
      ? assigned
      : memberIds;

  final category = switch (booking) {
    ParsedTravel() => ReceiptCategory.transport,
    ParsedStay() => ReceiptCategory.accommodation,
    ParsedPlan(:final item) when item.type == ItineraryItemType.food => ReceiptCategory.food,
    ParsedPlan() => ReceiptCategory.activity,
  };

  // Itemise only a fully paid booking whose printed lines add up: then a bag
  // or upgrade can later be moved onto the one person it's for.
  ReceiptItemization? items;
  if (price.status == PaidStatus.paid && price.lines.isNotEmpty && !price.linesMismatch) {
    final positive = [for (final l in price.lines) if (l.amount > 0) l];
    final discount = price.lines.where((l) => l.amount < 0).fold(0.0, (a, l) => a - l.amount);
    items = ReceiptItemization(
      items: [
        for (final (i, l) in positive.indexed)
          ReceiptItem(id: i, name: l.label, quantity: l.quantity, totalPrice: l.amount),
      ],
      discount: discount,
      assignments: {
        for (final (i, l) in positive.indexed)
          i: {for (final id in splitWith) id: l.quantity / splitWith.length},
      },
    );
  }

  final ref = switch (booking) {
    ParsedTravel(:final item) => item.confirmationNumber,
    ParsedStay(:final stay) => stay.confirmationNumber,
    ParsedPlan() => null,
  };
  return BookingReceiptDraft(
    title: booking.title,
    amount: price.paidAmount,
    currency: price.currency,
    category: category,
    paidById: payerId,
    splitWith: splitWith,
    items: items,
    notes: joinNonEmpty([
      'From booking',
      if (ref != null) 'Ref $ref',
      if (price.amountDue != null && price.amountDue! > 0)
        '${fmtAmount(price.amountDue!, price.currency)} still due',
      price.points,
    ]),
  );
}

/// A receipt already in Money for this booking's payment (someone logged it
/// by hand): same currency and amount, and the same name or reference.
Receipt? findExistingReceipt(BookingReceiptDraft draft, List<Receipt> receipts) {
  final title = foldForSearch(draft.title);
  final ref = RegExp(r'Ref (\S+)').firstMatch(draft.notes ?? '')?.group(1);
  return receipts.where((r) =>
      r.currency == draft.currency &&
      (r.amount - draft.amount).abs() < 0.5 &&
      (foldForSearch(r.title) == title ||
          (ref != null && ((r.notes ?? '').contains(ref) || r.title.contains(ref))))).firstOrNull;
}
