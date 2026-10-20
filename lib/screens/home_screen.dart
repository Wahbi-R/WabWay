import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/image_cache_manager.dart';
import '../widgets/android_download_banner.dart';
import '../widgets/update_checker_banner.dart';
import '../widgets/wabway_avatar.dart';
import '../core/text_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/async_screen_mixin.dart';
import '../core/providers/profile_provider.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/activity_service.dart';
import '../core/supabase/doc_service.dart';
import '../core/supabase/links_service.dart';
import '../core/supabase/money_service.dart';
import '../core/supabase/plan_service.dart';
import '../core/supabase/accommodation_service.dart';
import '../core/supabase/spot_service.dart';
import '../core/supabase/travel_service.dart';
import '../core/trip/app_trip.dart';
import '../core/trip/app_trip_member.dart';
import 'onboarding_screen.dart';
import 'trips/trip_settings_sheet.dart';
import 'trips/trip_list_tile.dart';
import '../data/activity_data.dart';
import '../data/docs_data.dart';
import '../data/links_data.dart';
import '../data/money_data.dart';
import '../data/plan_data.dart';
import '../data/accommodation_data.dart' show Accommodation;
import '../data/spot_data.dart';
import '../data/travel_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import 'crew_screen.dart';
import 'share/incoming_share_screen.dart';
import 'notification_settings_screen.dart';
import 'global_search_screen.dart';
import 'docs/doc_detail.dart';
import 'money/receipt_detail.dart';
import 'plan/item_detail.dart';
import 'spots/spot_detail.dart';
import 'travel/travel_item_detail.dart';
import 'pins_screen.dart';
import '../core/supabase/pins_service.dart';
import '../data/pins_data.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'share/open_add_sheet.dart';
import '../widgets/wabway_snack.dart';

// ─── Loaded data ──────────────────────────────────────────────────────────────

class _HomeData {
  const _HomeData({
    required this.spots,
    required this.docs,
    required this.days,
    required this.travelItems,
    required this.receipts,
    required this.links,
    required this.balancesByCurrency,
    required this.homeCurrency,
    required this.memberMap,
    required this.members,
    required this.stays,
    required this.activityEvents,
  });

  final List<Spot> spots;
  final List<TripDocument> docs;
  final List<TripDay> days;
  final List<TravelItem> travelItems;
  final List<Receipt> receipts;
  final List<TripLink> links;
  final List<Accommodation> stays;
  // balancesByCurrency[currency] = per-member net balances in that currency.
  // Multi-currency trips will have multiple entries here.
  final Map<String, List<MemberBalance>> balancesByCurrency;
  final String homeCurrency;
  final Map<String, String> memberMap; // userId → displayName
  // Full member list stored here so the activity feed can open receipt detail
  // screens (which need TripMember objects, not just names).
  final List<AppTripMember> members;
  final List<ActivityEvent> activityEvents;

  int get spotCount    => spots.length;
  int get visitedCount => spots.where((s) => s.status == SpotStatus.visited).length;
  int get docCount     => docs.length;

  // Sum of home-currency equivalents — consistent across multi-currency trips.
  double get totalSpent => receipts.fold(0.0, (s, r) => s + r.homeAmount);

  // Foreign receipts saved without an exchange rate (older builds allowed a
  // 0 home amount). Shown alongside the total instead of silently counting as 0.
  Map<String, double> get unconvertedSpent {
    final out = <String, double>{};
    for (final r in receipts) {
      if (r.homeAmount == 0 && r.amount > 0 && r.currency != homeCurrency) {
        out[r.currency] = (out[r.currency] ?? 0) + r.amount;
      }
    }
    return out;
  }

  String get spentLabel {
    final extra = unconvertedSpent;
    return joinNonEmpty([
      if (totalSpent > 0 || extra.isEmpty) fmtAmount(totalSpent, homeCurrency),
      for (final e in extra.entries) fmtAmount(e.value, e.key),
    ], ' + ');
  }

  // Today's plan day exactly, if one exists. Used for the "Today" agenda card.
  TripDay? get todayDay {
    final today = _today();
    for (final d in days) {
      if (d.date.year == today.year && d.date.month == today.month && d.date.day == today.day) {
        return d;
      }
    }
    return null;
  }

  // Travel items whose date is today.
  List<TravelItem> get todayTravelItems {
    final today = _today();
    return travelItems.where((t) {
      if (t.date == null) return false;
      final d = t.date!;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();
  }

  // First day from today (inclusive) that has at least one itinerary item.
  // Days are sorted chronologically by PlanService, so the first match is correct.
  TripDay? get nextDay {
    final today = _today();
    final future = days
        .where((d) => !d.date.isBefore(today) && d.items.isNotEmpty)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return future.isEmpty ? null : future.first;
  }

  // Nearest upcoming travel booking by departure date.
  // Linear scan — travelItems is small enough that sorting would be overkill.
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with AsyncScreenMixin {
  _HomeData? _data;

  // Home lives in the shell's IndexedStack, so initState runs once;
  // reloadWhenShown refreshes it silently whenever it becomes visible again,
  // so stats made on other tabs (a new plan day, a receipt) show up.

  // Activity inbox "unread" marker — last time this device opened the inbox
  // for the active trip.
  DateTime? _activitySeenAt;

  static String _seenKey(String tripId) => 'activity_seen_$tripId';

  Future<void> _loadActivitySeen(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_seenKey(tripId));
      if (mounted) {
        setState(() => _activitySeenAt =
            ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms));
      }
    } catch (_) {}
  }

  bool get _hasUnreadActivity {
    final d = _data;
    if (d == null) return false;
    final myId = ref.read(profileProvider)?.id ?? '';
    final seen = _activitySeenAt;
    return d.activityEvents.any((e) =>
        e.actorId != myId && (seen == null || e.createdAt.isAfter(seen)));
  }

  Future<void> _openInbox(BuildContext context) async {
    final trip = ref.read(activeTripProvider);
    final myId = ref.read(profileProvider)?.id ?? '';
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => _ActivityInboxScreen(data: _data, trip: trip, myId: myId),
      ),
    );
    final now = DateTime.now();
    if (mounted) setState(() => _activitySeenAt = now);
    if (trip == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_seenKey(trip.id), now.millisecondsSinceEpoch);
    } catch (_) {}
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    reloadWhenShown(() {
      if (_data != null) _load(silent: true);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showOnboardingIfNeeded(context);
      _load();
    });
  }

  Future<void> _load({bool silent = false}) async {
    final gen = beginLoad(silent: silent);
    final trip = ref.read(activeTripProvider);
    final members = ref.read(tripMembersProvider);
    final myId = ref.read(profileProvider)?.id ?? '';

    try {
      // All nine sources in parallel; stays failure is isolated via catchError.
      // results[0..8] must stay in sync with the list order below.
      final tripId = trip?.id ?? '';
      if (tripId.isEmpty) {
        commitLoad(gen, () => _data = null);
        return;
      }
      unawaited(_loadActivitySeen(tripId));
      final results = await Future.wait([
        SpotService.loadSpots(tripId),
        DocService.loadDocuments(tripId),
        PlanService.loadAll(tripId),
        TravelService.loadItems(tripId),
        MoneyService.loadReceipts(tripId),
        MoneyService.loadWithdrawals(tripId),
        ActivityService.loadEvents(tripId),
        LinksService.loadLinks(tripId),
        AccommodationService.loadAll(tripId)
            .catchError((_) => <Accommodation>[]),
      ]);

      final spots         = results[0] as List<Spot>;
      final docs          = results[1] as List<TripDocument>;
      final days          = results[2] as List<TripDay>;
      final travelItems   = results[3] as List<TravelItem>;
      final receipts      = results[4] as List<Receipt>;
      final withdrawals   = results[5] as List;
      final activities    = results[6] as List<ActivityEvent>;
      final links         = results[7] as List<TripLink>;
      final stays         = results[8] as List<Accommodation>;

      final memberMap = {for (final m in members) m.userId: m.profile.displayName};
      final tripMembers = members
          .map((m) => TripMember(id: m.userId, name: m.profile.displayName))
          .toList();

      final balancesByCurrency = calculateBalancesGrouped(
        receipts,
        withdrawals.cast(),
        myId: myId,
        members: tripMembers,
        homeCurrency: trip?.homeCurrency,
      );

      commitLoad(gen, () {
        _data = _HomeData(
          spots: spots,
          docs: docs,
          days: days,
          travelItems: travelItems,
          receipts: receipts,
          links: links,
          balancesByCurrency: balancesByCurrency,
          homeCurrency: trip?.homeCurrency ?? '',
          memberMap: memberMap,
          members: members,
          stays: stays,
          activityEvents: activities,
        );
      });
    } catch (_) {
      failLoad(gen, silent: silent);
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() => _data = null);
    return _load();
  }

  // Shared AppBar actions — import, global search, notification settings.
  // Defined once here so the error-state and success-state scaffolds stay in sync.
  void _openCrewScreen(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const CrewScreen()),
    );
  }

  List<Widget> _appBarActions(BuildContext context) => [
    IconButton(
      icon: const Icon(LucideIcons.messageSquare),
      color: kColorInkSoft,
      tooltip: 'Crew chat',
      onPressed: () => _openCrewScreen(context),
    ),
    IconButton(
      icon: const Icon(Icons.download_rounded),
      color: kColorInkSoft,
      tooltip: 'Import',
      onPressed: () => showImportScreen(context, ref),
    ),
    IconButton(
      icon: const Icon(LucideIcons.search),
      color: kColorInkSoft,
      tooltip: 'Search',
      onPressed: () {
        final trip    = ref.read(activeTripProvider);
        final members = ref.read(tripMembersProvider);
        showGlobalSearch(
          context,
          tripId:   trip?.id ?? '',
          tripName: trip?.name ?? '',
          userId:   ref.read(profileProvider)?.id ?? '',
          members:  members,
        );
      },
    ),
    IconButton(
      tooltip: 'Activity',
      color: kColorInkSoft,
      onPressed: () => _openInbox(context),
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(LucideIcons.bell),
          if (_hasUnreadActivity)
            Positioned(
              right: -1,
              top: -1,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: kColorPrimary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    ),
    const SizedBox(width: kSpace2),
  ];

  @override
  Widget build(BuildContext context) {
    final trip    = ref.watch(activeTripProvider);
    final members = ref.watch(tripMembersProvider);

    if (error && _data == null) {
      return Scaffold(
        backgroundColor: kColorCream,
        appBar: AppBar(
          title: Text('Home', style: kStyleTitle.copyWith(fontWeight: FontWeight.w800)),
          actions: _appBarActions(context),
          backgroundColor: kColorCream,
          scrolledUnderElevation: 0,
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
    final myId    = ref.watch(profileProvider)?.id ?? '';
    final isOwner = ref.watch(isOrganiserProvider);
    final tripStart = trip?.startDate;
    final isPreTrip = tripStart != null &&
        DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)
            .isBefore(tripStart);

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Home', style: kStyleTitle.copyWith(fontWeight: FontWeight.w800)),
        actions: _appBarActions(context),
        backgroundColor: kColorCream,
        scrolledUnderElevation: 0,
      ),
      bottomNavigationBar: const AndroidDownloadBanner(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'home_quick_add',
        tooltip: 'Add to trip',
        onPressed: () async {
          final created = await showQuickAddMenu(context, ref);
          if (created != null && mounted) {
            showWabwaySnack(context, 'Added ${created.label.toLowerCase()}');
            _load(silent: true);
          }
        },
        child: const Icon(Icons.add_rounded),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(kSpace4),
          children: [
            const UpdateCheckerBanner(),
            const SizedBox(height: kSpace3),
            if (trip != null)
              RepaintBoundary(
                child: _TripHero(
                  trip: trip,
                  memberCount: members.length,
                  data: data,
                  onTap: isOwner ? () => showTripSettingsSheet(context, ref, trip: trip) : null,
                ),
              ),
            const SizedBox(height: kSpace4),
            _BalanceChips(data: data, myId: myId),
            if (data != null && trip?.budget != null) ...[
              const SizedBox(height: kSpace3),
              _BudgetProgressBar(
                spent: data.totalSpent,
                budget: trip!.budget!,
                currency: trip.homeCurrency,
              ),
            ],
            const SizedBox(height: kSpace4),
            _PinboardCard(tripId: trip?.id ?? ''),
            if (data != null && data.todayDay != null) ...[
              const SizedBox(height: kSpace4),
              _TodayAgendaCard(
                day: data.todayDay!,
                travelItems: data.todayTravelItems,
              ),
            ] else if (!isPreTrip && data != null &&
                (data.nextDay != null || data.nextTravelItem != null)) ...[
              const SizedBox(height: kSpace4),
              _UpcomingCard(data: data),
            ],
            // Other trips — one tap to switch (same row as the trip switcher).
            if (ref.watch(allTripsProvider).length > 1) ...[
              const SizedBox(height: kSpace4),
              Text('Your trips', style: kStyleOverline),
              const SizedBox(height: kSpace3),
              DecoratedBox(
                decoration: kCardDecoration(),
                child: Column(
                  children: [
                    for (final t in ref.watch(allTripsProvider).take(5))
                      TripListTile(
                        trip: t,
                        isActive: t.id == trip?.id,
                        onTap: t.id == trip?.id
                            ? null
                            : () => ref.read(tripNotifierProvider.notifier).switchTrip(t),
                      ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: kSpace4),
            Text('Recent activity', style: kStyleOverline),
            const SizedBox(height: kSpace3),
            RepaintBoundary(child: _ActivityFeed(data: data, trip: trip, myId: myId)),
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
    final now        = DateTime.now();
    final todayOnly  = DateTime(now.year, now.month, now.day);
    final isPreTrip  = trip.startDate != null && todayOnly.isBefore(trip.startDate!);
    final nextDay    = data?.nextDay;
    final nextTravel = data?.nextTravelItem;
    final showFirstUp = isPreTrip && data != null &&
        (nextDay != null || nextTravel != null);

    final hasCover = trip.coverImageUrl != null;

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
      borderRadius: kRadiusLg,
      child: DecoratedBox(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover image strip (shown when trip has a cover photo)
          if (hasCover)
            SizedBox(
              height: 120,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: trip.coverImageUrl!,
                    cacheManager: WabwayImageCache.instance,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 300),
                    errorBuilder: (_, __, ___) => Container(color: kColorSurfaceSunken),
                  ),
                  // Gradient overlay so text below stays readable
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0x66000000)],
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Positioned(
                      top: kSpace2,
                      right: kSpace2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black45,
                          borderRadius: kRadiusMd,
                        ),
                        child: const Icon(Icons.edit_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          Padding(
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
                    // Subtle edit hint shown only to the trip owner (when no cover image)
                    if (onTap != null && !hasCover)
                      const Icon(Icons.edit_rounded, size: 14, color: kColorInkSoft),
                  ],
                ),
                const SizedBox(height: kSpace2),
                Text(trip.name, style: kStyleHeadingMd),
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
                        label: isPreTrip ? 'Saved' : 'Visited',
                        value: data != null
                            ? isPreTrip
                                ? '${data!.spotCount}'
                                : (data!.spotCount == 0
                                    ? '0'
                                    : '${data!.visitedCount}/${data!.spotCount}')
                            : '—',
                      ),
                    ),
                    Expanded(
                      child: _HeroStat(
                        label: pluralWord(data?.days.length ?? 0, 'Day'),
                        value: data != null ? '${data!.days.length}' : '—',
                      ),
                    ),
                    Expanded(
                      child: _HeroStat(
                        label: 'Spent',
                        value: data != null ? data!.spentLabel : '—',
                      ),
                    ),
                  ],
                ),
                if (showFirstUp) ...[
                  const SizedBox(height: kSpace4),
                  const Divider(height: 1, color: kColorBorder),
                  const SizedBox(height: kSpace3),
                  Text('First up', style: kStyleOverline),
                  const SizedBox(height: kSpace2),
                  if (nextTravel != null)
                    _FirstUpRow(
                      icon: nextTravel.type.icon,
                      color: nextTravel.type.color,
                      title: nextTravel.title,
                      sub: nextTravel.time ?? fmtDate(nextTravel.date!),
                      onTap: data != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TravelItemDetailScreen(
                                    item: nextTravel,
                                    docs: data!.docs,
                                    days: data!.days,
                                  ),
                                ),
                              )
                          : null,
                    ),
                  if (nextDay != null && nextDay.sortedItems.isNotEmpty) ...[
                    if (nextTravel != null) const SizedBox(height: kSpace2),
                    _FirstUpRow(
                      icon: nextDay.sortedItems.first.type.icon,
                      color: nextDay.sortedItems.first.type.color,
                      title: nextDay.sortedItems.first.title,
                      sub: nextDay.sortedItems.first.time ?? 'Day ${nextDay.dayNumber}',
                      onTap: data != null
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ItemDetailScreen(
                                    item: nextDay.sortedItems.first,
                                    day: nextDay,
                                    docs: data!.docs,
                                    spots: data!.spots,
                                    stays: data!.stays,
                                    days: data!.days,
                                  ),
                                ),
                              )
                          : null,
                    ),
                  ],
                ],
              ],
            ),
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
          style: kStyleMono.copyWith(fontSize: kTextLg, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        Text(label, style: kStyleCaption, overflow: TextOverflow.ellipsis, maxLines: 1),
      ],
    );
  }
}

// ─── First-up row (pre-trip hero section) ────────────────────────────────────

class _FirstUpRow extends StatelessWidget {
  const _FirstUpRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    Widget row = Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: kRadiusSm,
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: kSpace3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: kStyleBodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(sub, style: kStyleCaption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
        if (onTap != null)
          Icon(Icons.chevron_right_rounded, size: 16, color: kColorInkSoft.withValues(alpha: 0.5)),
      ],
    );

    if (onTap == null) return row;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: row,
    );
  }
}

// ─── Balance chips ────────────────────────────────────────────────────────────

class _BalanceChips extends StatelessWidget {
  const _BalanceChips({required this.data, required this.myId});
  final _HomeData? data;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final d = data;
    if (d == null || d.members.isEmpty || d.receipts.isEmpty) {
      return const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Balances', style: kStyleOverline),
            const SizedBox(height: kSpace3),
            Wrap(
              spacing: kSpace2,
              runSpacing: kSpace2,
              children: d.members.map((m) {
                final memberId = m.userId;
                final memberName = m.profile.displayName;
                // Find the largest imbalance across currencies for this member.
                String? mainCurrency;
                double mainNet = 0;
                bool settled = true;
                for (final entry in d.balancesByCurrency.entries) {
                  final mb = entry.value.firstWhere(
                    (b) => b.member.id == memberId,
                    orElse: () => MemberBalance(
                      member: TripMember(id: memberId, name: memberName),
                      net: 0,
                    ),
                  );
                  if (mb.net.abs() >= 0.5) settled = false;
                  if (mb.net.abs() > mainNet.abs()) {
                    mainNet = mb.net;
                    mainCurrency = entry.key;
                  }
                }
                return _MemberBalanceChip(
                  name: memberId == myId ? 'You' : memberName,
                  avatarName: memberName,
                  settled: settled,
                  net: mainNet,
                  currency: mainCurrency ?? d.homeCurrency,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberBalanceChip extends StatelessWidget {
  const _MemberBalanceChip({
    required this.name,
    required this.avatarName,
    required this.settled,
    required this.net,
    required this.currency,
  });
  final String name;

  /// The member's real display name — avatars never use "You".
  final String avatarName;
  final bool settled;
  final double net;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final label = settled
        ? 'Settled ✓'
        : (net > 0
            ? '+${fmtAmount(net.abs(), currency)}'
            : '–${fmtAmount(net.abs(), currency)}');
    final labelColor = settled
        ? kColorSuccess
        : (net > 0 ? kColorSuccess : kColorDanger);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusPill,
        border: Border.all(color: kColorBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(kSpace1, kSpace1, kSpace3, kSpace1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            WabwayAvatar(name: avatarName, size: WabwayAvatarSize.sm),
            const SizedBox(width: kSpace2),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: kStyleCaptionMedium),
                Text(label, style: kStyleCaption.copyWith(color: labelColor, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Budget progress bar ─────────────────────────────────────────────────────

class _BudgetProgressBar extends StatelessWidget {
  const _BudgetProgressBar({
    required this.spent,
    required this.budget,
    required this.currency,
  });

  final double spent;
  final double budget;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final progress = (spent / budget).clamp(0.0, 1.0);
    final isOver = spent > budget;
    final barColor = isOver ? kColorDanger : kColorPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Budget', style: kStyleCaption.copyWith(color: kColorInkSoft)),
            const Spacer(),
            Text(
              '${fmtAmount(spent, currency)} / ${fmtAmount(budget, currency)}',
              style: kStyleCaption.copyWith(
                color: isOver ? kColorDanger : kColorInkSoft,
                fontWeight: isOver ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: kRadiusPill,
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: kColorBorder,
            valueColor: AlwaysStoppedAnimation(barColor),
            minHeight: 6,
          ),
        ),
        if (isOver) ...[
          const SizedBox(height: 4),
          Text(
            '${fmtAmount(spent - budget, currency)} over budget',
            style: kStyleCaption.copyWith(color: kColorDanger),
          ),
        ],
      ],
    );
  }
}

// ─── Pinboard card ────────────────────────────────────────────────────────────
// Self-loading: shows pinned trip notes without adding to _HomeData.
// Hidden when there are no active pins, so it adds zero noise to empty trips.

class _PinboardCard extends StatefulWidget {
  const _PinboardCard({required this.tripId});
  final String tripId;

  @override
  State<_PinboardCard> createState() => _PinboardCardState();
}

class _PinboardCardState extends State<_PinboardCard> with AsyncScreenMixin {
  List<TripPin> _pins = [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _load();
    _channel = PinsService.subscribe(widget.tripId, () => _load(silent: true));
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final gen = beginLoad(silent: silent);
    try {
      final pins = await PinsService.fetchPinned(widget.tripId);
      commitLoad(gen, () => _pins = pins);
    } catch (_) {
      failLoad(gen, silent: silent || _pins.isNotEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading || _pins.isEmpty) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.push_pin_rounded, size: 14, color: kColorPrimary),
                const SizedBox(width: 4),
                Text('Pinboard', style: kStyleOverline.copyWith(color: kColorPrimary)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PinsScreen()),
                  ).then((_) => _load()),
                  child: Text(
                    'See all',
                    style: kStyleOverline.copyWith(color: kColorPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace3),
            ..._pins.take(3).map((pin) => Padding(
              padding: const EdgeInsets.only(bottom: kSpace3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.circle, size: 6, color: kColorPrimary),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(
                      pin.body,
                      style: kStyleBody,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ─── Upcoming card ────────────────────────────────────────────────────────────

class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({required this.data});
  final _HomeData data;

  static const int _maxItems = 3;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);

    // All upcoming plan days with at least one item, sorted soonest-first.
    final upcomingDays = data.days
        .where((d) => !d.date.isBefore(todayOnly) && d.items.isNotEmpty)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // All upcoming travel items with a date, sorted soonest-first.
    final upcomingTravel = data.travelItems
        .where((t) => t.date != null && !t.date!.isBefore(todayOnly))
        .toList()
      ..sort((a, b) => a.date!.compareTo(b.date!));

    if (upcomingDays.isEmpty && upcomingTravel.isEmpty) {
      return const SizedBox.shrink();
    }

    // Merge the two sorted lists, interleaved by date, up to _maxItems.
    final List<({IconData icon, String label, String sub, DateTime date})> items = [];
    int di = 0, ti = 0;
    while (items.length < _maxItems &&
        (di < upcomingDays.length || ti < upcomingTravel.length)) {
      final day = di < upcomingDays.length ? upcomingDays[di] : null;
      final travel = ti < upcomingTravel.length ? upcomingTravel[ti] : null;

      final bool useDay;
      if (day != null && travel != null) {
        useDay = !day.date.isAfter(travel.date!);
      } else {
        useDay = day != null;
      }

      if (useDay) {
        final d = day!;
        items.add((
          icon: Icons.calendar_month_rounded,
          label: joinNonEmpty(['Day ${d.dayNumber}', d.city]),
          sub: d.sortedItems.isNotEmpty ? d.sortedItems.first.title : '',
          date: d.date,
        ));
        di++;
      } else {
        final t = travel!;
        items.add((
          icon: t.type.icon,
          label: t.title,
          sub: [t.location, t.destination].whereType<String>().join(' → '),
          date: t.date!,
        ));
        ti++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coming up', style: kStyleOverline),
        const SizedBox(height: kSpace3),
        DecoratedBox(
          decoration: kCardDecoration(),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0)
                  const Divider(
                      height: 1, indent: kSpace4 + 36 + kSpace3, endIndent: kSpace4),
                Material(
                  color: Colors.transparent,
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
                      child: Icon(items[i].icon, size: 18, color: kColorInkSoft),
                    ),
                    title: Text(items[i].label, style: kStyleBodyMedium),
                    subtitle: items[i].sub.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(items[i].sub, style: kStyleCaption),
                          )
                        : null,
                    trailing: Text(fmtDate(items[i].date), style: kStyleOverline),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Today's agenda card (shown when today is a plan day) ────────────────────

class _TodayAgendaCard extends StatefulWidget {
  const _TodayAgendaCard({required this.day, this.travelItems = const []});
  final TripDay day;
  final List<TravelItem> travelItems;

  @override
  State<_TodayAgendaCard> createState() => _TodayAgendaCardState();
}

class _TodayAgendaCardState extends State<_TodayAgendaCard> {
  // Local done-state overrides for optimistic toggle; cleared on rebuild.
  late Map<String, bool> _doneOverride;

  @override
  void initState() {
    super.initState();
    _doneOverride = {};
  }

  bool _isDone(ItineraryItem item) => _doneOverride[item.id] ?? item.isDone;

  Future<void> _toggle(ItineraryItem item) async {
    final newDone = !_isDone(item);
    setState(() => _doneOverride[item.id] = newDone);
    try {
      await PlanService.toggleDone(item.id, done: newDone);
    } catch (_) {
      if (mounted) setState(() => _doneOverride[item.id] = !newDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items     = widget.day.sortedItems;
    final doneCount = items.where(_isDone).length;
    final total     = items.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Today', style: kStyleOverline),
            const Spacer(),
            if (total > 0)
              Text(
                '$doneCount/$total done',
                style: kStyleCaption.copyWith(
                  color: doneCount == total ? kColorPrimary : kColorInkSoft,
                ),
              ),
          ],
        ),
        const SizedBox(height: kSpace3),
        DecoratedBox(
          decoration: kCardDecoration(),
          child: Column(
            children: [
              // Day header row
              Padding(
                padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace2),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, size: 14, color: kColorInkSoft),
                    const SizedBox(width: kSpace2),
                    Text(
                      joinNonEmpty(['Day ${widget.day.dayNumber}', widget.day.city, fmtDate(widget.day.date)], '  ·  '),
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                    ),
                  ],
                ),
              ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
                  child: Text('Nothing planned for today yet.',
                      style: kStyleCaption.copyWith(color: kColorInkSoft)),
                )
              else
                ...items.asMap().entries.map((e) {
                  final i    = e.key;
                  final item = e.value;
                  final done   = _isDone(item);
                  final isLast = i == items.length - 1;
                  return Column(
                    children: [
                      if (i == 0)
                        const Divider(height: 1, color: kColorBorder),
                      Material(
                        color: Colors.transparent,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: kSpace4, vertical: kSpace1),
                          onTap: () => _toggle(item),
                          leading: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: done
                                  ? kColorPrimary.withValues(alpha: 0.12)
                                  : item.type.color.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              done ? Icons.check_rounded : item.type.icon,
                              size: 14,
                              color: done ? kColorPrimary : item.type.color,
                            ),
                          ),
                          title: Text(
                            item.title,
                            style: kStyleBodyMedium.copyWith(
                              decoration: done ? TextDecoration.lineThrough : null,
                              color: done ? kColorInkSoft : kColorInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: item.time != null || item.city != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Text(
                                    [if (item.time != null) item.time!, if (item.city != null) item.city!].join('  ·  '),
                                    style: kStyleCaption,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      if (!isLast)
                        const Divider(height: 1, indent: kSpace4 + 28 + kSpace3),
                    ],
                  );
                }),
              // Today's travel bookings (flights, hotels, etc.)
              if (widget.travelItems.isNotEmpty) ...[
                const Divider(height: 1, color: kColorBorder),
                Padding(
                  padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, kSpace1),
                  child: Text('Bookings today',
                      style: kStyleCaption.copyWith(color: kColorInkSoft)),
                ),
                ...widget.travelItems.map((t) => Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: kSpace4, vertical: kSpace1),
                    leading: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: t.type.color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(t.type.icon, size: 14, color: t.type.color),
                    ),
                    title: Text(t.title,
                        style: kStyleBodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: () {
                      final parts = [
                        if (t.time != null) t.time!,
                        if (t.location != null) t.location!,
                        if (t.destination != null && t.location != null) '→ ${t.destination!}',
                        if (t.confirmationNumber != null) t.confirmationNumber!,
                      ];
                      if (parts.isEmpty) return null;
                      return Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(parts.join('  ·  '),
                            style: kStyleCaption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      );
                    }(),
                  ),
                )),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Activity feed ────────────────────────────────────────────────────────────

/// The bell's destination: the trip's activity feed (same widget as Home's
/// "Recent activity"), with notification settings behind the gear.
class _ActivityInboxScreen extends StatelessWidget {
  const _ActivityInboxScreen({required this.data, required this.trip, required this.myId});
  final _HomeData? data;
  final AppTrip? trip;
  final String myId;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kColorCream,
        appBar: AppBar(
          title: Text('Activity', style: kStyleTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              color: kColorInkSoft,
              tooltip: 'Notification settings',
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(builder: (_) => const NotificationSettingsScreen()),
              ),
            ),
            const SizedBox(width: kSpace2),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(kSpace4),
          child: _ActivityFeed(data: data, trip: trip, myId: myId),
        ),
      );
}

class _ActivityFeed extends StatelessWidget {
  const _ActivityFeed({
    required this.data,
    required this.trip,
    required this.myId,
  });
  final _HomeData? data;
  final AppTrip? trip;
  final String myId;

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

    final d = data!;

    // Precompute O(1) lookup maps so each event row doesn't do a linear scan.
    final spotById    = { for (final s in d.spots)       s.id: s };
    final docById     = { for (final x in d.docs)        x.id: x };
    final travelById  = { for (final t in d.travelItems) t.id: t };
    final receiptById = { for (final r in d.receipts)    r.id: r };
    final linkById    = { for (final l in d.links)       l.id: l };
    final Map<String, ({TripDay day, ItineraryItem item})> planById = {};
    for (final day in d.days) {
      for (final it in day.items) {
        planById[it.id] = (day: day, item: it);
      }
    }

    // Convert members once for receipt detail.
    final moneyMembers = d.members.isEmpty
        ? [TripMember(id: myId.isEmpty ? 'you' : myId, name: 'You', isMe: true)]
        : d.members.map((m) => TripMember(
              id:   m.userId,
              name: m.profile.displayName, isMe: m.userId == myId,
            )).toList();

    void Function(BuildContext)? onTapFor(ActivityEvent ev) {
      switch (ev.type) {
        case ActivityEventType.spotAdded:
          final spot = spotById[ev.entityId];
          if (spot == null) return null;
          return (ctx) => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => SpotDetailScreen(spot: spot, docs: d.docs),
          ));

        case ActivityEventType.documentAdded:
          final doc = docById[ev.entityId];
          if (doc == null) return null;
          return (ctx) => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => DocDetailScreen(
              doc:            doc,
              tripId:         trip?.id ?? '',
              tripName:       trip?.name ?? '',
              availableSpots: d.spots,
            ),
          ));

        case ActivityEventType.travelItemAdded:
          final item = travelById[ev.entityId];
          if (item == null) return null;
          return (ctx) => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => TravelItemDetailScreen(
              item: item,
              docs: d.docs,
              days: d.days,
            ),
          ));

        case ActivityEventType.receiptAdded:
          final receipt = receiptById[ev.entityId];
          if (receipt == null) return null;
          return (ctx) => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => ReceiptDetailScreen(
              receipt: receipt,
              myId:    myId,
              members: moneyMembers,
              tripId:  trip?.id ?? '',
            ),
          ));

        case ActivityEventType.planItemAdded:
          final entry = planById[ev.entityId];
          if (entry == null) return null;
          return (ctx) => Navigator.push(ctx, MaterialPageRoute(
            builder: (_) => ItemDetailScreen(
              item:  entry.item,
              day:   entry.day,
              docs:  d.docs,
              spots: d.spots,
              stays: d.stays,
              days:  d.days,
            ),
          ));

        case ActivityEventType.linkAdded:
          final link = linkById[ev.entityId];
          if (link == null) return null;
          return (_) => launchUrl(
            Uri.parse(link.url),
            mode: LaunchMode.externalApplication,
          );

        case ActivityEventType.withdrawalAdded:
        case ActivityEventType.memberJoined:
        case ActivityEventType.unknown:
          return null;
      }
    }

    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Column(
        children: events.asMap().entries.map((entry) {
          final i      = entry.key;
          final ev     = entry.value;
          final isLast = i == events.length - 1;

          final actorLabel = ev.actorId == myId ? 'You' : ev.actorName;
          final onTap      = onTapFor(ev);

          return RepaintBoundary(
            child: Column(
              children: [
                Material(
                  color: Colors.transparent,
                  child: ListTile(
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
                    title: Text('$actorLabel ${ev.type.verb}', style: kStyleBodyMedium),
                    subtitle: ev.entityTitle != null && ev.entityTitle!.isNotEmpty
                        ? Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(ev.entityTitle!, style: kStyleCaption),
                          )
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_relativeTime(ev.createdAt), style: kStyleOverline),
                        if (onTap != null) ...[
                          const SizedBox(width: kSpace1),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: kColorInkSoft,
                          ),
                        ],
                      ],
                    ),
                    onTap: onTap != null ? () => onTap(context) : null,
                  ),
                ),
                if (!isLast) const Divider(height: 1, indent: kSpace4 + 36 + kSpace3),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
