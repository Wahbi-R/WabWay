import 'package:flutter/material.dart';
import '../data/accommodation_data.dart';
import '../data/connection_data.dart' show EntityType;
import '../data/money_data.dart';
import '../widgets/wabway_confirm_dialog.dart';
import '../widgets/wabway_snack.dart';
import 'receipts_link_service.dart';
import 'supabase/accommodation_service.dart';
import 'supabase/connection_service.dart';
import 'supabase/money_service.dart';
import 'trip_data_changes.dart';

// A stay and its receipt are separate records linked in Connections. When
// one's price is edited, offer to change the other — but only when they
// agreed before (same currency, same total). A deposit, a refund or a
// different currency means they differ on purpose, so those are left alone.

/// Same amount, give or take rounding to the currency's smallest unit.
bool pricesAgree(double a, double b, String currency) =>
    (a - b).abs() < (currencyDecimals(currency) == 0 ? 1 : 0.015);

/// Why [r] can't simply be re-priced (change it by hand in Money), or null.
String? rescaleBlocker(Receipt r) {
  if (r.splits.any((s) => s.isSettled)) return 'some shares are already paid back';
  if (r.isItemized) return "it's split by item";
  return null;
}

/// [r]'s shares scaled to a new [amount], rounded to the currency, with any
/// rounding left on the first share so they add up exactly.
List<ReceiptSplit> rescaledSplits(Receipt r, double amount) {
  if (r.splits.isEmpty || r.amount <= 0) return r.splits;
  final f = amount / r.amount;
  final d = currencyDecimals(r.currency);
  double round(double v) => double.parse(v.toStringAsFixed(d));
  final out = [for (final s in r.splits) ReceiptSplit(memberId: s.memberId, amount: round(s.amount * f))];
  final rest = round(amount - out.fold(0.0, (a, s) => a + s.amount));
  if (rest != 0) out[0] = ReceiptSplit(memberId: out[0].memberId, amount: round(out[0].amount + rest));
  return out;
}

/// [r] at a new [amount]: shares scaled, home amount at the same rate. Pushes
/// to its Receipts link when it has one.
Future<Receipt> repriceReceipt(
  Receipt r,
  double amount, {
  required List<TripMember> members,
  String? homeCurrency,
}) async {
  var updated = await MoneyService.updateReceipt(
    receiptId:         r.id,
    title:             r.title,
    amount:            amount,
    currency:          r.currency,
    homeAmount:        r.amount > 0 ? r.homeAmount * amount / r.amount : amount,
    exchangeRate:      r.exchangeRate,
    transactionFeePct: r.transactionFeePct,
    category:          r.category,
    paidBy:            r.paidById,
    date:              r.date,
    splits:            rescaledSplits(r, amount),
    notes:             r.notes,
    previousSplits:    r.splits,
  );
  if (updated.splitLinkId != null) {
    try {
      final (_, pushed) = await ReceiptsLinkService.push(updated, members, homeCurrency: homeCurrency);
      updated = pushed;
    } catch (_) {}
  }
  TripDataChanges.touch(const [EntityType.receipt]);
  return updated;
}

Future<List<String>> _linked(String id, EntityType type) async {
  final conns = await ConnectionService.fetchForEntity(id);
  return [for (final c in conns) if (c.peerType(id) == type) c.peerId(id)];
}

/// After a stay's total changed from [before] to [after]: offer to change the
/// receipt it's linked to. Never throws.
Future<void> offerReceiptUpdateForStay(
  BuildContext context, {
  required Accommodation before,
  required Accommodation after,
  required List<TripMember> members,
  String? homeCurrency,
}) async {
  try {
    final was = before.totalPrice, now = after.totalPrice;
    if (was == null || now == null || before.currency != after.currency) return;
    if (pricesAgree(was, now, after.currency)) return;
    Receipt? receipt;
    for (final id in await _linked(after.id, EntityType.receipt)) {
      final r = await MoneyService.loadReceipt(id);
      if (r != null && r.currency == after.currency && pricesAgree(r.amount, was, r.currency)) {
        receipt = r;
        break;
      }
    }
    if (receipt == null || !context.mounted) return;
    final blocker = rescaleBlocker(receipt);
    if (blocker != null) {
      showWabwaySnack(context,
          "The receipt in Money wasn't changed because $blocker — update it there.",
          duration: const Duration(seconds: 5));
      return;
    }
    final ok = await showWabwayConfirm(
      context,
      title: 'Update the receipt too?',
      message: '"${receipt.title}" in Money is ${fmtAmount(receipt.amount, receipt.currency)}. '
          'Change it to ${fmtAmount(now, receipt.currency)}? Everyone\'s share changes to match.',
      confirmLabel: 'Update receipt',
      cancelLabel: 'Leave it',
      destructive: false,
    );
    if (!ok) return;
    await repriceReceipt(receipt, now, members: members, homeCurrency: homeCurrency);
    if (context.mounted) showWabwaySnack(context, 'Receipt updated');
  } catch (_) {
    if (context.mounted) showWabwaySnack(context, "Couldn't update the receipt.", error: true);
  }
}

/// After a receipt's amount changed from [before] to [after]: offer to change
/// the total of the stay it's linked to. Never throws.
Future<void> offerStayUpdateForReceipt(
  BuildContext context, {
  required Receipt before,
  required Receipt after,
}) async {
  try {
    if (before.currency != after.currency ||
        pricesAgree(before.amount, after.amount, after.currency)) {
      return;
    }
    final ids = await _linked(after.id, EntityType.stay);
    if (ids.isEmpty) return;
    final stays = await AccommodationService.loadByIds(ids);
    final stay = stays.where((s) {
      final t = s.totalPrice;
      return t != null && s.currency == after.currency && pricesAgree(t, before.amount, s.currency);
    }).firstOrNull;
    if (stay == null || !context.mounted) return;
    final ok = await showWabwayConfirm(
      context,
      title: 'Update the stay too?',
      message: '"${stay.name}" is ${fmtAmount(stay.totalPrice!, stay.currency)} for '
          '${stay.nights == 1 ? '1 night' : '${stay.nights} nights'}. '
          'Change it to ${fmtAmount(after.amount, stay.currency)}?',
      confirmLabel: 'Update stay',
      cancelLabel: 'Leave it',
      destructive: false,
    );
    if (!ok) return;
    await AccommodationService.update(stay.copyWith(pricePerNight: after.amount / stay.nights!));
    TripDataChanges.touch(const [EntityType.stay]);
    if (context.mounted) showWabwaySnack(context, 'Stay updated');
  } catch (_) {
    if (context.mounted) showWabwaySnack(context, "Couldn't update the stay.", error: true);
  }
}
