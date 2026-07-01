import 'package:flutter/material.dart';
import '../data/money_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'money/receipt_list_tile.dart';
import 'money/receipt_detail.dart';
import 'money/add_receipt_sheet.dart';
import 'money/cash_list_tile.dart';
import 'money/cash_detail.dart';
import 'money/add_cash_sheet.dart';
import 'money/settle_up_panel.dart';

enum _MoneyTab { receipts, cash, settleUp }

class MoneyScreen extends StatefulWidget {
  const MoneyScreen({super.key});

  @override
  State<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends State<MoneyScreen> {
  final List<Receipt> _receipts = List.from(kMockReceipts);
  final List<CashWithdrawal> _withdrawals = List.from(kMockWithdrawals);
  _MoneyTab _tab = _MoneyTab.receipts;
  String? _selectedReceiptId;
  String? _selectedWithdrawalId;

  static const _currency = 'JPY';

  List<MemberBalance> get _balances =>
      calculateBalances(_receipts, _withdrawals);
  List<SettlementSuggestion> get _settlements =>
      suggestSettlements(_balances, _currency);

  Receipt? get _selectedReceipt => _selectedReceiptId == null
      ? null
      : _receipts.where((r) => r.id == _selectedReceiptId).firstOrNull;

  CashWithdrawal? get _selectedWithdrawal => _selectedWithdrawalId == null
      ? null
      : _withdrawals.where((w) => w.id == _selectedWithdrawalId).firstOrNull;

  void _addReceipt(BuildContext context) async {
    final receipt = await showAddReceiptSheet(context);
    if (receipt != null) {
      setState(() {
        _receipts.insert(0, receipt);
        _selectedReceiptId = receipt.id;
        _tab = _MoneyTab.receipts;
      });
    }
  }

  void _addWithdrawal(BuildContext context) async {
    final w = await showAddCashSheet(context);
    if (w != null) {
      setState(() {
        _withdrawals.insert(0, w);
        _selectedWithdrawalId = w.id;
        _tab = _MoneyTab.cash;
      });
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    return isDesktop ? _buildDesktop(context) : _buildMobile(context);
  }

  // ─── Desktop ──────────────────────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      body: Column(
        children: [
          _DesktopMoneyBar(
            activeTab: _tab,
            onTabChange: (t) => setState(() => _tab = t),
            onAdd: () => _tab == _MoneyTab.cash
                ? _addWithdrawal(context)
                : _addReceipt(context),
            showAdd: _tab != _MoneyTab.settleUp,
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 380, child: _buildDesktopListPanel()),
                const VerticalDivider(
                    width: 1, thickness: 1, color: kColorBorder),
                Expanded(child: _buildDesktopDetailPanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopListPanel() {
    if (_tab == _MoneyTab.receipts) {
      if (_receipts.isEmpty) {
        return const _EmptyList(
          icon: Icons.receipt_long_rounded,
          label: 'No receipts yet',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(kSpace4),
        itemCount: _receipts.length,
        separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
        itemBuilder: (_, i) => ReceiptListTile(
          receipt: _receipts[i],
          selected: _selectedReceiptId == _receipts[i].id,
          onTap: () => setState(() => _selectedReceiptId = _receipts[i].id),
        ),
      );
    }

    if (_tab == _MoneyTab.cash) {
      if (_withdrawals.isEmpty) {
        return const _EmptyList(
          icon: Icons.atm_rounded,
          label: 'No withdrawals yet',
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(kSpace4),
        itemCount: _withdrawals.length,
        separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
        itemBuilder: (_, i) => CashListTile(
          withdrawal: _withdrawals[i],
          selected: _selectedWithdrawalId == _withdrawals[i].id,
          onTap: () =>
              setState(() => _selectedWithdrawalId = _withdrawals[i].id),
        ),
      );
    }

    // Settle up: full content in left panel
    return SettleUpPanel(
      balances: _balances,
      suggestions: _settlements,
      currency: _currency,
    );
  }

  Widget _buildDesktopDetailPanel() {
    if (_tab == _MoneyTab.settleUp) {
      return const SizedBox.shrink();
    }

    if (_tab == _MoneyTab.receipts) {
      final receipt = _selectedReceipt;
      if (receipt == null) {
        return const Center(
          child: WabwayEmptyState(
            icon: Icons.receipt_long_rounded,
            title: 'Select a receipt',
            description: 'Tap any receipt in the list to view details.',
          ),
        );
      }
      return SingleChildScrollView(
        child:
            ReceiptDetailContent(key: ValueKey(receipt.id), receipt: receipt),
      );
    }

    final withdrawal = _selectedWithdrawal;
    if (withdrawal == null) {
      return const Center(
        child: WabwayEmptyState(
          icon: Icons.atm_rounded,
          title: 'Select a withdrawal',
          description: 'Tap any withdrawal to view details.',
        ),
      );
    }
    return SingleChildScrollView(
      child: CashDetailContent(
          key: ValueKey(withdrawal.id), withdrawal: withdrawal),
    );
  }

  // ─── Mobile ───────────────────────────────────────────────────────────────────

  Widget _buildMobile(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: _tab.index,
      child: Scaffold(
        backgroundColor: kColorCream,
        appBar: AppBar(
          title: Text('Money', style: kStyleTitle),
          actions: [
            if (_tab != _MoneyTab.settleUp)
              IconButton(
                icon: const Icon(Icons.add_rounded),
                color: kColorInkSoft,
                onPressed: () => _tab == _MoneyTab.cash
                    ? _addWithdrawal(context)
                    : _addReceipt(context),
              ),
            const SizedBox(width: kSpace2),
          ],
          bottom: TabBar(
            onTap: (i) => setState(() => _tab = _MoneyTab.values[i]),
            tabs: const [
              Tab(text: 'Receipts'),
              Tab(text: 'Cash'),
              Tab(text: 'Settle Up'),
            ],
          ),
        ),
        body: TabBarView(
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Receipts tab
            _receipts.isEmpty
                ? const WabwayEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: 'No receipts yet',
                    description: 'Tap + to add the first expense.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(kSpace4),
                    itemCount: _receipts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: kSpace2),
                    itemBuilder: (ctx, i) => ReceiptListTile(
                      receipt: _receipts[i],
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              ReceiptDetailScreen(receipt: _receipts[i]),
                        ),
                      ),
                    ),
                  ),

            // Cash tab
            _withdrawals.isEmpty
                ? const WabwayEmptyState(
                    icon: Icons.atm_rounded,
                    title: 'No withdrawals yet',
                    description: 'Tap + to log an ATM withdrawal.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(kSpace4),
                    itemCount: _withdrawals.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: kSpace2),
                    itemBuilder: (ctx, i) => CashListTile(
                      withdrawal: _withdrawals[i],
                      onTap: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) =>
                              CashDetailScreen(withdrawal: _withdrawals[i]),
                        ),
                      ),
                    ),
                  ),

            // Settle Up tab
            SettleUpPanel(
              balances: _balances,
              suggestions: _settlements,
              currency: _currency,
            ),
          ],
        ),
        floatingActionButton: _tab == _MoneyTab.settleUp
            ? null
            : FloatingActionButton.extended(
                heroTag: 'money_fab',
                onPressed: () => _tab == _MoneyTab.cash
                    ? _addWithdrawal(context)
                    : _addReceipt(context),
                icon: Icon(_tab == _MoneyTab.cash
                    ? Icons.atm_rounded
                    : Icons.receipt_long_rounded),
                label: Text(
                  _tab == _MoneyTab.cash ? 'Add withdrawal' : 'Add receipt',
                  style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
                ),
              ),
      ),
    );
  }
}

// ─── Desktop top bar ──────────────────────────────────────────────────────────

class _DesktopMoneyBar extends StatelessWidget {
  const _DesktopMoneyBar({
    required this.activeTab,
    required this.onTabChange,
    required this.onAdd,
    required this.showAdd,
  });

  final _MoneyTab activeTab;
  final ValueChanged<_MoneyTab> onTabChange;
  final VoidCallback onAdd;
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: kTopBarHeight,
      decoration: const BoxDecoration(
        color: kColorBgRaised,
        border: Border(bottom: BorderSide(color: kColorBorder)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: kSpace4),
      child: Row(
        children: [
          Text('Money', style: kStyleTitle),
          const SizedBox(width: kSpace6),

          // Tab chips
          for (final tab in _MoneyTab.values)
            Padding(
              padding: const EdgeInsets.only(right: kSpace1),
              child: _DesktopTabChip(
                label: switch (tab) {
                  _MoneyTab.receipts => 'Receipts',
                  _MoneyTab.cash => 'Cash',
                  _MoneyTab.settleUp => 'Settle Up',
                },
                selected: activeTab == tab,
                onTap: () => onTabChange(tab),
              ),
            ),

          const Spacer(),

          if (showAdd)
            WabwayButton(
              label: activeTab == _MoneyTab.cash
                  ? 'Add withdrawal'
                  : 'Add receipt',
              icon: activeTab == _MoneyTab.cash
                  ? Icons.atm_rounded
                  : Icons.receipt_long_rounded,
              size: WabwayButtonSize.sm,
              onPressed: onAdd,
            ),
        ],
      ),
    );
  }
}

class _DesktopTabChip extends StatelessWidget {
  const _DesktopTabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace1),
        decoration: BoxDecoration(
          color: selected ? kColorPrimarySoft : Colors.transparent,
          borderRadius: kRadiusPill,
          border: Border.all(
            color: selected
                ? kColorPrimaryDark.withValues(alpha: 0.25)
                : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: kStyleCaptionMedium.copyWith(
            color: selected ? kColorPrimaryDark : kColorInkSoft,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: WabwayEmptyState(icon: icon, title: label, description: ''),
    );
  }
}
