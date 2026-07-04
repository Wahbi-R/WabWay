import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/supabase/settlement_service.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

class SettleUpPanel extends StatefulWidget {
  const SettleUpPanel({
    super.key,
    required this.balancesByCurrency,
    required this.suggestionsByCurrency,
    required this.members,
    required this.tripId,
    required this.myId,
    this.existingSettlements = const [],
    this.scrollController,
    this.onSettled,
  });

  final Map<String, List<MemberBalance>> balancesByCurrency;
  final Map<String, List<SettlementSuggestion>> suggestionsByCurrency;
  final List<TripMember> members;
  final String tripId;
  final String myId;
  final List<Settlement> existingSettlements;
  final ScrollController? scrollController;
  final VoidCallback? onSettled;

  @override
  State<SettleUpPanel> createState() => _SettleUpPanelState();
}

class _SettleUpPanelState extends State<SettleUpPanel> {
  // currency → suggestions (with isSettled state)
  late Map<String, List<SettlementSuggestion>> _groupedSuggestions;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initSuggestions();
  }

  @override
  void didUpdateWidget(SettleUpPanel old) {
    super.didUpdateWidget(old);
    if (widget.existingSettlements != old.existingSettlements ||
        widget.suggestionsByCurrency != old.suggestionsByCurrency) {
      _initSuggestions();
    }
  }

  void _initSuggestions() {
    _groupedSuggestions = {};
    for (final entry in widget.suggestionsByCurrency.entries) {
      _groupedSuggestions[entry.key] = entry.value.map((s) {
        final alreadySettled = widget.existingSettlements
            .any((e) => e.matches(s.fromMemberId, s.toMemberId));
        return SettlementSuggestion(
          fromMemberId: s.fromMemberId,
          toMemberId:   s.toMemberId,
          amount:       s.amount,
          currency:     s.currency,
          isSettled:    alreadySettled,
        );
      }).toList();
    }
  }

  Future<void> _markSettled(SettlementSuggestion s) async {
    if (_saving || s.isSettled) return;
    setState(() { _saving = true; s.isSettled = true; });
    try {
      await SettlementService.createSettlement(
        tripId:         widget.tripId,
        fromMemberId:   s.fromMemberId,
        toMemberId:     s.toMemberId,
        amount:         s.amount,
        currency:       s.currency,
        settledBy:      widget.myId,
      );
      widget.onSettled?.call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Settlement saved', style: kStyleBody.copyWith(color: Colors.white)),
          backgroundColor: kColorSuccess,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => s.isSettled = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not save. Try again.', style: kStyleBody.copyWith(color: Colors.white)),
          backgroundColor: kColorDanger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencies = widget.balancesByCurrency.keys.toList()..sort();
    final allBalances = currencies
        .expand((c) => widget.balancesByCurrency[c] ?? [])
        .toList();
    final allSuggestions = currencies
        .expand((c) => _groupedSuggestions[c] ?? [])
        .toList();

    final anyBalance = allBalances.any((b) => b.net.abs() > 0.5);

    return SingleChildScrollView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Per-currency balance sections (or single if one currency)
          for (final currency in currencies) ...[
            _CurrencyBalanceCard(
              currency: currency,
              balances: widget.balancesByCurrency[currency] ?? [],
              suggestions: _groupedSuggestions[currency] ?? [],
              onSettle: _markSettled,
              showCurrencyLabel: currencies.length > 1,
            ),
            const SizedBox(height: kSpace3),
          ],

          if (!anyBalance)
            const WabwayEmptyState(
              icon: Icons.check_circle_rounded,
              title: 'All settled up',
              description: 'No outstanding balances.',
            ),

          // Suggested settlements
          if (allSuggestions.isNotEmpty) ...[
            const SizedBox(height: kSpace2),
            Text('Suggested payments', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const SizedBox(height: kSpace2),
            ...allSuggestions.map((s) => _SettlementRow(
                  suggestion: s,
                  currency:   s.currency,
                  members:    widget.members,
                  onMark:     () => _markSettled(s),
                )),
          ],
        ],
      ),
    );
  }
}

class _CurrencyBalanceCard extends StatelessWidget {
  const _CurrencyBalanceCard({
    required this.currency,
    required this.balances,
    required this.suggestions,
    required this.onSettle,
    required this.showCurrencyLabel,
  });

  final String currency;
  final List<MemberBalance> balances;
  final List<SettlementSuggestion> suggestions;
  final ValueChanged<SettlementSuggestion> onSettle;
  final bool showCurrencyLabel;

  @override
  Widget build(BuildContext context) {
    final totalOwedToYou = balances.where((b) => b.net > 0)
        .fold(0.0, (a, b) => a + b.net);
    final totalYouOwe = balances.where((b) => b.net < 0)
        .fold(0.0, (a, b) => a + b.net.abs());
    final owedToYou = balances.where((b) => b.net > 0.5).toList();
    final youOwe    = balances.where((b) => b.net < -0.5).toList();

    return Container(
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
          if (showCurrencyLabel) ...[
            WabwayBadge(label: currency, tone: WabwayBadgeTone.neutral),
            const SizedBox(height: kSpace3),
          ],
          Text('Balance overview', style: kStyleBodySemibold),
          const SizedBox(height: kSpace4),
          Row(
            children: [
              Expanded(
                child: _BalanceTile(
                  label: 'Owed to you',
                  amount: totalOwedToYou,
                  currency: currency,
                  color: kColorSuccess,
                  softColor: kColorSuccessSoft,
                ),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: _BalanceTile(
                  label: 'You owe',
                  amount: totalYouOwe,
                  currency: currency,
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
                      ? '+${fmtAmount(totalOwedToYou - totalYouOwe, currency)}'
                      : '-${fmtAmount((totalOwedToYou - totalYouOwe).abs(), currency)}',
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
          if (owedToYou.isNotEmpty) ...[
            const SizedBox(height: kSpace4),
            Text('Owed to you', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const SizedBox(height: kSpace2),
            ...owedToYou.map((b) => _BalanceRow(
                  balance: b,
                  currency: currency,
                  onSettle: () {
                    final s = suggestions.where((s) =>
                        s.fromMemberId == b.member.id && !s.isSettled).firstOrNull;
                    if (s != null) onSettle(s);
                  },
                  isSettled: suggestions.where((s) => s.fromMemberId == b.member.id)
                      .any((s) => s.isSettled),
                )),
          ],
          if (youOwe.isNotEmpty) ...[
            const SizedBox(height: kSpace4),
            Text('You owe', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const SizedBox(height: kSpace2),
            ...youOwe.map((b) => _BalanceRow(
                  balance: b,
                  currency: currency,
                  isYouOwe: true,
                  onSettle: () {
                    final s = suggestions.where((s) =>
                        s.toMemberId == b.member.id && !s.isSettled).firstOrNull;
                    if (s != null) onSettle(s);
                  },
                  isSettled: suggestions.where((s) => s.toMemberId == b.member.id)
                      .any((s) => s.isSettled),
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
    this.isSettled = false,
  });

  final MemberBalance balance;
  final String currency;
  final bool isYouOwe;
  final VoidCallback onSettle;
  final bool isSettled;

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
            if (isSettled)
              const Icon(Icons.check_circle_rounded, size: 18, color: kColorSuccess)
            else
              WabwayButton(
                label: 'Mark settled',
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
    required this.members,
    required this.onMark,
  });

  final SettlementSuggestion suggestion;
  final String currency;
  final List<TripMember> members;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final from = memberById(suggestion.fromMemberId, members);
    final to   = memberById(suggestion.toMemberId, members);

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
