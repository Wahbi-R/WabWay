import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/doc_service.dart';
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'add_receipt_sheet.dart';

// ─── Confirmation helper ──────────────────────────────────────────────────────

Future<bool> _confirmDelete(BuildContext context, String title) async {
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete?'),
          content: Text(
              'This will permanently remove "$title" for everyone in the trip.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete',
                  style: TextStyle(color: kColorDanger)),
            ),
          ],
        ),
      ) ??
      false;
}

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
          if (widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: kColorDanger,
              onPressed: () async {
                final ok = await _confirmDelete(context, _receipt.title);
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  widget.onDelete!();
                }
              },
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
          onDelete:  widget.onDelete,
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
                value: payer.name,
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
              ...receipt.splits.map((s) => _SplitRow(
                    split:    s,
                    currency: receipt.currency,
                    paidById: receipt.paidById,
                    members:  members,
                  )),

              const SizedBox(height: kSpace5),
              const Divider(height: 1),
              const SizedBox(height: kSpace5),

              _LinkedDocsSection(key: ValueKey(receipt.hashCode), receiptId: receipt.id),


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
                  variant: WabwayButtonVariant.ghost,
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

// ─── Linked documents section ────────────────────────────────────────────────

class _LinkedDocsSection extends StatefulWidget {
  const _LinkedDocsSection({required this.receiptId});
  final String receiptId;

  @override
  State<_LinkedDocsSection> createState() => _LinkedDocsSectionState();
}

class _LinkedDocsSectionState extends State<_LinkedDocsSection> {
  List<TripDocument>? _docs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final docs = await DocService.loadLinkedDocuments(
        linkedType: DocLinkedType.receipt,
        linkedId:   widget.receiptId,
      );
      if (mounted) setState(() => _docs = docs);
    } catch (_) {
      if (mounted) setState(() => _docs = []);
    }
  }

  Future<void> _open(TripDocument doc) async {
    if (doc.storagePath == null) return;
    final url = await DocService.getSignedUrl(doc.storagePath!);
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    if (_docs == null || _docs!.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Documents', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace3),
        ..._docs!.map((doc) => Padding(
          padding: const EdgeInsets.only(bottom: kSpace2),
          child: _DocRow(doc: doc, onTap: () => _open(doc)),
        )),
        const SizedBox(height: kSpace3),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc, required this.onTap});
  final TripDocument doc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: doc.storagePath != null ? onTap : null,
      borderRadius: kRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
        decoration: BoxDecoration(
          color: kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border: Border.all(color: kColorBorder),
        ),
        child: Row(
          children: [
            Icon(doc.type.icon, size: 18, color: kColorInkSoft),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Text(doc.title, style: kStyleBodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (doc.storagePath != null)
              const Icon(Icons.open_in_new_rounded, size: 16, color: kColorInkSoft),
          ],
        ),
      ),
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

class _SplitRow extends StatelessWidget {
  const _SplitRow({
    required this.split,
    required this.currency,
    required this.paidById,
    required this.members,
  });

  final ReceiptSplit split;
  final String currency;
  final String paidById;
  final List<TripMember> members;

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
          Text(
            fmtAmount(split.amount, currency),
            style: GoogleFonts.ibmPlexMono(
              fontSize: kTextSm,
              fontWeight: FontWeight.w500,
              color: split.isSettled ? kColorInkSoft : kColorInk,
              decoration: split.isSettled ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

