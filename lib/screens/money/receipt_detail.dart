import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// ─── Mobile full-screen route ─────────────────────────────────────────────────

class ReceiptDetailScreen extends StatelessWidget {
  const ReceiptDetailScreen({super.key, required this.receipt});
  final Receipt receipt;

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
        title: Text(receipt.title, style: kStyleTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: kSpace12),
        child: ReceiptDetailContent(receipt: receipt),
      ),
    );
  }
}

// ─── Shared detail content ────────────────────────────────────────────────────

class ReceiptDetailContent extends StatelessWidget {
  const ReceiptDetailContent({super.key, required this.receipt});
  final Receipt receipt;

  @override
  Widget build(BuildContext context) {
    final payer = memberById(receipt.paidById);
    final net = receipt.myNet;

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
                value: payer.isYou ? 'You' : payer.name,
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
                    split: s,
                    currency: receipt.currency,
                    paidById: receipt.paidById,
                  )),

              const SizedBox(height: kSpace5),
              const Divider(height: 1),
              const SizedBox(height: kSpace5),

              // Attach receipt placeholder
              _AttachPlaceholder(),
            ],
          ),
        ),
      ],
    );
  }
}

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
  });

  final ReceiptSplit split;
  final String currency;
  final String paidById;

  @override
  Widget build(BuildContext context) {
    final member = memberById(split.memberId);
    final isPayer = split.memberId == paidById;

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace3),
      child: Row(
        children: [
          WabwayAvatar(name: member.isYou ? 'You' : member.name, size: WabwayAvatarSize.sm),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.isYou ? 'You' : member.name,
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

class _AttachPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: kSpace6),
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.attach_file_rounded, size: 24, color: kColorInkSoft),
          const SizedBox(height: kSpace2),
          Text('Attach receipt photo', style: kStyleCaption),
        ],
      ),
    );
  }
}
