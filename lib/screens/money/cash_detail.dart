import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// ─── Mobile full-screen route ─────────────────────────────────────────────────

class CashDetailScreen extends StatelessWidget {
  const CashDetailScreen({super.key, required this.withdrawal});
  final CashWithdrawal withdrawal;

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
        title: Text('ATM Withdrawal', style: kStyleTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: kSpace12),
        child: CashDetailContent(withdrawal: withdrawal),
      ),
    );
  }
}

// ─── Shared content ───────────────────────────────────────────────────────────

class CashDetailContent extends StatelessWidget {
  const CashDetailContent({super.key, required this.withdrawal});
  final CashWithdrawal withdrawal;

  @override
  Widget build(BuildContext context) {
    final who = memberById(withdrawal.withdrawnById);
    final net = withdrawal.myNet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header band
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(kSpace6),
          decoration: const BoxDecoration(color: kColorAccentSoft),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(kSpace2),
                    decoration: BoxDecoration(
                      color: kColorAccent.withValues(alpha: 0.15),
                      borderRadius: kRadiusMd,
                    ),
                    child: const Icon(Icons.atm_rounded, size: 20, color: kColorAccent),
                  ),
                  const SizedBox(width: kSpace3),
                  const WabwayTag(label: 'Cash / ATM'),
                ],
              ),
              const SizedBox(height: kSpace3),
              Text('ATM Withdrawal', style: kStyleHeadingSm),
              const SizedBox(height: kSpace1),
              Text(fmtDate(withdrawal.date), style: kStyleCaption),
              const SizedBox(height: kSpace4),
              Text(
                fmtAmount(withdrawal.amount, withdrawal.currency),
                style: GoogleFonts.ibmPlexMono(
                  fontSize: kText3xl,
                  fontWeight: FontWeight.w700,
                  color: kColorInk,
                ),
              ),
              if (withdrawal.atmFee > 0) ...[
                const SizedBox(height: kSpace1),
                Text(
                  '+ ${fmtAmount(withdrawal.atmFee, withdrawal.currency)} ATM fee',
                  style: kStyleCaption,
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
              // Withdrawn by
              Row(
                children: [
                  const Icon(Icons.person_rounded, size: 16, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Withdrawn by', style: kStyleCaption),
                      Text(who.isYou ? 'You' : who.name, style: kStyleBodyMedium),
                    ],
                  ),
                ],
              ),

              if (net.abs() > 0.01) ...[
                const SizedBox(height: kSpace3),
                Row(
                  children: [
                    Icon(
                      net > 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                      size: 16,
                      color: kColorInkSoft,
                    ),
                    const SizedBox(width: kSpace2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(net > 0 ? 'You are owed' : 'You owe', style: kStyleCaption),
                        Text(
                          fmtAmount(net.abs(), withdrawal.currency),
                          style: kStyleBodyMedium.copyWith(
                              color: net > 0 ? kColorSuccess : kColorDanger),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              if (withdrawal.notes != null) ...[
                const SizedBox(height: kSpace3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.notes_rounded, size: 16, color: kColorInkSoft),
                    const SizedBox(width: kSpace2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Notes', style: kStyleCaption),
                          Text(withdrawal.notes!, style: kStyleBodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: kSpace5),
              const Divider(height: 1),
              const SizedBox(height: kSpace5),

              // Distribution table
              Text('Cash distributed', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              const SizedBox(height: kSpace3),
              ...withdrawal.distributions.map((d) => _DistRow(
                    dist: d,
                    currency: withdrawal.currency,
                  )),

              const SizedBox(height: kSpace5),
              const Divider(height: 1),
              const SizedBox(height: kSpace5),

              // Attach placeholder
              const WabwayAttachPlaceholder(label: 'Attach ATM slip'),
            ],
          ),
        ),
      ],
    );
  }
}

class _DistRow extends StatelessWidget {
  const _DistRow({required this.dist, required this.currency});
  final CashDistribution dist;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final member = memberById(dist.memberId);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace3),
      child: Row(
        children: [
          WabwayAvatar(name: member.isYou ? 'You' : member.name, size: WabwayAvatarSize.sm),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Text(member.isYou ? 'You' : member.name, style: kStyleBodyMedium),
          ),
          Text(
            fmtAmount(dist.amount, currency),
            style: GoogleFonts.ibmPlexMono(
              fontSize: kTextSm,
              fontWeight: FontWeight.w500,
              color: kColorInk,
            ),
          ),
        ],
      ),
    );
  }
}
