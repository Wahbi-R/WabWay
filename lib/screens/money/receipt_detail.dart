import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/receipts_link_service.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/money_service.dart';
import '../../core/sync_queue.dart';
import '../../core/text_utils.dart';
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import '../../data/connection_data.dart';
import '../shared/attached_docs_section.dart';
import 'add_receipt_sheet.dart';

// ─── Confirmation helper ──────────────────────────────────────────────────────

Future<bool> _confirmDelete(BuildContext context, String title) =>
    showWabwayDeleteConfirm(context, entity: 'receipt', name: title,
        detail: 'for everyone in the trip');

/// Opens the edit form with the active trip's currencies (the form's
/// conversion needs the real home currency, not the 'CAD' default).
Future<Receipt?> _openEditor(
  BuildContext context,
  WidgetRef ref, {
  required Receipt receipt,
  required String tripId,
  required String myId,
  required List<TripMember> members,
  bool duplicate = false,
}) {
  final trip = ref.read(activeTripProvider);
  return showAddReceiptSheet(
    context,
    tripId:          tripId,
    userId:          supabase.auth.currentUser?.id ?? myId,
    members:         members,
    existingReceipt: receipt,
    isDuplicate:     duplicate,
    homeCurrency:    trip?.homeCurrency ?? 'CAD',
    defaultCurrency: trip?.defaultCurrency,
  );
}

// ─── Mobile full-screen route ─────────────────────────────────────────────────

class ReceiptDetailScreen extends ConsumerStatefulWidget {
  const ReceiptDetailScreen({
    super.key,
    required this.receipt,
    required this.myId,
    required this.members,
    required this.tripId,
    this.onDelete,
    this.onUpdated,
  });

  final Receipt receipt;
  final String myId;
  final List<TripMember> members;
  final String tripId;
  final VoidCallback? onDelete;
  final ValueChanged<Receipt>? onUpdated;

  @override
  ConsumerState<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends ConsumerState<ReceiptDetailScreen> {
  late Receipt _receipt;

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt;
  }

  void _updated(Receipt r) {
    setState(() => _receipt = r);
    widget.onUpdated?.call(r);
  }

  Future<void> _editReceipt() async {
    final updated = await _openEditor(context, ref,
        receipt: _receipt, tripId: widget.tripId, myId: widget.myId, members: widget.members);
    if (updated != null && mounted) _updated(updated);
  }

  Future<void> _duplicateReceipt() async {
    await _openEditor(context, ref,
        receipt: _receipt, tripId: widget.tripId, myId: widget.myId,
        members: widget.members, duplicate: true);
    // The caller (money screen) refreshes on its own via its realtime channel.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: kColorInkSoft,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(_receipt.title, style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            color: kColorInkSoft,
            tooltip: 'Edit',
            onPressed: _editReceipt,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, color: kColorInkSoft),
            onSelected: (v) {
              if (v == 'duplicate') _duplicateReceipt();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'duplicate',
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('Duplicate'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: kSpace12 + MediaQuery.paddingOf(context).bottom),
        child: ReceiptDetailContent(
          receipt:   _receipt,
          myId:      widget.myId,
          members:   widget.members,
          tripId:    widget.tripId,
          // One delete button (in the content); on this full-screen route it
          // also closes the page.
          onDelete:  widget.onDelete == null
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onDelete!();
                },
          onUpdated: _updated,
        ),
      ),
    );
  }
}

// ─── Shared detail content ────────────────────────────────────────────────────

class ReceiptDetailContent extends ConsumerStatefulWidget {
  const ReceiptDetailContent({
    super.key,
    required this.receipt,
    required this.myId,
    required this.members,
    required this.tripId,
    this.onDelete,
    this.onUpdated,
  });

  final Receipt receipt;
  final String myId;
  final List<TripMember> members;
  final String tripId;
  final VoidCallback? onDelete;
  final ValueChanged<Receipt>? onUpdated;

  @override
  ConsumerState<ReceiptDetailContent> createState() => _ReceiptDetailContentState();
}

class _ReceiptDetailContentState extends ConsumerState<ReceiptDetailContent> {
  late Receipt _receipt = widget.receipt;
  RemoteSplit? _remote;
  bool _checkingLink = false;
  bool _linkBusy = false;
  bool _linkQueued = false;
  final Set<String> _busyShares = {};

  @override
  void initState() {
    super.initState();
    SyncQueue.pendingLinkIds(widget.tripId).then((ids) {
      if (mounted && ids.contains(_receipt.id)) setState(() => _linkQueued = true);
    });
    _checkLink();
  }

  @override
  void didUpdateWidget(ReceiptDetailContent old) {
    super.didUpdateWidget(old);
    if (!identical(old.receipt, widget.receipt)) {
      _receipt = widget.receipt;
      if (old.receipt.splitLinkId != widget.receipt.splitLinkId) _checkLink();
    }
  }

  String get _me => supabase.auth.currentUser?.id ?? widget.myId;
  bool get _isOrganiser => ref.read(isOrganiserProvider);
  /// Can change the split itself (RLS: payer, creator or trip owner).
  bool get _canEdit =>
      _me == _receipt.paidById || _me == _receipt.createdById || _isOrganiser;
  /// Can mark this share paid (RLS: that person, the payer or the owner).
  bool _canSettle(ReceiptSplit s) =>
      s.memberId == _me || _me == _receipt.paidById || _isOrganiser;

  void _update(Receipt r) {
    setState(() => _receipt = r);
    widget.onUpdated?.call(r);
  }

  Future<bool> _offline() async {
    final c = await Connectivity().checkConnectivity();
    return c.every((r) => r == ConnectivityResult.none);
  }

  // ── Shares ────────────────────────────────────────────────────────────────

  Future<void> _toggleShare(ReceiptSplit split) async {
    if (_busyShares.contains(split.memberId)) return;
    final settled = !split.isSettled;
    final before = _receipt;
    setState(() => _busyShares.add(split.memberId));
    _update(_receipt.copyWith(splits: [
      for (final s in _receipt.splits)
        s.memberId == split.memberId
            ? s.copyWith(isSettled: settled, settledAt: DateTime.now())
            : s,
    ]));
    try {
      await MoneyService.setShareSettled(
          receiptId: _receipt.id, memberId: split.memberId, settled: settled);
      unawaited(_pushLinkQuietly());
    } catch (_) {
      if (await _offline()) {
        await SyncQueue.enqueueSettleShare(widget.tripId,
            receiptId: _receipt.id, memberId: split.memberId, settled: settled);
        if (mounted) showWabwaySnack(context, 'Saved offline — will sync when you reconnect');
      } else {
        _update(before);
        if (mounted) showWabwaySnack(context, 'Could not update. Try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busyShares.remove(split.memberId));
    }
  }

  // ── Receipts link ─────────────────────────────────────────────────────────

  Future<void> _checkLink() async {
    if (_receipt.splitLinkId == null) {
      if (_remote != null) setState(() => _remote = null);
      return;
    }
    setState(() => _checkingLink = true);
    try {
      final remote = await ReceiptsLinkService.fetch(_receipt, widget.members);
      if (mounted) setState(() => _remote = remote);
    } catch (_) {
      // Offline or the site is down — just don't show remote changes.
    } finally {
      if (mounted) setState(() => _checkingLink = false);
    }
  }

  String? get _homeCurrency => ref.read(activeTripProvider)?.homeCurrency;

  bool get _remoteChanged =>
      _remote != null && _receipt.splitLinkHash != null && _remote!.hash != _receipt.splitLinkHash;

  /// Keep the link in step after a WabWay change (e.g. a share marked paid),
  /// unless someone changed the link in the meantime.
  Future<void> _pushLinkQuietly() async {
    if (_receipt.splitLinkId == null) return;
    final (result, updated) =
        await ReceiptsLinkService.push(_receipt, widget.members, homeCurrency: _homeCurrency);
    if (!mounted) return;
    if (result == LinkPushResult.pushed) {
      _update(updated);
    } else if (result == LinkPushResult.remoteChanged) {
      unawaited(_checkLink());
    }
  }

  Future<void> _createLink() async {
    setState(() => _linkBusy = true);
    try {
      final photos = await ReceiptsLinkService.attachedPhotos(_receipt.id);
      final updated = await ReceiptsLinkService.create(_receipt, widget.members,
          photos: photos, homeCurrency: _homeCurrency);
      if (!mounted) return;
      _update(updated);
      _shareLink();
    } catch (_) {
      if (await _offline()) {
        await SyncQueue.enqueueLink(widget.tripId, _receipt.id);
        if (mounted) {
          setState(() => _linkQueued = true);
          showWabwaySnack(context, "You're offline — the link will be created when you reconnect.");
        }
      } else if (mounted) {
        showWabwaySnack(context, "Couldn't create the link. Try again.", error: true);
      }
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  void _shareLink() {
    final id = _receipt.splitLinkId;
    if (id == null) return;
    Share.share('Claim what you had from "${_receipt.title}": ${receiptsLinkUrl(id)}',
        subject: _receipt.title);
  }

  Future<void> _applyRemote() async {
    final remote = _remote;
    if (remote == null) return;
    setState(() => _linkBusy = true);
    try {
      final updated = await ReceiptsLinkService.apply(_receipt, remote, widget.members);
      if (!mounted) return;
      _update(updated);
      setState(() => _remote = null);
      showWabwaySnack(context, 'Updated from the Receipts link');
      unawaited(_checkLink());
    } catch (_) {
      if (mounted) showWabwaySnack(context, "Couldn't apply the link's changes.", error: true);
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  Future<void> _overwriteRemote() async {
    final ok = await showWabwayConfirm(
      context,
      title: "Replace the link's changes?",
      message: 'The link will show the split as it is in WabWay. Claims and paid marks '
          'made on the link since will be lost.',
      confirmLabel: 'Replace',
    );
    if (!ok || !mounted) return;
    setState(() => _linkBusy = true);
    try {
      final updated =
          await ReceiptsLinkService.overwrite(_receipt, widget.members, homeCurrency: _homeCurrency);
      if (!mounted) return;
      _update(updated);
      unawaited(_checkLink());
    } catch (_) {
      if (mounted) showWabwaySnack(context, "Couldn't update the link.", error: true);
    } finally {
      if (mounted) setState(() => _linkBusy = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final receipt = _receipt;
    final payer = memberById(receipt.paidById, widget.members);
    final net   = receipt.myNetFor(widget.myId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header band
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(kSpace6),
          decoration: BoxDecoration(
            color: receipt.category.softColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(kSpace2),
                    decoration: BoxDecoration(
                      color: receipt.category.color.withValues(alpha: 0.15),
                      borderRadius: kRadiusMd,
                    ),
                    child: Icon(receipt.category.icon, size: 20, color: receipt.category.color),
                  ),
                  const SizedBox(width: kSpace3),
                  WabwayTag(label: receipt.category.label),
                  if (receipt.isFullySettled) ...[
                    const SizedBox(width: kSpace2),
                    const WabwayBadge(label: 'All paid', tone: WabwayBadgeTone.success),
                  ],
                ],
              ),
              const SizedBox(height: kSpace3),
              Text(receipt.title, style: kStyleHeadingSm),
              const SizedBox(height: kSpace1),
              Text(
                fmtDate(receipt.date),
                style: kStyleCaption,
              ),
              const SizedBox(height: kSpace4),
              Text(
                fmtAmount(receipt.amount, receipt.currency),
                style: GoogleFonts.ibmPlexMono(
                  fontSize: kText3xl,
                  fontWeight: FontWeight.w700,
                  color: kColorInk,
                ),
              ),
              // What it came to in the trip's home currency (same as the list).
              if (receipt.isForeignCurrency) ...[
                const SizedBox(height: kSpace1),
                Text(
                  '≈ ${fmtAmount(receipt.homeAmount, _homeCurrency ?? 'CAD')}'
                  '${receipt.transactionFeePct > 0 ? ' incl. ${receipt.transactionFeePct.toStringAsFixed(1)}% card fee' : ''}',
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: kTextBase,
                    fontWeight: FontWeight.w500,
                    color: kColorInkSoft,
                  ),
                ),
              ],
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Paid by
              _InfoRow(
                icon: Icons.person_rounded,
                label: 'Paid by',
                value: payer.label,
              ),

              // Still outstanding for you
              if (net.abs() > 0.01) ...[
                const SizedBox(height: kSpace3),
                _InfoRow(
                  icon: net > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  label: net > 0 ? 'You are still owed' : 'You still owe',
                  value: joinNonEmpty([
                    fmtAmount(net.abs(), receipt.currency),
                    if (receipt.isForeignCurrency) '≈ ${fmtAmount(net.abs() * receipt.homeRate, _homeCurrency ?? 'CAD')}',
                  ], '  '),
                  valueColor: net > 0 ? kColorSuccess : kColorDanger,
                ),
              ],

              if (receipt.notes != null) ...[
                const SizedBox(height: kSpace3),
                _InfoRow(
                  icon: Icons.notes_rounded,
                  label: 'Notes',
                  value: receipt.notes!,
                ),
              ],

              const SizedBox(height: kSpace5),
              const Divider(height: 1),
              const SizedBox(height: kSpace5),

              // Split breakdown
              Text('Split', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              const SizedBox(height: kSpace3),
              if (receipt.splits.length > 1 && receipt.amount > 0) ...[
                _SplitBar(splits: receipt.splits, total: receipt.amount),
                const SizedBox(height: kSpace3),
              ],
              ...receipt.splits.map((s) => _SplitRow(
                    split:    s,
                    currency: receipt.currency,
                    paidById: receipt.paidById,
                    members:  widget.members,
                    total:    receipt.amount,
                    // What each share comes to at home (so everyone knows
                    // what to send) — at the rate actually paid.
                    homeCurrency: receipt.isForeignCurrency ? _homeCurrency : null,
                    homeRate: receipt.homeRate,
                    busy:     _busyShares.contains(s.memberId),
                    onToggle: s.memberId != receipt.paidById && _canSettle(s)
                        ? () => _toggleShare(s)
                        : null,
                  )),

              if (receipt.isItemized) ...[
                const SizedBox(height: kSpace3),
                _ItemBreakdown(
                  items: receipt.items!,
                  members: widget.members,
                  currency: receipt.currency,
                ),
              ],

              const SizedBox(height: kSpace5),
              _LinkCard(
                receipt:      receipt,
                members:      widget.members,
                remote:       _remote,
                remoteChanged: _remoteChanged,
                checking:     _checkingLink,
                busy:         _linkBusy,
                queued:       _linkQueued,
                canEdit:      _canEdit,
                onCreate:     _createLink,
                onShare:      _shareLink,
                onRefresh:    _checkLink,
                onApply:      _applyRemote,
                onOverwrite:  _overwriteRemote,
              ),

              const SizedBox(height: kSpace5),
              const Divider(height: 1),
              const SizedBox(height: kSpace5),

              AttachedDocsSection(
                entityType: EntityType.receipt,
                entityId:   receipt.id,
                tripId:     widget.tripId,
                entityName: receipt.title,
                uploadType: DocType.receipt,
                emptyText:  'Nothing attached yet. Attach the receipt photo, invoice or booking.',
              ),
              const SizedBox(height: kSpace5),


              if (widget.onUpdated != null) ...[
                WabwayButton(
                  label: 'Edit receipt',
                  icon: Icons.edit_rounded,
                  variant: WabwayButtonVariant.ghost,
                  fullWidth: true,
                  onPressed: () async {
                    final updated = await _openEditor(context, ref,
                        receipt: receipt, tripId: widget.tripId,
                        myId: widget.myId, members: widget.members);
                    if (updated != null && mounted) _update(updated);
                  },
                ),
                const SizedBox(height: kSpace3),
              ],

              if (widget.onDelete != null) ...[
                WabwayButton(
                  label: 'Delete receipt',
                  icon: Icons.delete_outline_rounded,
                  variant: WabwayButtonVariant.dangerOutline,
                  fullWidth: true,
                  onPressed: () async {
                    final ok = await _confirmDelete(context, receipt.title);
                    if (ok && mounted) widget.onDelete!();
                  },
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: kColorInkSoft),
        const SizedBox(width: kSpace2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: kStyleCaption),
              Text(
                value,
                style: kStyleBodyMedium.copyWith(color: valueColor ?? kColorInk),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Split proportion bar ─────────────────────────────────────────────────────

class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.splits, required this.total});
  final List<ReceiptSplit> splits;
  final double total;

  @override
  Widget build(BuildContext context) {
    const barColors = [
      Color(0xFF4A7AB5), Color(0xFFD6A84F), Color(0xFF7D9A75),
      Color(0xFFA97BB5), Color(0xFF4A9B8A), Color(0xFF6F665D),
    ];
    return ClipRRect(
      borderRadius: kRadiusPill,
      child: SizedBox(
        height: 8,
        child: Row(
          children: splits.asMap().entries.map((e) {
            final fraction = total > 0 ? (e.value.amount / total).clamp(0.0, 1.0) : 0.0;
            return Expanded(
              flex: (fraction * 1000).round(),
              child: Container(color: barColors[e.key % barColors.length]),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.split,
    required this.currency,
    required this.paidById,
    required this.members,
    this.total = 0,
    this.homeCurrency,
    this.homeRate = 1,
    this.busy = false,
    this.onToggle,
  });

  final ReceiptSplit split;
  final String currency;

  /// Set for a foreign-currency receipt: the share is also shown in it.
  final String? homeCurrency;
  final double homeRate;
  final String paidById;
  final List<TripMember> members;
  final double total;
  final bool busy;
  /// Null when you can't change this share (or it's the payer's own).
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final member  = memberById(split.memberId, members);
    final isPayer = split.memberId == paidById;

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace3),
      child: Row(
        children: [
          WabwayAvatar(name: member.name, size: WabwayAvatarSize.sm),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.label,
                  style: kStyleBodyMedium,
                ),
                if (isPayer)
                  Text('paid the bill', style: kStyleCaption)
                else if (split.isSettled)
                  Text(
                    split.settledAt != null ? 'paid · ${fmtDate(split.settledAt!)}' : 'paid',
                    style: kStyleCaption.copyWith(color: kColorSuccess),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                fmtAmount(split.amount, currency),
                style: GoogleFonts.ibmPlexMono(
                  fontSize: kTextSm,
                  fontWeight: FontWeight.w500,
                  color: split.isSettled ? kColorInkSoft : kColorInk,
                  decoration: split.isSettled ? TextDecoration.lineThrough : null,
                ),
              ),
              if (homeCurrency != null)
                Text(
                  '≈ ${fmtAmount(split.amount * homeRate, homeCurrency!)}',
                  style: GoogleFonts.ibmPlexMono(fontSize: 12, color: kColorInkSoft),
                ),
              if (total > 0)
                Text(
                  '${(split.amount / total * 100).toStringAsFixed(0)}%',
                  style: kStyleCaption.copyWith(color: kColorInkSoft, fontSize: 11),
                ),
            ],
          ),
          if (!isPayer) ...[
            const SizedBox(width: kSpace2),
            SizedBox(
              width: 92,
              child: busy
                  ? const Center(
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kColorPrimary),
                      ),
                    )
                  : split.isSettled
                      ? TextButton.icon(
                          onPressed: onToggle,
                          icon: const Icon(Icons.check_circle_rounded, size: 16, color: kColorSuccess),
                          label: Text('Paid', style: kStyleCaptionMedium.copyWith(color: kColorSuccess)),
                        )
                      : onToggle == null
                          ? const SizedBox.shrink()
                          : WabwayButton(
                              label: 'Mark paid',
                              size: WabwayButtonSize.sm,
                              variant: WabwayButtonVariant.ghost,
                              onPressed: onToggle,
                            ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Item breakdown ───────────────────────────────────────────────────────────

class _ItemBreakdown extends StatelessWidget {
  const _ItemBreakdown({required this.items, required this.members, required this.currency});
  final ReceiptItemization items;
  final List<TripMember> members;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final shares = items.itemSharesByMember();
    final totals = items.personTotals(members.map((m) => m.id));
    final unclaimed = items.unclaimed;
    return Container(
      decoration: BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: const Icon(Icons.receipt_long_rounded, color: kColorInkSoft),
          title: Text('Who had what', style: kStyleBodyMedium),
          subtitle: Text(
            '${pluralize(items.items.length, 'item')}'
            '${items.extras.abs() > 0.005 ? ' · tax & tip shared by what each had' : ''}',
            style: kStyleCaption,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
          children: [
            for (final m in members)
              if (shares[m.id]?.isNotEmpty ?? false) ...[
                Padding(
                  padding: const EdgeInsets.only(top: kSpace2, bottom: kSpace1),
                  child: Row(
                    children: [
                      WabwayAvatar(name: m.name, size: WabwayAvatarSize.xs),
                      const SizedBox(width: kSpace2),
                      Expanded(child: Text(m.label, style: kStyleBodySemibold)),
                      Text(fmtAmount(totals[m.id] ?? 0, currency), style: kStyleBodySemibold),
                    ],
                  ),
                ),
                for (final sh in shares[m.id]!)
                  _Line(sh.item.quantity > 1 ? '${fmtQty(sh.item.quantity)}× ${sh.item.name}' : sh.item.name,
                      fmtAmount(sh.share, currency)),
                if (items.extras.abs() > 0.005)
                  _Line('Tax / tip share',
                      fmtAmount((totals[m.id] ?? 0) - shares[m.id]!.fold(0.0, (a, s) => a + s.share), currency)),
              ],
            if (unclaimed.isNotEmpty) ...[
              const SizedBox(height: kSpace2),
              Text('Not claimed (payer covers)', style: kStyleCaptionMedium.copyWith(color: kColorWarning)),
              for (final u in unclaimed) _Line(u.item.name, fmtAmount(u.amount, currency)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: kSpace6, bottom: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: kStyleCaption.copyWith(color: kColorInk))),
          Text(value, style: kStyleCaption.copyWith(color: kColorInk)),
        ],
      ),
    );
  }
}

// ─── Receipts link card ───────────────────────────────────────────────────────

class _LinkCard extends StatelessWidget {
  const _LinkCard({
    required this.receipt,
    required this.members,
    required this.remote,
    required this.remoteChanged,
    required this.checking,
    required this.busy,
    required this.queued,
    required this.canEdit,
    required this.onCreate,
    required this.onShare,
    required this.onRefresh,
    required this.onApply,
    required this.onOverwrite,
  });

  final Receipt receipt;
  final List<TripMember> members;
  final RemoteSplit? remote;
  final bool remoteChanged;
  final bool checking;
  final bool busy;
  final bool queued;
  final bool canEdit;
  final VoidCallback onCreate;
  final VoidCallback onShare;
  final VoidCallback onRefresh;
  final VoidCallback onApply;
  final VoidCallback onOverwrite;

  /// What differs between the link and WabWay, per person.
  List<String> _changes() {
    final r = remote;
    if (r == null) return const [];
    final ids = members.map((m) => m.id);
    final now = {for (final s in receipt.splits) s.memberId: s};
    final remoteTotals = r.items.personTotals(ids);
    final out = <String>[];
    for (final m in members) {
      final before = now[m.id]?.amount ?? 0;
      final after = remoteTotals[m.id] ?? 0;
      if ((before - after).abs() >= 0.01) {
        out.add('${m.label}: ${fmtAmount(before, receipt.currency)} → ${fmtAmount(after, receipt.currency)}');
      }
      if (m.id != receipt.paidById && r.paidMemberIds.contains(m.id) && !(now[m.id]?.isSettled ?? false)) {
        out.add('${m.label} marked paid');
      }
    }
    if (r.unknownPeople.isNotEmpty) {
      out.add('Not in the trip: ${r.unknownPeople.join(', ')} (their part stays with the payer)');
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final id = receipt.splitLinkId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.link_rounded, size: 18, color: kColorInkSoft),
              const SizedBox(width: kSpace2),
              Expanded(child: Text('Receipts link', style: kStyleBodyMedium)),
              if (id != null)
                checking
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: kColorInkSoft),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        color: kColorInkSoft,
                        tooltip: 'Check for changes',
                        visualDensity: VisualDensity.compact,
                        onPressed: onRefresh,
                      ),
            ],
          ),
          const SizedBox(height: kSpace1),
          if (id == null && queued)
            Text("Will be created when you're back online.", style: kStyleCaption)
          else if (id == null) ...[
            Text('Let people claim items and mark themselves paid on receipts.wabble.ca — '
                'no account needed.', style: kStyleCaption),
            const SizedBox(height: kSpace2),
            WabwayButton(
              label: 'Create link',
              icon: Icons.add_link_rounded,
              size: WabwayButtonSize.sm,
              variant: WabwayButtonVariant.secondary,
              loading: busy,
              onPressed: busy ? null : onCreate,
            ),
          ] else ...[
            SelectableText(receiptsLinkUrl(id),
                style: kStyleCaption.copyWith(color: kColorPrimary)),
            const SizedBox(height: kSpace2),
            Wrap(
              spacing: kSpace2,
              runSpacing: kSpace2,
              children: [
                WabwayButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  size: WabwayButtonSize.sm,
                  variant: WabwayButtonVariant.secondary,
                  onPressed: onShare,
                ),
                WabwayButton(
                  label: 'Copy',
                  icon: Icons.copy_rounded,
                  size: WabwayButtonSize.sm,
                  variant: WabwayButtonVariant.ghost,
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: receiptsLinkUrl(id)));
                    showWabwaySnack(context, 'Link copied');
                  },
                ),
                WabwayButton(
                  label: 'Open',
                  icon: Icons.open_in_new_rounded,
                  size: WabwayButtonSize.sm,
                  variant: WabwayButtonVariant.ghost,
                  onPressed: () => launchUrl(Uri.parse(receiptsLinkUrl(id)),
                      mode: LaunchMode.externalApplication),
                ),
              ],
            ),
            if (remoteChanged) ...[
              const SizedBox(height: kSpace3),
              Container(
                padding: const EdgeInsets.all(kSpace3),
                decoration: const BoxDecoration(color: kColorWarningSoft, borderRadius: kRadiusMd),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Changes on the link', style: kStyleBodySemibold),
                    const SizedBox(height: kSpace1),
                    for (final c in _changes()) Text('• $c', style: kStyleCaption.copyWith(color: kColorInk)),
                    if (_changes().isEmpty)
                      Text('Items or claims were edited on the link.', style: kStyleCaption),
                    const SizedBox(height: kSpace2),
                    if (canEdit)
                      Wrap(
                        spacing: kSpace2,
                        runSpacing: kSpace2,
                        children: [
                          WabwayButton(
                            label: 'Apply to WabWay',
                            icon: Icons.download_rounded,
                            size: WabwayButtonSize.sm,
                            loading: busy,
                            onPressed: busy ? null : onApply,
                          ),
                          WabwayButton(
                            label: "Keep WabWay's",
                            size: WabwayButtonSize.sm,
                            variant: WabwayButtonVariant.ghost,
                            onPressed: busy ? null : onOverwrite,
                          ),
                        ],
                      )
                    else
                      Text(
                        'Only ${memberById(receipt.paidById, members).label} (who paid) '
                        'or the organiser can apply these.',
                        style: kStyleCaption,
                      ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
