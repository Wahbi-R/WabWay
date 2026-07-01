import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

class SettleUpPanel extends StatefulWidget {
  const SettleUpPanel({
    super.key,
    required this.balances,
    required this.suggestions,
    required this.currency,
    this.scrollController,
  });

  final List<MemberBalance> balances;
  final List<SettlementSuggestion> suggestions;
  final String currency;
  final ScrollController? scrollController;

  @override
  State<SettleUpPanel> createState() => _SettleUpPanelState();
}

class _SettleUpPanelState extends State<SettleUpPanel> {
  late final List<SettlementSuggestion> _suggestions;

  @override
  void initState() {
    super.initState();
    _suggestions = List.from(widget.suggestions);
  }

  void _markSettled(SettlementSuggestion s) {
    setState(() => s.isSettled = true);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Marked as settled', style: kStyleBody.copyWith(color: Colors.white)),
      backgroundColor: kColorSuccess,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final totalOwedToYou = widget.balances
        .where((b) => b.net > 0)
        .fold(0.0, (a, b) => a + b.net);
    final totalYouOwe = widget.balances
        .where((b) => b.net < 0)
        .fold(0.0, (a, b) => a + b.net.abs());

    final owedToYou = widget.balances.where((b) => b.net > 0.5).toList();
    final youOwe    = widget.balances.where((b) => b.net < -0.5).toList();

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance overview card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(kSpace4),
            decoration: BoxDecoration(
              color: kColorPaper,
              borderRadius: kRadiusLg,
              border: Border.all(color: kColorBorder),
              boxShadow: kShadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Balance overview', style: kStyleBodySemibold),
                const SizedBox(height: kSpace4),
                Row(
                  children: [
                    Expanded(
                      child: _BalanceTile(
                        label: 'Owed to you',
                        amount: totalOwedToYou,
                        currency: widget.currency,
                        color: kColorSuccess,
                        softColor: kColorSuccessSoft,
                      ),
                    ),
                    const SizedBox(width: kSpace3),
                    Expanded(
                      child: _BalanceTile(
                        label: 'You owe',
                        amount: totalYouOwe,
                        currency: widget.currency,
                        color: kColorDanger,
                        softColor: kColorDangerSoft,
                      ),
                    ),
                  ],
                ),
                if (totalOwedToYou > 0 || totalYouOwe > 0) ...[
                  const SizedBox(height: kSpace3),
                  const Divider(height: 1),
                  const SizedBox(height: kSpace3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Net balance', style: kStyleCaptionMedium),
                      Text(
                        (totalOwedToYou - totalYouOwe) >= 0
                            ? '+${fmtAmount(totalOwedToYou - totalYouOwe, widget.currency)}'
                            : '-${fmtAmount((totalOwedToYou - totalYouOwe).abs(), widget.currency)}',
                        style: GoogleFonts.ibmPlexMono(
                          fontSize: kTextBase,
                          fontWeight: FontWeight.w600,
                          color: (totalOwedToYou - totalYouOwe) >= 0
                              ? kColorSuccess
                              : kColorDanger,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: kSpace5),

          // Who owes you
          if (owedToYou.isNotEmpty) ...[
            Text('Owed to you', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const SizedBox(height: kSpace2),
            ...owedToYou.map((b) => _BalanceRow(
                  balance: b,
                  currency: widget.currency,
                  onSettle: () {
                    final s = _suggestions.where((s) =>
                        s.fromMemberId == b.member.id && !s.isSettled).firstOrNull;
                    if (s != null) _markSettled(s);
                  },
                )),
            const SizedBox(height: kSpace4),
          ],

          // You owe
          if (youOwe.isNotEmpty) ...[
            Text('You owe', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const SizedBox(height: kSpace2),
            ...youOwe.map((b) => _BalanceRow(
                  balance: b,
                  currency: widget.currency,
                  isYouOwe: true,
                  onSettle: () {
                    final s = _suggestions.where((s) =>
                        s.toMemberId == b.member.id && !s.isSettled).firstOrNull;
                    if (s != null) _markSettled(s);
                  },
                )),
            const SizedBox(height: kSpace4),
          ],

          if (owedToYou.isEmpty && youOwe.isEmpty)
            const WabwayEmptyState(
              icon: Icons.check_circle_rounded,
              title: 'All settled up',
              description: 'No outstanding balances.',
            ),

          // Suggested settlements
          if (_suggestions.isNotEmpty) ...[
            Text('Suggested payments', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const SizedBox(height: kSpace2),
            ..._suggestions.map((s) => _SettlementRow(
                  suggestion: s,
                  currency: widget.currency,
                  onMark: () => _markSettled(s),
                )),
          ],
        ],
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.label,
    required this.amount,
    required this.currency,
    required this.color,
    required this.softColor,
  });

  final String label;
  final double amount;
  final String currency;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: kRadiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: kStyleCaption),
          const SizedBox(height: kSpace1),
          Text(
            fmtAmount(amount, currency),
            style: GoogleFonts.ibmPlexMono(
              fontSize: kTextMd,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({
    required this.balance,
    required this.currency,
    this.isYouOwe = false,
    required this.onSettle,
  });

  final MemberBalance balance;
  final String currency;
  final bool isYouOwe;
  final VoidCallback onSettle;

  @override
  Widget build(BuildContext context) {
    final amount = balance.net.abs();
    final color  = isYouOwe ? kColorDanger : kColorSuccess;

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: WabwayCard(
        padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
        child: Row(
          children: [
            WabwayAvatar(name: balance.member.name, size: WabwayAvatarSize.sm),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(balance.member.name, style: kStyleBodyMedium),
                  Text(
                    isYouOwe
                        ? 'You owe ${balance.member.name}'
                        : '${balance.member.name} owes you',
                    style: kStyleCaption,
                  ),
                ],
              ),
            ),
            Text(
              fmtAmount(amount, currency),
              style: GoogleFonts.ibmPlexMono(
                fontSize: kTextBase,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: kSpace3),
            WabwayButton(
              label: 'Settled',
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: onSettle,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettlementRow extends StatelessWidget {
  const _SettlementRow({
    required this.suggestion,
    required this.currency,
    required this.onMark,
  });

  final SettlementSuggestion suggestion;
  final String currency;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final from = memberById(suggestion.fromMemberId);
    final to   = memberById(suggestion.toMemberId);

    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: WabwayCard(
        padding: const EdgeInsets.all(kSpace4),
        child: Row(
          children: [
            if (suggestion.isSettled)
              const Icon(Icons.check_circle_rounded, size: 16, color: kColorSuccess)
            else
              const Icon(Icons.arrow_forward_rounded, size: 16, color: kColorInkSoft),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Text(
                '${from.isYou ? 'You' : from.name} → ${to.isYou ? 'You' : to.name}',
                style: kStyleBodyMedium.copyWith(
                  decoration: suggestion.isSettled ? TextDecoration.lineThrough : null,
                  color: suggestion.isSettled ? kColorInkSoft : kColorInk,
                ),
              ),
            ),
            Text(
              fmtAmount(suggestion.amount, suggestion.currency),
              style: GoogleFonts.ibmPlexMono(
                fontSize: kTextBase,
                fontWeight: FontWeight.w600,
                color: suggestion.isSettled ? kColorInkSoft : kColorInk,
              ),
            ),
            if (!suggestion.isSettled) ...[
              const SizedBox(width: kSpace3),
              WabwayButton(
                label: 'Mark settled',
                variant: WabwayButtonVariant.ghost,
                size: WabwayButtonSize.sm,
                onPressed: onMark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
