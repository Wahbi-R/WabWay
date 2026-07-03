import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/auth/profile_state.dart';
import '../core/supabase/doc_service.dart';
import '../core/supabase/money_service.dart';
import '../core/supabase/plan_service.dart';
import '../core/supabase/spot_service.dart';
import '../core/supabase/travel_service.dart';
import '../core/trip/app_trip.dart';
import '../core/trip/trip_state.dart';
import '../data/money_data.dart';
import '../data/plan_data.dart';
import '../data/travel_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

// ─── Loaded data ──────────────────────────────────────────────────────────────

class _HomeData {
  const _HomeData({
    required this.spotCount,
    required this.docCount,
    required this.days,
    required this.travelItems,
    required this.receipts,
    required this.balances,
    required this.memberMap,
    required this.currency,
  });

  final int spotCount;
  final int docCount;
  final List<TripDay> days;
  final List<TravelItem> travelItems;
  final List<Receipt> receipts;
  final List<MemberBalance> balances;
  final Map<String, String> memberMap; // userId → displayName
  final String currency;

  double get totalSpent => receipts.fold(0.0, (s, r) => s + r.amount);

  TripDay? get nextDay {
    final today = _today();
    for (final d in days) {
      if (!d.date.isBefore(today) && d.items.isNotEmpty) return d;
    }
    return null;
  }

  TravelItem? get nextTravelItem {
    final today = _today();
    TravelItem? result;
    for (final t in travelItems) {
      if (t.date == null || t.date!.isBefore(today)) continue;
      if (result == null || t.date!.isBefore(result.date!)) result = t;
    }
    return result;
  }

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  _HomeData? _data;
  Object? _error;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _loaded = true;
      _load();
    }
  }

  Future<void> _load() async {
    final trip = TripState.tripOf(context);
    final members = TripState.membersOf(context);
    final myId = ProfileState.of(context).id;

    try {
      final spotsFuture = SpotService.loadSpots(trip.id);
      final docsFuture = DocService.loadDocuments(trip.id);
      final planFuture = PlanService.loadAll(trip.id);
      final travelFuture = TravelService.loadItems(trip.id);
      final receiptsFuture = MoneyService.loadReceipts(trip.id);
      final withdrawalsFuture = MoneyService.loadWithdrawals(trip.id);

      final spots = await spotsFuture;
      final docs = await docsFuture;
      final days = await planFuture;
      final travelItems = await travelFuture;
      final receipts = await receiptsFuture;
      final withdrawals = await withdrawalsFuture;

      final memberMap = {for (final m in members) m.userId: m.profile.displayName};
      final tripMembers = members
          .map((m) => TripMember(id: m.userId, name: m.profile.displayName))
          .toList();

      final balances = calculateBalances(
        receipts,
        withdrawals,
        myId: myId,
        members: tripMembers,
      );

      if (!mounted) return;
      setState(() {
        _error = null;
        _data = _HomeData(
          spotCount: spots.length,
          docCount: docs.length,
          days: days,
          travelItems: travelItems,
          receipts: receipts,
          balances: balances,
          memberMap: memberMap,
          currency: trip.defaultCurrency,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _data = null;
      _error = null;
    });
    return _load();
  }

  @override
  Widget build(BuildContext context) {
    final trip = TripState.tripOf(context);
    final members = TripState.membersOf(context);

    if (_error != null && _data == null) {
      return Scaffold(
        backgroundColor: kColorCream,
        appBar: AppBar(
          title: Text('Home', style: kStyleTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              color: kColorInkSoft,
              onPressed: () {},
            ),
            const SizedBox(width: kSpace2),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 40, color: kColorInkSoft),
              const SizedBox(height: kSpace3),
              Text('Could not load home', style: kStyleBodyMedium),
              const SizedBox(height: kSpace3),
              TextButton(onPressed: _refresh, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final data = _data;

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Home', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            color: kColorInkSoft,
            onPressed: () {},
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(kSpace4),
          children: [
            _TripHero(trip: trip, memberCount: members.length, data: data),
            const SizedBox(height: kSpace4),
            _QuickBalanceCard(data: data),
            if (data != null &&
                (data.nextDay != null || data.nextTravelItem != null)) ...[
              const SizedBox(height: kSpace4),
              _UpcomingCard(data: data),
            ],
            const SizedBox(height: kSpace4),
            Text('Recent activity', style: kStyleOverline),
            const SizedBox(height: kSpace3),
            _ActivityFeed(data: data),
            const SizedBox(height: kSpace16),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtTripDates(DateTime? start, DateTime? end) {
  if (start == null && end == null) return '';
  const mo = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  if (start != null && end != null) {
    return '${mo[start.month - 1]} ${start.day} – '
        '${mo[end.month - 1]} ${end.day}, ${end.year}';
  }
  if (start != null) return '${mo[start.month - 1]} ${start.day}, ${start.year}';
  return 'Until ${mo[end!.month - 1]} ${end.day}, ${end.year}';
}

String _relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays >= 7) return fmtDate(date);
  if (diff.inDays >= 2) return '${diff.inDays}d ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inHours >= 1) return '${diff.inHours}h ago';
  if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
  return 'Just now';
}

// ─── Trip hero ────────────────────────────────────────────────────────────────

class _TripHero extends StatelessWidget {
  const _TripHero({
    required this.trip,
    required this.memberCount,
    required this.data,
  });

  final AppTrip trip;
  final int memberCount;
  final _HomeData? data;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _fmtTripDates(trip.startDate, trip.endDate);
    final memberLabel = memberCount == 1 ? '1 member' : '$memberCount members';
    final metaLine = [if (dateLabel.isNotEmpty) dateLabel, memberLabel].join('  ·  ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpace6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TRIP',
              style: kStyleOverline.copyWith(
                color: kColorPrimary,
                letterSpacing: kTextXs * kTrackingWide,
              ),
            ),
            const SizedBox(height: kSpace2),
            Text(
              trip.name,
              style: GoogleFonts.lora(
                fontSize: kText2xl,
                fontWeight: FontWeight.w600,
                color: kColorInk,
                height: kLeadingSnug,
              ),
            ),
            if (trip.destination != null) ...[
              const SizedBox(height: kSpace1),
              Text(trip.destination!, style: kStyleCaption),
            ],
            const SizedBox(height: kSpace2),
            Text(metaLine, style: kStyleCaption),
            const SizedBox(height: kSpace5),
            Row(
              children: [
                _HeroStat(
                  label: 'Spots saved',
                  value: data != null ? '${data!.spotCount}' : '—',
                ),
                const SizedBox(width: kSpace6),
                _HeroStat(
                  label: 'Days planned',
                  value: data != null ? '${data!.days.length}' : '—',
                ),
                const SizedBox(width: kSpace6),
                _HeroStat(
                  label: 'Total spent',
                  value: data != null
                      ? fmtAmount(data!.totalSpent, data!.currency)
                      : '—',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.ibmPlexMono(
            fontSize: kTextXl,
            fontWeight: FontWeight.w600,
            color: kColorInk,
          ),
        ),
        Text(label, style: kStyleCaption),
      ],
    );
  }
}

// ─── Balance card ─────────────────────────────────────────────────────────────

class _QuickBalanceCard extends StatelessWidget {
  const _QuickBalanceCard({required this.data});
  final _HomeData? data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorPrimarySoft,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorPrimarySoftBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Row(
          children: [
            const Icon(
              Icons.account_balance_wallet_rounded,
              color: kColorPrimary,
              size: 20,
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your balance', style: kStyleCaption),
                  const SizedBox(height: kSpace1),
                  _buildContent(),
                ],
              ),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                foregroundColor: kColorPrimaryDark,
                backgroundColor: kColorPaper,
                shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
              ),
              child: Text(
                'Settle up',
                style: kStyleBodySemibold.copyWith(color: kColorPrimaryDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (data == null) {
      return const SizedBox(
        height: 16,
        width: 120,
        child: LinearProgressIndicator(backgroundColor: Colors.transparent),
      );
    }

    final owes = data!.balances.where((b) => b.net < -0.5).toList()
      ..sort((a, b) => a.net.compareTo(b.net));
    final owed = data!.balances.where((b) => b.net > 0.5).toList()
      ..sort((a, b) => b.net.compareTo(a.net));

    if (owes.isEmpty && owed.isEmpty) {
      return Text(
        data!.receipts.isEmpty ? 'No expenses yet' : 'All settled up',
        style: kStyleBodySemibold.copyWith(color: kColorInkSoft),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (owes.isNotEmpty)
          Text(
            'You owe ${owes.first.member.name}: '
            '${fmtAmount(-owes.first.net, data!.currency)}',
            style: kStyleBodySemibold.copyWith(color: kColorPrimaryDark),
          ),
        if (owed.isNotEmpty)
          Text(
            '${owed.first.member.name} owes you '
            '${fmtAmount(owed.first.net, data!.currency)}',
            style: kStyleBodySemibold.copyWith(color: kColorSuccess),
          ),
      ],
    );
  }
}

// ─── Upcoming card ────────────────────────────────────────────────────────────

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.data});
  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final nextDay = data.nextDay;
    final nextTravel = data.nextTravelItem;

    final IconData icon;
    final String label;
    final String sub;
    final DateTime? date;

    if (nextDay != null) {
      final items = nextDay.sortedItems;
      icon = Icons.calendar_month_rounded;
      label = 'Day ${nextDay.dayNumber} · ${nextDay.city}';
      sub = items.isNotEmpty ? items.first.title : '';
      date = nextDay.date;
    } else if (nextTravel != null) {
      icon = nextTravel.type.icon;
      label = nextTravel.title;
      sub = [nextTravel.location, nextTravel.destination]
          .whereType<String>()
          .join(' → ');
      date = nextTravel.date;
    } else {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coming up', style: kStyleOverline),
        const SizedBox(height: kSpace3),
        DecoratedBox(
          decoration: kCardDecoration(),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: kSpace4,
              vertical: kSpace2,
            ),
            leading: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: kColorSurfaceSunken,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 18, color: kColorInkSoft),
            ),
            title: Text(label, style: kStyleBodyMedium),
            subtitle: sub.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(sub, style: kStyleCaption),
                  )
                : null,
            trailing: date != null ? Text(fmtDate(date), style: kStyleOverline) : null,
          ),
        ),
      ],
    );
  }
}

// ─── Activity feed ────────────────────────────────────────────────────────────

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({required this.data});
  final _HomeData? data;

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return DecoratedBox(
        decoration: kCardDecoration(),
        child: const Padding(
          padding: EdgeInsets.all(kSpace6),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    final receipts = data!.receipts.take(4).toList();

    if (receipts.isEmpty) {
      return DecoratedBox(
        decoration: kCardDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kSpace4,
            vertical: kSpace5,
          ),
          child: Center(child: Text('No activity yet', style: kStyleCaption)),
        ),
      );
    }

    final myId = ProfileState.of(context).id;

    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Column(
        children: receipts.asMap().entries.map((entry) {
          final i = entry.key;
          final receipt = entry.value;
          final isLast = i == receipts.length - 1;

          final payerName = receipt.paidById == myId
              ? 'You'
              : (data!.memberMap[receipt.paidById] ?? receipt.paidById);

          return Column(
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: kSpace4,
                  vertical: kSpace2,
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: kColorSurfaceSunken,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(receipt.category.icon, size: 18, color: kColorInkSoft),
                ),
                title: Text(
                  '$payerName added a receipt',
                  style: kStyleBodyMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '${receipt.title} · ${fmtAmount(receipt.amount, data!.currency)}',
                    style: kStyleCaption,
                  ),
                ),
                trailing: Text(_relativeTime(receipt.date), style: kStyleOverline),
              ),
              if (!isLast) const Divider(height: 1, indent: kSpace4 + 36 + kSpace3),
            ],
          );
        }).toList(),
      ),
    );
  }
}
