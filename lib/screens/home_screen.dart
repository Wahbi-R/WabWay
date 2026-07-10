import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/auth/profile_state.dart';
import '../core/supabase/activity_service.dart';
import '../core/supabase/doc_service.dart';
import '../core/supabase/money_service.dart';
import '../core/supabase/plan_service.dart';
import '../core/supabase/spot_service.dart';
import '../core/supabase/travel_service.dart';
import '../core/trip/app_trip.dart';
import '../core/trip/trip_state.dart';
import '../core/update_checker.dart';
import 'onboarding_screen.dart';
import 'trips/trip_settings_sheet.dart';
import '../data/activity_data.dart';
import '../data/money_data.dart';
import '../data/plan_data.dart';
import '../data/travel_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import 'share/incoming_share_screen.dart';
import 'notification_settings_screen.dart';
import 'global_search_screen.dart';

// ─── Loaded data ──────────────────────────────────────────────────────────────

class _HomeData {
  const _HomeData({
    required this.spotCount,
    required this.docCount,
    required this.days,
    required this.travelItems,
    required this.receipts,
    required this.balancesByCurrency,
    required this.homeCurrency,
    required this.memberMap,
    required this.activityEvents,
  });

  final int spotCount;
  final int docCount;
  final List<TripDay> days;
  final List<TravelItem> travelItems;
  final List<Receipt> receipts;
  // balancesByCurrency[currency] = per-member net balances in that currency.
  // Multi-currency trips will have multiple entries here.
  final Map<String, List<MemberBalance>> balancesByCurrency;
  final String homeCurrency;
  final Map<String, String> memberMap; // userId → displayName
  final List<ActivityEvent> activityEvents;

  // Sum of home-currency equivalents — consistent across multi-currency trips.
  double get totalSpent => receipts.fold(0.0, (s, r) => s + r.homeAmount);

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
  UpdateInfo? _updateInfo;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _checkForUpdate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showOnboardingIfNeeded(context);
    });
  }

  Future<void> _checkForUpdate() async {
    final info = await UpdateChecker.check();
    if (mounted && info != null && info.hasUpdate) {
      setState(() => _updateInfo = info);
    }
  }

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
      final results = await Future.wait([
        SpotService.loadSpots(trip.id),
        DocService.loadDocuments(trip.id),
        PlanService.loadAll(trip.id),
        TravelService.loadItems(trip.id),
        MoneyService.loadReceipts(trip.id),
        MoneyService.loadWithdrawals(trip.id),
        ActivityService.loadEvents(trip.id),
      ]);

      final spots        = results[0] as List;
      final docs         = results[1] as List;
      final days         = results[2] as List<TripDay>;
      final travelItems  = results[3] as List<TravelItem>;
      final receipts     = results[4] as List<Receipt>;
      final withdrawals  = results[5] as List;
      final activities   = results[6] as List<ActivityEvent>;

      final memberMap = {for (final m in members) m.userId: m.profile.displayName};
      final tripMembers = members
          .map((m) => TripMember(id: m.userId, name: m.profile.displayName))
          .toList();

      final balancesByCurrency = calculateBalancesGrouped(
        receipts,
        withdrawals.cast(),
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
          balancesByCurrency: balancesByCurrency,
          homeCurrency: trip.homeCurrency,
          memberMap: memberMap,
          activityEvents: activities,
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

  // Shared AppBar actions — import, global search, notification settings.
  // Defined once here so the error-state and success-state scaffolds stay in sync.
  List<Widget> _appBarActions(BuildContext context) => [
    IconButton(
      icon: const Icon(Icons.download_rounded),
      color: kColorInkSoft,
      tooltip: 'Import',
      onPressed: () => showImportScreen(context),
    ),
    IconButton(
      icon: const Icon(Icons.search_rounded),
      color: kColorInkSoft,
      tooltip: 'Search',
      onPressed: () {
        final trip    = TripState.tripOf(context);
        final members = TripState.membersOf(context);
        showGlobalSearch(
          context,
          tripId:   trip.id,
          tripName: trip.name,
          userId:   ProfileState.of(context).id,
          members:  members,
        );
      },
    ),
    IconButton(
      icon: const Icon(Icons.notifications_outlined),
      color: kColorInkSoft,
      onPressed: () => Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => const NotificationSettingsScreen(),
        ),
      ),
    ),
    const SizedBox(width: kSpace2),
  ];

  @override
  Widget build(BuildContext context) {
    final trip = TripState.tripOf(context);
    final members = TripState.membersOf(context);

    if (_error != null && _data == null) {
      return Scaffold(
        backgroundColor: kColorCream,
        appBar: AppBar(
          title: Text('Home', style: kStyleTitle),
          actions: _appBarActions(context),
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
    final myId   = ProfileState.of(context).id;
    final isOwner = members.any((m) => m.userId == myId && m.isOwner);

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Home', style: kStyleTitle),
        actions: _appBarActions(context),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(kSpace4),
          children: [
            if (_updateInfo != null) ...[
              _UpdateBanner(info: _updateInfo!, onDismiss: () => setState(() => _updateInfo = null)),
              const SizedBox(height: kSpace3),
            ],
            _TripHero(
              trip: trip,
              memberCount: members.length,
              data: data,
              // Owners can tap the hero to edit trip details inline
              onTap: isOwner ? () => showTripSettingsSheet(context, trip: trip) : null,
            ),
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

// Returns a human-readable trip countdown string for the hero card:
//   "Starts in 12 days" / "Day 3 of 14" / "Ended yesterday"
// Returns null when the trip has no dates set.
String? _tripCountdown(DateTime? start, DateTime? end) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (start != null && today.isBefore(start)) {
    final days = start.difference(today).inDays;
    if (days == 0) return 'Starts today';
    if (days == 1) return 'Starts tomorrow';
    return 'Starts in $days days';
  }
  if (end != null && today.isAfter(end)) {
    final days = today.difference(end).inDays;
    if (days == 0) return 'Ended today';
    if (days == 1) return 'Ended yesterday';
    return 'Ended $days days ago';
  }
  // Trip is currently active
  if (start != null && end != null) {
    final day   = today.difference(start).inDays + 1;
    final total = end.difference(start).inDays + 1;
    return 'Day $day of $total';
  }
  if (start != null) return 'Day ${today.difference(start).inDays + 1}';
  return null;
}

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

// ─── Update banner ────────────────────────────────────────────────────────────

class _UpdateBanner extends StatelessWidget {
  const _UpdateBanner({required this.info, required this.onDismiss});
  final UpdateInfo info;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorPrimarySoft,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorPrimary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.system_update_rounded, size: 20, color: kColorPrimary),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update available — ${info.latestTag}',
                    style: kStyleBodyMedium.copyWith(color: kColorPrimaryDark),
                  ),
                  if (info.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      info.releaseNotes.length > 120
                          ? '${info.releaseNotes.substring(0, 120)}…'
                          : info.releaseNotes,
                      style: kStyleCaption.copyWith(color: kColorPrimaryDark),
                    ),
                  ],
                  const SizedBox(height: kSpace2),
                  GestureDetector(
                    onTap: info.downloadUrl.isEmpty
                        ? null
                        : () => launchUrl(
                              Uri.parse(info.downloadUrl),
                              mode: LaunchMode.externalApplication,
                            ),
                    child: Text(
                      'Download update →',
                      style: kStyleCaptionMedium.copyWith(
                          color: kColorPrimary,
                          decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close_rounded, size: 16, color: kColorInkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Trip hero ────────────────────────────────────────────────────────────────

class _TripHero extends StatelessWidget {
  const _TripHero({
    required this.trip,
    required this.memberCount,
    required this.data,
    this.onTap,
  });

  final AppTrip trip;
  final int memberCount;
  final _HomeData? data;
  // Non-null for owners: tapping the hero opens Trip Settings directly
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel  = _fmtTripDates(trip.startDate, trip.endDate);
    final countdown  = _tripCountdown(trip.startDate, trip.endDate);
    final memberLabel = memberCount == 1 ? '1 member' : '$memberCount members';
    final metaLine   = [if (dateLabel.isNotEmpty) dateLabel, memberLabel].join('  ·  ');

    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'TRIP',
                    style: kStyleOverline.copyWith(
                      color: kColorPrimary,
                      letterSpacing: kTextXs * kTrackingWide,
                    ),
                  ),
                ),
                // Subtle edit hint shown only to the trip owner
                if (onTap != null)
                  const Icon(Icons.edit_rounded, size: 14, color: kColorInkSoft),
              ],
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
            if (countdown != null) ...[
              const SizedBox(height: kSpace2),
              // Pill chip showing days until departure, current day, or days since return
              Container(
                padding: const EdgeInsets.symmetric(horizontal: kSpace2, vertical: 2),
                decoration: BoxDecoration(
                  color: kColorPrimary.withValues(alpha: 0.12),
                  borderRadius: kRadiusPill,
                ),
                child: Text(
                  countdown,
                  style: kStyleOverline.copyWith(color: kColorPrimaryDark),
                ),
              ),
            ],
            const SizedBox(height: kSpace5),
            Row(
              children: [
                Expanded(
                  child: _HeroStat(
                    label: 'Spots saved',
                    value: data != null ? '${data!.spotCount}' : '—',
                  ),
                ),
                Expanded(
                  child: _HeroStat(
                    label: 'Days planned',
                    value: data != null ? '${data!.days.length}' : '—',
                  ),
                ),
                Expanded(
                  child: _HeroStat(
                    label: 'Total spent',
                    value: data != null
                        ? fmtAmount(data!.totalSpent, data!.homeCurrency)
                        : '—',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ), // GestureDetector
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
            fontSize: kTextLg,
            fontWeight: FontWeight.w600,
            color: kColorInk,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(label, style: kStyleCaption, overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    );
  }
}

// ─── Balance card ─────────────────────────────────────────────────────────────

class _QuickBalanceCard extends StatelessWidget {
  const _QuickBalanceCard({required this.data});
  final _HomeData? data;

  // TODO: Settle up — build money settlement flow (calculate per-member balances,
  // allow marking debts as paid). Needs new DB table or computed view.
  Widget _settleUpButton() => TextButton(
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
      );

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
        child: LayoutBuilder(
          builder: (_, constraints) {
            final isNarrow = constraints.maxWidth < 400;
            final content = _buildContent();
            const walletIcon = Icon(
              Icons.account_balance_wallet_rounded,
              color: kColorPrimary,
              size: 20,
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      walletIcon,
                      const SizedBox(width: kSpace3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Your balance', style: kStyleCaption),
                            const SizedBox(height: kSpace1),
                            content,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace3),
                  SizedBox(width: double.infinity, child: _settleUpButton()),
                ],
              );
            }

            return Row(
              children: [
                walletIcon,
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your balance', style: kStyleCaption),
                      const SizedBox(height: kSpace1),
                      content,
                    ],
                  ),
                ),
                _settleUpButton(),
              ],
            );
          },
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

    final byCurrency = data!.balancesByCurrency;

    // Gather the most significant debt and credit across all currencies.
    // Multi-currency trips can have debts in e.g. JPY and USD simultaneously.
    final lines = <Widget>[];
    bool anyBalance = false;

    for (final entry in byCurrency.entries) {
      final currency = entry.key;
      final balances = entry.value;

      final owes = balances.where((b) => b.net < -0.5).toList()
        ..sort((a, b) => a.net.compareTo(b.net));
      final owed = balances.where((b) => b.net > 0.5).toList()
        ..sort((a, b) => b.net.compareTo(a.net));

      if (owes.isNotEmpty) {
        anyBalance = true;
        lines.add(Text(
          'You owe ${owes.first.member.name}: ${fmtAmount(-owes.first.net, currency)}',
          style: kStyleBodySemibold.copyWith(color: kColorPrimaryDark),
        ));
      }
      if (owed.isNotEmpty) {
        anyBalance = true;
        lines.add(Text(
          '${owed.first.member.name} owes you ${fmtAmount(owed.first.net, currency)}',
          style: kStyleBodySemibold.copyWith(color: kColorSuccess),
        ));
      }
    }

    if (!anyBalance) {
      return Text(
        data!.receipts.isEmpty ? 'No expenses yet' : 'All settled up',
        style: kStyleBodySemibold.copyWith(color: kColorInkSoft),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines,
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

    final myId  = ProfileState.of(context).id;
    final events = data!.activityEvents;

    if (events.isEmpty) {
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

    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Column(
        children: events.asMap().entries.map((entry) {
          final i    = entry.key;
          final ev   = entry.value;
          final isLast = i == events.length - 1;

          final actorLabel = ev.actorId == myId ? 'You' : ev.actorName;
          final subtitle   = ev.entityTitle;

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
                  decoration: BoxDecoration(
                    color: ev.type.softColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(ev.type.icon, size: 18, color: ev.type.color),
                ),
                title: Text(
                  '$actorLabel ${ev.type.verb}',
                  style: kStyleBodyMedium,
                ),
                subtitle: subtitle != null && subtitle.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(subtitle, style: kStyleCaption),
                      )
                    : null,
                trailing: Text(_relativeTime(ev.createdAt), style: kStyleOverline),
              ),
              if (!isLast) const Divider(height: 1, indent: kSpace4 + 36 + kSpace3),
            ],
          );
        }).toList(),
      ),
    );
  }
}
