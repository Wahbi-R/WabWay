import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/supabase/client.dart';
import '../core/supabase/money_service.dart';
import '../core/trip/trip_state.dart';
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
  List<Receipt> _receipts = [];
  List<CashWithdrawal> _withdrawals = [];
  bool _loading = true;
  bool _error = false;

  _MoneyTab _tab = _MoneyTab.receipts;
  String? _selectedReceiptId;
  String? _selectedWithdrawalId;

  String? _activeTripId;
  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  // Captured in didChangeDependencies and passed to add sheets.
  List<TripMember> _members = [];
  String _userId = '';

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Capture real identity and member list from the inherited widget tree.
    // These are stored as instance fields — no global mutation.
    final myId = supabase.auth.currentUser?.id ?? '';
    final appMembers = TripState.membersOf(context);
    _userId  = myId;
    _members = appMembers.isEmpty
        ? [TripMember(id: myId.isEmpty ? 'you' : myId, name: 'You')]
        : appMembers
            .map((m) => TripMember(
                  id:   m.userId,
                  name: m.userId == myId ? 'You' : m.profile.displayName,
                ))
            .toList();

    final tripId = TripState.tripOf(context).id;
    if (tripId != _activeTripId) {
      _activeTripId = tripId;
      _loadAll();
      _subscribeRealtime(tripId);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  // ── Data loading ──────────────────────────────────────────────────────────────

  Future<void> _loadAll({bool silent = false}) async {
    final tripId = _activeTripId;
    if (tripId == null) return;
    if (!silent) setState(() { _loading = true; _error = false; });
    try {
      final futures = await Future.wait([
        MoneyService.loadReceipts(tripId),
        MoneyService.loadWithdrawals(tripId),
      ]);
      if (!mounted) return;
      setState(() {
        _receipts   = List<Receipt>.from(futures[0] as List);
        _withdrawals = List<CashWithdrawal>.from(futures[1] as List);
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      if (silent) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  // ── Realtime ──────────────────────────────────────────────────────────────────

  void _subscribeRealtime(String tripId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supabase
        .channel('money-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'receipts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => _scheduleReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'receipt_splits',
          callback: (_) => _scheduleReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cash_withdrawals',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => _scheduleReload(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cash_distributions',
          callback: (_) => _scheduleReload(),
        )
        .subscribe();
  }

  void _scheduleReload() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _loadAll(silent: true);
    });
  }

  // ── Derived state ─────────────────────────────────────────────────────────────

  String get _currency {
    if (_receipts.isNotEmpty)    return _receipts.first.currency;
    if (_withdrawals.isNotEmpty) return _withdrawals.first.currency;
    return 'JPY';
  }

  List<MemberBalance> get _balances =>
      calculateBalances(_receipts, _withdrawals, myId: _userId, members: _members);
  List<SettlementSuggestion> get _settlements =>
      suggestSettlements(_balances, _currency, myId: _userId);

  Receipt? get _selectedReceipt => _selectedReceiptId == null
      ? null
      : _receipts.where((r) => r.id == _selectedReceiptId).firstOrNull;

  CashWithdrawal? get _selectedWithdrawal => _selectedWithdrawalId == null
      ? null
      : _withdrawals.where((w) => w.id == _selectedWithdrawalId).firstOrNull;

  // ── Mutations ─────────────────────────────────────────────────────────────────

  Future<void> _addReceipt(BuildContext context) async {
    if (_activeTripId == null) return;
    final receipt = await showAddReceiptSheet(
      context,
      tripId:  _activeTripId!,
      userId:  _userId,
      members: _members,
    );
    if (receipt != null && mounted) {
      setState(() {
        _receipts.insert(0, receipt);
        _selectedReceiptId = receipt.id;
        _tab = _MoneyTab.receipts;
      });
    }
  }

  Future<void> _addWithdrawal(BuildContext context) async {
    if (_activeTripId == null) return;
    final w = await showAddCashSheet(
      context,
      tripId:  _activeTripId!,
      userId:  _userId,
      members: _members,
    );
    if (w != null && mounted) {
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
    if (_loading) {
      return const Scaffold(
        backgroundColor: kColorCream,
        body: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(kColorPrimary),
            ),
          ),
        ),
      );
    }

    if (_error) {
      return Scaffold(
        backgroundColor: kColorCream,
        body: Center(
          child: WabwayEmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load money data',
            description: 'Check your connection and try again.',
            action: WabwayButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _loadAll,
            ),
          ),
        ),
      );
    }

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
          receipt:  _receipts[i],
          myId:     _userId,
          members:  _members,
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
          myId:       _userId,
          members:    _members,
          selected:   _selectedWithdrawalId == _withdrawals[i].id,
          onTap: () =>
              setState(() => _selectedWithdrawalId = _withdrawals[i].id),
        ),
      );
    }

    // Settle up: full content in left panel
    return SettleUpPanel(
      balances:    _balances,
      suggestions: _settlements,
      currency:    _currency,
      members:     _members,
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
        child: ReceiptDetailContent(
          key:     ValueKey(receipt.id),
          receipt: receipt,
          myId:    _userId,
          members: _members,
        ),
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
        key:        ValueKey(withdrawal.id),
        withdrawal: withdrawal,
        myId:       _userId,
        members:    _members,
      ),
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
                    itemBuilder: (ctx, i) {
                      final r = _receipts[i];
                      return ReceiptListTile(
                        receipt: r,
                        myId:    _userId,
                        members: _members,
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => ReceiptDetailScreen(
                              receipt: r,
                              myId:    _userId,
                              members: _members,
                            ),
                          ),
                        ),
                      );
                    },
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
                    itemBuilder: (ctx, i) {
                      final w = _withdrawals[i];
                      return CashListTile(
                        withdrawal: w,
                        myId:       _userId,
                        members:    _members,
                        onTap: () => Navigator.push(
                          ctx,
                          MaterialPageRoute(
                            builder: (_) => CashDetailScreen(
                              withdrawal: w,
                              myId:       _userId,
                              members:    _members,
                            ),
                          ),
                        ),
                      );
                    },
                  ),

            // Settle Up tab
            SettleUpPanel(
              balances:    _balances,
              suggestions: _settlements,
              currency:    _currency,
              members:     _members,
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
