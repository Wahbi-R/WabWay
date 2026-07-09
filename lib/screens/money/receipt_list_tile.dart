import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

class ReceiptListTile extends StatelessWidget {
  const ReceiptListTile({
    super.key,
    required this.receipt,
    required this.myId,
    required this.members,
    required this.homeCurrency,
    this.selected = false,
    this.onTap,
  });

  final Receipt receipt;
  final String myId;
  final List<TripMember> members;
  final String homeCurrency;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final payer = memberById(receipt.paidById, members);
    final net   = receipt.myNetFor(myId);
    final isPositive = net > 0;
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
            // Category icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: receipt.category.softColor,
                borderRadius: kRadiusMd,
              ),
              child: Icon(
                receipt.category.icon,
                size: 18,
                color: receipt.category.color,
              ),
            ),
            const SizedBox(width: kSpace3),

            // Title + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    receipt.title,
                    style: kStyleBodySemibold,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${payer.name} paid · ${fmtDate(receipt.date)} · ÷${receipt.splits.length}',
                    style: kStyleCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: kSpace3),

            // Amount + net
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fmtAmount(receipt.amount, receipt.currency),
                  style: GoogleFonts.ibmPlexMono(
                    fontSize: kTextBase,
                    fontWeight: FontWeight.w600,
                    color: kColorInk,
                  ),
                ),
                // Show home-currency equivalent when it differs from receipt currency
                if (receipt.isForeignCurrency) ...[
                  const SizedBox(height: 1),
                  Text(
                    '≈ ${fmtAmount(receipt.homeAmount, homeCurrency)}',
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: kTextXs,
                      fontWeight: FontWeight.w400,
                      color: kColorInkSoft,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                if (net.abs() > 0.01)
                  Text(
                    '${isPositive ? '+' : ''}${fmtAmount(net, homeCurrency)}',
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
