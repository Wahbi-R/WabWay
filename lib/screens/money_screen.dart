import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/client.dart';
import '../core/supabase/money_service.dart';
import '../core/supabase/settlement_service.dart';
import '../core/sync_queue.dart';
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
import 'money/currency_converter_sheet.dart';
import 'money/settle_up_panel.dart';

enum _MoneyTab { receipts, cash, settleUp }

enum _ReceiptSort {
  newestFirst,
  oldestFirst,
  highestAmount,
  lowestAmount;

  String get label => switch (this) {
    _ReceiptSort.newestFirst    => 'Newest first',
    _ReceiptSort.oldestFirst    => 'Oldest first',
    _ReceiptSort.highestAmount  => 'Highest amount',
    _ReceiptSort.lowestAmount   => 'Lowest amount',
  };

  IconData get icon => switch (this) {
    _ReceiptSort.newestFirst    => Icons.arrow_downward_rounded,
    _ReceiptSort.oldestFirst    => Icons.arrow_upward_rounded,
    _ReceiptSort.highestAmount  => Icons.arrow_downward_rounded,
    _ReceiptSort.lowestAmount   => Icons.arrow_upward_rounded,
  };
}

enum _CashSort { newest, oldest }

// Mixed list entries for the receipt list — either a sticky date header or an
// actual receipt row. Using a sealed class keeps the switch exhaustive.
sealed class _ReceiptListEntry {}
class _DateHeader  extends _ReceiptListEntry { final DateTime date; _DateHeader(this.date); }
class _ReceiptItem extends _ReceiptListEntry { final Receipt receipt; _ReceiptItem(this.receipt); }

class MoneyScreen extends ConsumerStatefulWidget {
  const MoneyScreen({super.key});

  @override
  ConsumerState<MoneyScreen> createState() => _MoneyScreenState();
}

class _MoneyScreenState extends ConsumerState<MoneyScreen> {
  List<Receipt> _receipts = [];
  List<CashWithdrawal> _withdrawals = [];
  _CashSort _cashSort = _CashSort.newest;
  bool _loading = true;
  bool _error = false;
  bool _offline = false;
  int _pendingSyncCount = 0;

  _MoneyTab _tab = _MoneyTab.receipts;
  ReceiptCategory? _filterCategory;
  String? _filterPayerId;
  DateTimeRange? _dateRange;
  _ReceiptSort _receiptSort = _ReceiptSort.newestFirst;
  String _receiptSearch = '';
  String _cashSearch = '';
  final _searchCtrl = TextEditingController();
  final _cashSearchCtrl = TextEditingController();
  String? _selectedReceiptId;
  String? _selectedWithdrawalId;

  String? _activeTripId;
  String? _lastTripId;
  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;
  int _loadGen = 0;

  // Captured in didChangeDependencies and passed to add sheets.
  List<TripMember> _members = [];
  String _userId = '';
  List<Settlement> _persistedSettlements = [];

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  void _rebuildMembers() {
    final myId = supabase.auth.currentUser?.id ?? '';
    final appMembers = ref.read(tripMembersProvider);
    _userId  = myId;
    _members = appMembers.isEmpty
        ? [TripMember(id: myId.isEmpty ? 'you' : myId, name: 'You')]
        : appMembers
            .map((m) => TripMember(
                  id:   m.userId,
                  name: m.userId == myId ? 'You' : m.profile.displayName,
                ))
            .toList();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _rebuildMembers();
      _activeTripId = ref.read(activeTripIdProvider);
      _loadAll();
      _subscribeRealtime(_activeTripId!);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _realtimeChannel?.unsubscribe();
    _searchCtrl.dispose();
    _cashSearchCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  bool get _hasActiveFilters =>
      _filterCategory != null ||
      _filterPayerId != null ||
      _dateRange != null ||
      _receiptSearch.isNotEmpty;

  void _clearAllFilters() {
    setState(() {
      _filterCategory = null;
      _filterPayerId = null;
      _dateRange = null;
      _receiptSearch = '';
      _selectedReceiptId = null;
    });
    _searchCtrl.clear();
  }

  Widget _receiptFilterStrip() {
    final present = ReceiptCategory.values
        .where((c) => _receipts.any((r) => r.category == c))
        .toList();
    return WabwayFilterStrip<ReceiptCategory>(
      selected: _filterCategory,
      options: present.map((c) => (
        value: c,
        label: c.label,
        count: _receipts.where((r) => r.category == c).length,
      )).toList(),
      allCount: _receipts.length,
      onChanged: (c) => setState(() {
        _filterCategory = c;
        _selectedReceiptId = null;
      }),
    );
  }

  Widget _payerFilterStrip() {
    final payerIds = _receipts.map((r) => r.paidById).toSet();
    if (payerIds.length < 2) return const SizedBox.shrink();
    final payers = payerIds
        .map((id) => _members.firstWhere(
              (m) => m.id == id,
              orElse: () => TripMember(id: id, name: 'Unknown'),
            ))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return WabwayFilterStrip<String>(
      selected: _filterPayerId,
      options: payers.map((m) => (
        value: m.id,
        label: m.id == _userId ? 'Me' : m.name,
        count: _receipts.where((r) => r.paidById == m.id).length,
      )).toList(),
      allCount: _receipts.length,
      onChanged: (id) => setState(() {
        _filterPayerId = id;
        _selectedReceiptId = null;
      }),
    );
  }

  String? get _activeDatePreset {
    if (_dateRange == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_dateRange!.start == today && _dateRange!.end == today) return 'today';
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    if (_dateRange!.start == weekStart && _dateRange!.end == today) return 'week';
    final monthStart = DateTime(now.year, now.month, 1);
    if (_dateRange!.start == monthStart && _dateRange!.end == today) return 'month';
    return null;
  }

  void _setDatePreset(String key) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final DateTimeRange range;
    switch (key) {
      case 'today':
        range = DateTimeRange(start: today, end: today);
      case 'week':
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        range = DateTimeRange(start: weekStart, end: today);
      case 'month':
        final monthStart = DateTime(now.year, now.month, 1);
        range = DateTimeRange(start: monthStart, end: today);
      default:
        return;
    }
    if (_activeDatePreset == key) {
      setState(() { _dateRange = null; _selectedReceiptId = null; });
    } else {
      setState(() { _dateRange = range; _selectedReceiptId = null; });
    }
  }

  Widget _quickDatePresets() {
    final active = _activeDatePreset;
    const presets = [('today', 'Today'), ('week', 'This week'), ('month', 'This month')];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace1),
      child: Row(
        children: presets.map((p) {
          final (key, label) = p;
          final sel = active == key;
          return Padding(
            padding: const EdgeInsets.only(right: kSpace2),
            child: GestureDetector(
              onTap: () => _setDatePreset(key),
              child: AnimatedContainer(
                duration: kDurationFast,
                padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? kColorPrimary : kColorSurfaceSunken,
                  borderRadius: kRadiusPill,
                  border: Border.all(color: sel ? kColorPrimary : kColorBorder),
                ),
                child: Text(
                  label,
                  style: kStyleCaption.copyWith(
                    color: sel ? Colors.white : kColorInkSoft,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final first = _receipts.isEmpty ? DateTime.now() : _receipts.map((r) => r.date).reduce((a, b) => a.isBefore(b) ? a : b);
    final last  = _receipts.isEmpty ? DateTime.now() : _receipts.map((r) => r.date).reduce((a, b) => a.isAfter(b)  ? a : b);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate:  last.isAfter(DateTime.now()) ? last : DateTime.now(),
      initialDateRange: _dateRange,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(primary: kColorPrimary),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    setState(() {
      _dateRange = picked;
      _selectedReceiptId = null;
    });
  }

  Widget _dateRangeChip() {
    final hasRange = _dateRange != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
      child: GestureDetector(
        onTap: _pickDateRange,
        child: AnimatedContainer(
          duration: kDurationFast,
          padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 6),
          decoration: BoxDecoration(
            color: hasRange ? kColorPrimary.withValues(alpha: 0.08) : kColorPaper,
            borderRadius: kRadiusPill,
            border: Border.all(
              color: hasRange ? kColorPrimary.withValues(alpha: 0.4) : kColorBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.date_range_rounded,
                size: 14,
                color: hasRange ? kColorPrimary : kColorInkSoft,
              ),
              const SizedBox(width: 5),
              Text(
                hasRange
                    ? '${fmtDate(_dateRange!.start)} – ${fmtDate(_dateRange!.end)}'
                    : 'Date range',
                style: kStyleCaption.copyWith(
                  color: hasRange ? kColorPrimary : kColorInkSoft,
                  fontWeight: hasRange ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (hasRange) ...[
                const SizedBox(width: 5),
                GestureDetector(
                  onTap: () => setState(() {
                    _dateRange = null;
                    _selectedReceiptId = null;
                  }),
                  child: Icon(Icons.close_rounded, size: 14, color: kColorPrimary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Data loading ──────────────────────────────────────────────────────────────

  Future<void> _loadAll({bool silent = false}) async {
    final tripId = _activeTripId;
    if (tripId == null) return;
    final gen = ++_loadGen;
    if (!silent) setState(() {
      _loading = true; _error = false; _offline = false;
      _receipts = []; _withdrawals = [];
      if (_lastTripId != tripId) { _persistedSettlements = []; _pendingSyncCount = 0; }
    });

    if (!silent) {
      final cachedReceipts    = await MoneyService.loadReceiptsFromCache(tripId);
      final cachedWithdrawals = await MoneyService.loadWithdrawalsFromCache(tripId);
      final pending           = await SyncQueue.pendingCountFor(tripId);
      if (!mounted || gen != _loadGen) return;
      if (cachedReceipts != null) {
        setState(() {
          _receipts    = cachedReceipts;
          _withdrawals = cachedWithdrawals ?? [];
          if (_lastTripId != tripId) _persistedSettlements = [];
          _lastTripId  = tripId;
          _loading = false;
          _pendingSyncCount = pending;
        });
      }
    }

    try {
      final futures = await Future.wait([
        MoneyService.loadReceipts(tripId),
        MoneyService.loadWithdrawals(tripId),
        SettlementService.loadSettlements(tripId),
      ]);
      if (!mounted || gen != _loadGen) return;
      final pending = await SyncQueue.pendingCountFor(tripId);
      if (!mounted || gen != _loadGen) return;
      setState(() {
        _receipts             = List<Receipt>.from(futures[0] as List);
        _withdrawals          = List<CashWithdrawal>.from(futures[1] as List);
        _persistedSettlements = List<Settlement>.from(futures[2] as List);
        _lastTripId           = tripId;
        _loading = false;
        _offline = false;
        _pendingSyncCount = pending;
      });
    } catch (_) {
      if (!mounted || gen != _loadGen) return;
      if (silent) { setState(() { _offline = true; _loading = false; }); return; }
      if (_receipts.isEmpty) {
        setState(() { _loading = false; _error = true; });
      } else {
        setState(() { _loading = false; _offline = true; });
      }
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
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'settlements',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
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
  //
  // _filteredReceipts is the single source of truth for what the list shows.
  // Sort is applied after the category filter so you never see "Newest first"
  // mixed in with a filtered subset that includes a different sort order.

  List<Receipt> get _filteredReceipts {
    final q = _receiptSearch.toLowerCase().trim();
    bool matchesSearch(Receipt r) {
      if (q.isEmpty) return true;
      return r.title.toLowerCase().contains(q) ||
          r.category.label.toLowerCase().contains(q) ||
          (r.notes?.toLowerCase().contains(q) ?? false);
    }
    final base = _receipts.where((r) {
      if (_filterCategory != null && r.category != _filterCategory) return false;
      if (_filterPayerId != null && r.paidById != _filterPayerId) return false;
      if (_dateRange != null) {
        final day = DateUtils.dateOnly(r.date);
        if (day.isBefore(_dateRange!.start) || day.isAfter(_dateRange!.end)) return false;
      }
      return matchesSearch(r);
    }).toList();
    base.sort((a, b) => switch (_receiptSort) {
      _ReceiptSort.newestFirst   => b.date.compareTo(a.date),
      _ReceiptSort.oldestFirst   => a.date.compareTo(b.date),
      _ReceiptSort.highestAmount => b.homeAmount.compareTo(a.homeAmount),
      _ReceiptSort.lowestAmount  => a.homeAmount.compareTo(b.homeAmount),
    });
    return base;
  }

  // When the sort is date-based, inject date-header entries before the first
  // receipt of each calendar day so the user can scan "what did we spend on
  // Tuesday?". Amount-sorted lists skip headers because the date order
  // would be meaningless there.
  List<_ReceiptListEntry> get _receiptListItems {
    final receipts = _filteredReceipts;
    if (_receiptSort == _ReceiptSort.highestAmount ||
        _receiptSort == _ReceiptSort.lowestAmount) {
      return receipts.map<_ReceiptListEntry>(_ReceiptItem.new).toList();
    }
    final out = <_ReceiptListEntry>[];
    DateTime? lastDay;
    for (final r in receipts) {
      final day = DateUtils.dateOnly(r.date);
      if (lastDay == null || day != lastDay) {
        out.add(_DateHeader(day));
        lastDay = day;
      }
      out.add(_ReceiptItem(r));
    }
    return out;
  }

  Map<String, List<MemberBalance>> get _balancesByCurrency =>
      calculateBalancesGrouped(_receipts, _withdrawals, myId: _userId, members: _members);
  Map<String, List<SettlementSuggestion>> get _suggestionsByCurrency {
    final grouped = _balancesByCurrency;
    return {
      for (final entry in grouped.entries)
        entry.key: suggestSettlements(entry.value, entry.key, myId: _userId),
    };
  }

  Receipt? get _selectedReceipt => _selectedReceiptId == null
      ? null
      : _receipts.where((r) => r.id == _selectedReceiptId).firstOrNull;

  CashWithdrawal? get _selectedWithdrawal => _selectedWithdrawalId == null
      ? null
      : _withdrawals.where((w) => w.id == _selectedWithdrawalId).firstOrNull;

  List<CashWithdrawal> get _sortedWithdrawals {
    var list = List<CashWithdrawal>.from(_withdrawals);
    final q = _cashSearch.toLowerCase().trim();
    if (q.isNotEmpty) {
      list = list.where((w) {
        bool m(String? s) => s != null && s.toLowerCase().contains(q);
        return m(w.currency) || m(w.notes) || m(fmtAmount(w.amount, w.currency));
      }).toList();
    }
    if (_cashSort == _CashSort.oldest) {
      list.sort((a, b) => a.date.compareTo(b.date));
    } else {
      list.sort((a, b) => b.date.compareTo(a.date));
    }
    return list;
  }

  // ── Mutations ─────────────────────────────────────────────────────────────────

  String get _homeCurrency => ref.read(activeTripProvider)?.homeCurrency ?? '';

  void _exportReceipts() {
    final receipts = _filteredReceipts;
    if (receipts.isEmpty) return;
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Export is not supported on web.', style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    final tripName = ref.read(activeTripProvider)?.name ?? 'Trip';
    final buf = StringBuffer();
    buf.writeln('Date,Title,Category,Amount,Currency,Home Amount,Home Currency,Paid By,Splits,Notes');
    for (final r in receipts) {
      final payer = memberById(r.paidById, _members);
      buf.writeln([
        _csvCell(r.date.toIso8601String().substring(0, 10)),
        _csvCell(r.title),
        _csvCell(r.category.label),
        _csvCell(r.amount.toStringAsFixed(2)),
        _csvCell(r.currency),
        _csvCell(r.homeAmount.toStringAsFixed(2)),
        _csvCell(_homeCurrency),
        _csvCell(payer.name),
        _csvCell('${r.splits.length}'),
        _csvCell(r.notes ?? ''),
      ].join(','));
    }
    Share.share(buf.toString(), subject: '$tripName — Receipts');
  }

  static String _csvCell(String v) => '"${v.replaceAll('"', '""')}"';

  Future<void> _addReceipt(BuildContext context) async {
    if (_activeTripId == null) return;
    final receipt = await showAddReceiptSheet(
      context,
      tripId:       _activeTripId!,
      userId:       _userId,
      members:      _members,
      homeCurrency: _homeCurrency,
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

  void _deleteReceipt(String id) {
    setState(() {
      _receipts.removeWhere((r) => r.id == id);
      if (_selectedReceiptId == id) _selectedReceiptId = null;
    });
    MoneyService.deleteReceipt(id).catchError((_) => _loadAll(silent: true));
  }

  void _deleteWithdrawal(String id) {
    setState(() {
      _withdrawals.removeWhere((w) => w.id == id);
      if (_selectedWithdrawalId == id) _selectedWithdrawalId = null;
    });
    MoneyService.deleteWithdrawal(id).catchError((_) => _loadAll(silent: true));
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _activeTripId) {
        _activeTripId = next;
        _rebuildMembers();
        _loadAll();
        _subscribeRealtime(next);
      }
    });
    if (_loading) return const WabwayLoadingScaffold();

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
    final base = isDesktop ? _buildDesktop(context) : _buildMobile(context);
    if (!_offline) return base;
    return Stack(
      children: [
        base,
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: OfflineBanner(onRetry: _loadAll),
        ),
      ],
    );
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
            pendingSyncCount: _pendingSyncCount,
          ),
          Expanded(
            child: _tab == _MoneyTab.settleUp
                ? SettleUpPanel(
                    balancesByCurrency:    _balancesByCurrency,
                    suggestionsByCurrency: _suggestionsByCurrency,
                    members:               _members,
                    tripId:                _activeTripId ?? '',
                    myId:                  _userId,
                    existingSettlements:   _persistedSettlements,
                    onSettled:             () => _loadAll(silent: true),
                  )
                : Row(
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
      final listItems = _receiptListItems;
      return Column(
        children: [
          _SpendingSummaryCard(receipts: _receipts, homeCurrency: _homeCurrency),
          _SpendingByMemberCard(receipts: _receipts, homeCurrency: _homeCurrency, members: _members),
          WabwaySearchBar(
            controller: _searchCtrl,
            hint: 'Search receipts…',
            onChanged: (v) => setState(() {
              _receiptSearch = v;
              _selectedReceiptId = null;
            }),
          ),
          Row(
            children: [
              Expanded(child: _receiptFilterStrip()),
              _dateRangeChip(),
              Padding(
                padding: const EdgeInsets.only(right: kSpace3),
                child: _SortButton(
                  current: _receiptSort,
                  onChanged: (s) => setState(() => _receiptSort = s),
                ),
              ),
            ],
          ),
          _payerFilterStrip(),
          _quickDatePresets(),
          if (_hasActiveFilters)
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace2),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _clearAllFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 5),
                    decoration: BoxDecoration(
                      color: kColorDanger.withValues(alpha: 0.07),
                      borderRadius: kRadiusPill,
                      border: Border.all(color: kColorDanger.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.close_rounded, size: 12, color: kColorDanger),
                        const SizedBox(width: 4),
                        Text(
                          'Clear filters',
                          style: kStyleCaption.copyWith(
                            color: kColorDanger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: listItems.isEmpty
                ? Center(
                    child: WabwayEmptyState(
                      icon: _receiptSearch.isNotEmpty
                          ? Icons.search_off_rounded
                          : Icons.filter_list_rounded,
                      title: _receiptSearch.isNotEmpty
                          ? 'No results for "$_receiptSearch"'
                          : _dateRange != null
                              ? 'No receipts in that date range'
                              : _filterPayerId != null
                                  ? 'No receipts paid by that person'
                                  : 'No ${_filterCategory?.label ?? ''} receipts',
                      description: _receiptSearch.isNotEmpty
                          ? 'Try a different search term.'
                          : _dateRange != null
                              ? 'Try a wider date range or clear the filter.'
                              : 'Try a different filter.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(kSpace4),
                    itemCount: listItems.length,
                    itemBuilder: (_, i) {
                      final entry = listItems[i];
                      if (entry is _DateHeader) return _DateGroupHeader(date: entry.date);
                      final r = (entry as _ReceiptItem).receipt;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: kSpace2),
                        child: ReceiptListTile(
                          receipt:      r,
                          myId:         _userId,
                          members:      _members,
                          homeCurrency: _homeCurrency,
                          selected:     _selectedReceiptId == r.id,
                          onTap: () => setState(() => _selectedReceiptId = r.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
    }

    if (_tab == _MoneyTab.cash) {
      if (_withdrawals.isEmpty) {
        return const _EmptyList(
          icon: Icons.atm_rounded,
          label: 'No withdrawals yet',
        );
      }
      final sorted = _sortedWithdrawals;
      return Column(
        children: [
          _CashSummaryCard(withdrawals: _withdrawals),
          WabwaySearchBar(
            controller: _cashSearchCtrl,
            hint: 'Search withdrawals…',
            onChanged: (v) => setState(() => _cashSearch = v),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                PopupMenuButton<_CashSort>(
                  icon: Icon(
                    Icons.sort_rounded,
                    size: 18,
                    color: _cashSort != _CashSort.newest ? kColorPrimary : kColorInkSoft,
                  ),
                  tooltip: 'Sort withdrawals',
                  initialValue: _cashSort,
                  onSelected: (s) => setState(() => _cashSort = s),
                  itemBuilder: (_) => [
                    _cashSortItem(_CashSort.newest, 'Newest first', _cashSort),
                    _cashSortItem(_CashSort.oldest, 'Oldest first', _cashSort),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? Center(
                    child: WabwayEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No results for "$_cashSearch"',
                      description: 'Try a different search term.',
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace4),
                    itemCount: sorted.length,
                    separatorBuilder: (_, __) => const SizedBox(height: kSpace2),
                    itemBuilder: (_, i) => CashListTile(
                      withdrawal: sorted[i],
                      myId:       _userId,
                      members:    _members,
                      selected:   _selectedWithdrawalId == sorted[i].id,
                      onTap: () => setState(() => _selectedWithdrawalId = sorted[i].id),
                    ),
                  ),
          ),
        ],
      );
    }

    // Settle up: full content in left panel
    return SettleUpPanel(
      balancesByCurrency:    _balancesByCurrency,
      suggestionsByCurrency: _suggestionsByCurrency,
      members:               _members,
      tripId:                _activeTripId ?? '',
      myId:                  _userId,
      existingSettlements:   _persistedSettlements,
      onSettled:             () => _loadAll(silent: true),
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
          key:       ValueKey(receipt.id),
          receipt:   receipt,
          myId:      _userId,
          members:   _members,
          tripId:    _activeTripId!,
          onDelete:  () => _deleteReceipt(receipt.id),
          onUpdated: (r) => setState(() {
            final idx = _receipts.indexWhere((x) => x.id == r.id);
            if (idx >= 0) _receipts[idx] = r;
          }),
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
        tripId:     _activeTripId ?? '',
        onDelete:   () => _deleteWithdrawal(withdrawal.id),
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
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Money', style: kStyleTitle),
              // Orange "N pending" badge appears when receipts were added while
              // offline and are still waiting in the local sync queue.
              if (_pendingSyncCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: kColorWarning,
                    borderRadius: kRadiusPill,
                  ),
                  child: Text(
                    '$_pendingSyncCount pending',
                    style: kStyleCaption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (_tab == _MoneyTab.receipts && _receipts.isNotEmpty) ...[
              _SortButton(
                current: _receiptSort,
                onChanged: (s) => setState(() => _receiptSort = s),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                color: kColorInkSoft,
                tooltip: 'Export receipts as CSV',
                onPressed: _exportReceipts,
              ),
            ],
            if (_tab == _MoneyTab.cash && _withdrawals.isNotEmpty)
              PopupMenuButton<_CashSort>(
                icon: Icon(
                  Icons.sort_rounded,
                  size: 20,
                  color: _cashSort != _CashSort.newest ? kColorPrimary : kColorInkSoft,
                ),
                tooltip: 'Sort withdrawals',
                initialValue: _cashSort,
                onSelected: (s) => setState(() => _cashSort = s),
                itemBuilder: (_) => [
                  _cashSortItem(_CashSort.newest, 'Newest first', _cashSort),
                  _cashSortItem(_CashSort.oldest, 'Oldest first', _cashSort),
                ],
              ),
            IconButton(
              icon: const Icon(Icons.currency_exchange_rounded, size: 20),
              color: kColorInkSoft,
              tooltip: 'Currency converter',
              onPressed: () => showCurrencyConverterSheet(
                context,
                homeCurrency: _homeCurrency,
                receipts: _receipts,
              ),
            ),
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
            // Receipts tab — summary cards + search + filter + list all scroll together
            _receipts.isEmpty
                ? const Center(
                    child: WabwayEmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'No receipts yet',
                      description: 'Tap + to add the first expense.',
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _SpendingSummaryCard(
                                receipts: _receipts, homeCurrency: _homeCurrency),
                            _SpendingByMemberCard(
                                receipts: _receipts, homeCurrency: _homeCurrency, members: _members),
                            WabwaySearchBar(
                              controller: _searchCtrl,
                              hint: 'Search receipts…',
                              onChanged: (v) => setState(() {
                                _receiptSearch = v;
                                _selectedReceiptId = null;
                              }),
                            ),
                            Row(
                              children: [
                                Expanded(child: _receiptFilterStrip()),
                                _dateRangeChip(),
                              ],
                            ),
                            _payerFilterStrip(),
                            _quickDatePresets(),
                            if (_hasActiveFilters)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace2),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: GestureDetector(
                                    onTap: _clearAllFilters,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: kColorDanger.withValues(alpha: 0.07),
                                        borderRadius: kRadiusPill,
                                        border: Border.all(color: kColorDanger.withValues(alpha: 0.25)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.close_rounded, size: 12, color: kColorDanger),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Clear filters',
                                            style: kStyleCaption.copyWith(
                                              color: kColorDanger,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (_receiptListItems.isEmpty)
                        SliverFillRemaining(
                          child: Center(
                            child: WabwayEmptyState(
                              icon: _receiptSearch.isNotEmpty
                                  ? Icons.search_off_rounded
                                  : Icons.filter_list_rounded,
                              title: _receiptSearch.isNotEmpty
                                  ? 'No results for "$_receiptSearch"'
                                  : _dateRange != null
                                      ? 'No receipts in that date range'
                                      : 'No ${_filterCategory?.label ?? ''} receipts',
                              description: _receiptSearch.isNotEmpty
                                  ? 'Try a different search term.'
                                  : _dateRange != null
                                      ? 'Try a wider date range or clear the filter.'
                                      : 'Try a different category filter.',
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.all(kSpace4),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) {
                                final entry = _receiptListItems[i];
                                if (entry is _DateHeader) {
                                  return _DateGroupHeader(date: entry.date);
                                }
                                final r = (entry as _ReceiptItem).receipt;
                                return Dismissible(
                                  key: ValueKey('receipt_${r.id}'),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (_) async {
                                    _deleteReceipt(r.id);
                                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                                      content: Text('"${r.title}" deleted.',
                                          style: kStyleBody.copyWith(color: Colors.white)),
                                      behavior: SnackBarBehavior.floating,
                                    ));
                                    return false;
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: kSpace5, bottom: kSpace2),
                                    color: Colors.red.shade50,
                                    child: const Icon(Icons.delete_rounded,
                                        color: Colors.red, size: 22),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: kSpace2),
                                    child: ReceiptListTile(
                                      receipt:      r,
                                      myId:         _userId,
                                      members:      _members,
                                      homeCurrency: _homeCurrency,
                                      onTap: () => Navigator.push(
                                        ctx,
                                        MaterialPageRoute(
                                          builder: (_) => ReceiptDetailScreen(
                                            receipt:   r,
                                            myId:      _userId,
                                            members:   _members,
                                            tripId:    _activeTripId!,
                                            onDelete:  () => _deleteReceipt(r.id),
                                            onUpdated: (updated) {
                                              if (mounted) {
                                                setState(() {
                                                  final idx = _receipts.indexWhere((x) => x.id == updated.id);
                                                  if (idx >= 0) _receipts[idx] = updated;
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              childCount: _receiptListItems.length,
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: kSpace12)),
                    ],
                  ),

            // Cash tab
            _withdrawals.isEmpty
                ? const WabwayEmptyState(
                    icon: Icons.atm_rounded,
                    title: 'No withdrawals yet',
                    description: 'Tap + to log an ATM withdrawal.',
                  )
                : Builder(builder: (_) {
                    final sorted = _sortedWithdrawals;
                    return Column(
                      children: [
                        _CashSummaryCard(withdrawals: _withdrawals),
                        WabwaySearchBar(
                          controller: _cashSearchCtrl,
                          hint: 'Search withdrawals…',
                          onChanged: (v) => setState(() => _cashSearch = v),
                        ),
                        Expanded(
                          child: sorted.isEmpty
                              ? Center(
                                  child: WabwayEmptyState(
                                    icon: Icons.search_off_rounded,
                                    title: 'No results for "$_cashSearch"',
                                    description: 'Try a different search term.',
                                  ),
                                )
                              : ListView.separated(
                            padding: const EdgeInsets.all(kSpace4),
                            itemCount: sorted.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: kSpace2),
                            itemBuilder: (ctx, i) {
                              final w = sorted[i];
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
                                      tripId:     _activeTripId ?? '',
                                      onDelete:   () => _deleteWithdrawal(w.id),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }),

            // Settle Up tab
            SettleUpPanel(
              balancesByCurrency:    _balancesByCurrency,
              suggestionsByCurrency: _suggestionsByCurrency,
              members:               _members,
              tripId:                _activeTripId ?? '',
              myId:                  _userId,
              existingSettlements:   _persistedSettlements,
              onSettled:             () => _loadAll(silent: true),
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
    this.pendingSyncCount = 0,
  });

  final _MoneyTab activeTab;
  final ValueChanged<_MoneyTab> onTabChange;
  final VoidCallback onAdd;
  final bool showAdd;
  final int pendingSyncCount;

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
          if (pendingSyncCount > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: kColorWarning,
                borderRadius: kRadiusPill,
              ),
              child: Text(
                '$pendingSyncCount pending',
                style: kStyleCaption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
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

// ─── Date group header ────────────────────────────────────────────────────────

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({required this.date});
  final DateTime date;

  static const _days   = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  @override
  Widget build(BuildContext context) {
    final label = '${_days[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';
    return Padding(
      padding: const EdgeInsets.only(top: kSpace3, bottom: kSpace2),
      child: Text(label, style: kStyleCaption.copyWith(
        color: kColorInkSoft,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      )),
    );
  }
}

// ─── Spending summary by category ────────────────────────────────────────────
//
// Shows a compact card with total spend and per-category bars using homeAmount
// (the locked home-currency equivalent). Hidden when all receipts are in one
// category — it only adds value when there's something to compare.

class _SpendingSummaryCard extends StatelessWidget {
  const _SpendingSummaryCard({
    required this.receipts,
    required this.homeCurrency,
  });

  final List<Receipt> receipts;
  final String homeCurrency;

  @override
  Widget build(BuildContext context) {
    final Map<ReceiptCategory, double> totals = {};
    for (final r in receipts) {
      totals[r.category] = (totals[r.category] ?? 0.0) + r.homeAmount;
    }
    if (totals.length < 2) return const SizedBox.shrink();

    final grandTotal = receipts.fold(0.0, (s, r) => s + r.homeAmount);
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Daily average — computed from distinct receipt dates.
    final distinctDays = receipts
        .map((r) => DateTime(r.date.year, r.date.month, r.date.day))
        .toSet()
        .length;
    final avgPerDay = distinctDays > 0 ? grandTotal / distinctDays : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, 0),
      child: WabwayCard(
        padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Spending by category',
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      overflow: TextOverflow.ellipsis),
                ),
                if (avgPerDay != null) ...[
                  Text(
                    '~${fmtAmount(avgPerDay, homeCurrency)}/day',
                    style: kStyleCaption.copyWith(color: kColorInkSoft),
                  ),
                  const SizedBox(width: kSpace2),
                  const Text('·', style: TextStyle(color: kColorInkSoft)),
                  const SizedBox(width: kSpace2),
                ],
                Text(fmtAmount(grandTotal, homeCurrency),
                    style: kStyleBodySemibold),
              ],
            ),
            const SizedBox(height: kSpace3),
            ...sorted.map((e) {
              final pct = grandTotal > 0 ? e.value / grandTotal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: kSpace2),
                child: Row(
                  children: [
                    Icon(e.key.icon, size: 12, color: e.key.color),
                    const SizedBox(width: kSpace2),
                    Expanded(
                      child: Text(e.key.label,
                          style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    ),
                    Text(fmtAmount(e.value, homeCurrency),
                        style: kStyleCaptionMedium),
                    const SizedBox(width: kSpace3),
                    // Mini bar showing proportion of total spend.
                    SizedBox(
                      width: 48,
                      child: ClipRRect(
                        borderRadius: kRadiusPill,
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: e.key.softColor,
                          color: e.key.color,
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Spending by member ───────────────────────────────────────────────────────

class _SpendingByMemberCard extends StatelessWidget {
  const _SpendingByMemberCard({
    required this.receipts,
    required this.homeCurrency,
    required this.members,
  });

  final List<Receipt> receipts;
  final String homeCurrency;
  final List<TripMember> members;

  @override
  Widget build(BuildContext context) {
    final Map<String, double> paid = {};
    for (final r in receipts) {
      paid[r.paidById] = (paid[r.paidById] ?? 0.0) + r.homeAmount;
    }
    // Only show when at least 2 different people paid.
    if (paid.length < 2) return const SizedBox.shrink();

    final grandTotal = paid.values.fold(0.0, (s, v) => s + v);
    final sorted = paid.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final memberName = {for (final m in members) m.id: m.name};

    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
      child: WabwayCard(
        padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Spending by member',
                    style: kStyleCaption.copyWith(color: kColorInkSoft)),
                const Spacer(),
                Text(fmtAmount(grandTotal, homeCurrency),
                    style: kStyleBodySemibold),
              ],
            ),
            const SizedBox(height: kSpace3),
            ...sorted.map((e) {
              final name = memberName[e.key] ?? e.key.substring(0, 4);
              final initials = name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase();
              final pct = grandTotal > 0 ? e.value / grandTotal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: kSpace2),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: kColorPrimarySoft,
                      child: Text(initials, style: kStyleCaption.copyWith(fontSize: 8, color: kColorPrimaryDark)),
                    ),
                    const SizedBox(width: kSpace2),
                    Expanded(
                      child: Text(name, style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    ),
                    Text(fmtAmount(e.value, homeCurrency), style: kStyleCaptionMedium),
                    const SizedBox(width: kSpace3),
                    SizedBox(
                      width: 48,
                      child: ClipRRect(
                        borderRadius: kRadiusPill,
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: kColorPrimarySoft,
                          color: kColorPrimary,
                          minHeight: 4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─── Receipt sort button ──────────────────────────────────────────────────────

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current, required this.onChanged});
  final _ReceiptSort current;
  final ValueChanged<_ReceiptSort> onChanged;

  @override
  Widget build(BuildContext context) {
    // Highlight the icon when the sort is non-default so the user knows
    // something is active.
    final isDefault = current == _ReceiptSort.newestFirst;
    return PopupMenuButton<_ReceiptSort>(
      tooltip: 'Sort receipts',
      icon: Icon(
        Icons.sort_rounded,
        size: 20,
        color: isDefault ? kColorInkSoft : kColorPrimary,
      ),
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (_) => _ReceiptSort.values
          .map((s) => PopupMenuItem<_ReceiptSort>(
                value: s,
                child: Row(
                  children: [
                    Icon(s.icon, size: 16,
                        color: s == current ? kColorPrimary : kColorInkSoft),
                    const SizedBox(width: kSpace2),
                    Text(
                      s.label,
                      style: kStyleBody.copyWith(
                        color: s == current ? kColorPrimary : kColorInk,
                        fontWeight: s == current
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ─── Cash sort helper ─────────────────────────────────────────────────────────

PopupMenuItem<_CashSort> _cashSortItem(
    _CashSort value, String label, _CashSort current) {
  return PopupMenuItem(
    value: value,
    child: Row(
      children: [
        SizedBox(
          width: 20,
          child: current == value
              ? const Icon(Icons.check_rounded, size: 16, color: kColorPrimary)
              : null,
        ),
        const SizedBox(width: kSpace2),
        Text(label),
      ],
    ),
  );
}

// ─── Cash summary card ────────────────────────────────────────────────────────

class _CashSummaryCard extends StatelessWidget {
  const _CashSummaryCard({required this.withdrawals});
  final List<CashWithdrawal> withdrawals;

  @override
  Widget build(BuildContext context) {
    if (withdrawals.length < 2) return const SizedBox.shrink();

    final Map<String, double> amountByCurrency = {};
    final Map<String, double> feesByCurrency = {};
    for (final w in withdrawals) {
      amountByCurrency[w.currency] =
          (amountByCurrency[w.currency] ?? 0.0) + w.amount;
      if (w.atmFee > 0) {
        feesByCurrency[w.currency] =
            (feesByCurrency[w.currency] ?? 0.0) + w.atmFee;
      }
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, 0),
      child: WabwayCard(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpace4, vertical: kSpace3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Cash withdrawn',
                    style: kStyleCaption.copyWith(color: kColorInkSoft)),
                const Spacer(),
                Text('${withdrawals.length} withdrawals',
                    style: kStyleCaption.copyWith(color: kColorInkSoft)),
              ],
            ),
            const SizedBox(height: kSpace2),
            ...amountByCurrency.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: kSpace1),
                  child: Row(
                    children: [
                      const Icon(Icons.atm_rounded,
                          size: 12, color: kColorInkSoft),
                      const SizedBox(width: kSpace2),
                      Expanded(
                        child: Text(e.key,
                            style: kStyleCaption.copyWith(
                                color: kColorInkSoft)),
                      ),
                      Text(fmtAmount(e.value, e.key),
                          style: kStyleBodySemibold),
                    ],
                  ),
                )),
            if (feesByCurrency.isNotEmpty) ...[
              const Divider(height: kSpace3),
              ...feesByCurrency.entries.map((e) => Row(
                    children: [
                      const Icon(Icons.price_check_rounded,
                          size: 12, color: kColorWarning),
                      const SizedBox(width: kSpace2),
                      Expanded(
                        child: Text('ATM fees (${e.key})',
                            style: kStyleCaption.copyWith(
                                color: kColorInkSoft)),
                      ),
                      Text(fmtAmount(e.value, e.key),
                          style: kStyleCaptionMedium.copyWith(
                              color: kColorWarning)),
                    ],
                  )),
            ],
          ],
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
