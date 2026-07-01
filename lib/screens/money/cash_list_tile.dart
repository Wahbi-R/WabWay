import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

class CashListTile extends StatelessWidget {
  const CashListTile({
    super.key,
    required this.withdrawal,
    this.selected = false,
    this.onTap,
  });

  final CashWithdrawal withdrawal;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final who = memberById(withdrawal.withdrawnById);
    final net = withdrawal.myNet;
    final netColor = net > 0.01
        ? kColorSuccess
        : net < -0.01
            ? kColorDanger
            : kColorInkSoft;

    return WabwayCard(
      hoverable: true,
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: kColorAccentSoft,
                borderRadius: kRadiusMd,
              ),
              child: const Icon(Icons.atm_rounded, size: 18, color: kColorAccent),
            ),
            const SizedBox(width: kSpace3),

            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ATM Withdrawal', style: kStyleBodySemibold),
                  const SizedBox(height: 2),
                  Text(
                    '${who.isYou ? 'You' : who.name} withdrew · ${fmtDate(withdrawal.date)}'
                    '${withdrawal.atmFee > 0 ? ' · Fee: ${fmtAmount(withdrawal.atmFee, withdrawal.currency)}' : ''}',
                    style: kStyleCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpace3),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtAmount(withdrawal.amount, withdrawal.currency),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: kTextBase,
                    fontWeight: FontWeight.w600,
                    color: kColorInk,
                  ),
                ),
                const SizedBox(height: 2),
                if (net.abs() > 0.01)
                  Text(
                    '${net > 0 ? '+' : ''}${fmtAmount(net, withdrawal.currency)}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: kTextXs,
                      fontWeight: FontWeight.w500,
                      color: netColor,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
