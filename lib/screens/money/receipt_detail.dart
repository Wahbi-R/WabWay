import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase/client.dart';
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

// ─── Mobile full-screen route ─────────────────────────────────────────────────

class ReceiptDetailScreen extends StatefulWidget {
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
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  late Receipt _receipt;

  @override
  void initState() {
    super.initState();
    _receipt = widget.receipt;
  }

  Future<void> _editReceipt() async {
    final updated = await showAddReceiptSheet(
      context,
      tripId:          widget.tripId,
      userId:          widget.myId,
      members:         widget.members,
      existingReceipt: _receipt,
    );
    if (updated != null && mounted) {
      setState(() => _receipt = updated);
      widget.onUpdated?.call(updated);
    }
  }

  Future<void> _duplicateReceipt() async {
    await showAddReceiptSheet(
      context,
      tripId:          widget.tripId,
      userId:          widget.myId,
      members:         widget.members,
      existingReceipt: _receipt,
      isDuplicate:     true,
    );
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
          onUpdated: (r) {
            setState(() => _receipt = r);
            widget.onUpdated?.call(r);
          },
        ),
      ),
    );
  }
}

// ─── Shared detail content ────────────────────────────────────────────────────

class ReceiptDetailContent extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final payer = memberById(receipt.paidById, members);
    final net   = receipt.myNetFor(myId);

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

              // Net for you
              if (net.abs() > 0.01) ...[
                const SizedBox(height: kSpace3),
                _InfoRow(
                  icon: net > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  label: net > 0 ? 'You are owed' : 'You owe',
                  value: fmtAmount(net.abs(), receipt.currency),
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
                    members:  members,
                    total:    receipt.amount,
                  )),

              const SizedBox(height: kSpace5),
              const Divider(height: 1),
              const SizedBox(height: kSpace5),

              AttachedDocsSection(
                entityType: EntityType.receipt,
                entityId:   receipt.id,
                tripId:     tripId,
                entityName: receipt.title,
                uploadType: DocType.receipt,
                emptyText:  'Nothing attached yet. Attach the receipt photo, invoice or booking.',
              ),
              const SizedBox(height: kSpace5),


              if (onUpdated != null) ...[
                WabwayButton(
                  label: 'Edit receipt',
                  icon: Icons.edit_rounded,
                  variant: WabwayButtonVariant.ghost,
                  fullWidth: true,
                  onPressed: () async {
                    final myId = supabase.auth.currentUser?.id ?? this.myId;
                    final updated = await showAddReceiptSheet(
                      context,
                      tripId:          tripId,
                      userId:          myId,
                      members:         members,
                      existingReceipt: receipt,
                    );
                    if (updated != null && context.mounted) {
                      onUpdated!(updated);
                    }
                  },
                ),
                const SizedBox(height: kSpace3),
              ],

              if (onDelete != null) ...[
                WabwayButton(
                  label: 'Delete receipt',
                  icon: Icons.delete_outline_rounded,
                  variant: WabwayButtonVariant.dangerOutline,
                  fullWidth: true,
                  onPressed: () async {
                    final ok = await _confirmDelete(context, receipt.title);
                    if (ok && context.mounted) onDelete!();
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
  });

  final ReceiptSplit split;
  final String currency;
  final String paidById;
  final List<TripMember> members;
  final double total;

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
                  member.name,
                  style: kStyleBodyMedium,
                ),
                if (isPayer)
                  Text('paid', style: kStyleCaption),
              ],
            ),
          ),
          if (split.isSettled)
            const Padding(
              padding: EdgeInsets.only(right: kSpace2),
              child: Icon(Icons.check_circle_rounded, size: 14, color: kColorSuccess),
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
              if (total > 0)
                Text(
                  '${(split.amount / total * 100).toStringAsFixed(0)}%',
                  style: kStyleCaption.copyWith(color: kColorInkSoft, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

