import 'package:flutter/material.dart';
import '../core/supabase/accommodation_service.dart';
import '../core/supabase/doc_service.dart';
import '../core/supabase/money_service.dart';
import '../core/supabase/plan_service.dart';
import '../core/supabase/spot_service.dart';
import '../core/supabase/travel_service.dart';
import '../core/trip/app_trip_member.dart';
import '../data/accommodation_data.dart';
import '../data/docs_data.dart';
import '../data/money_data.dart';
import '../data/plan_data.dart';
import '../data/spot_data.dart';
import '../data/travel_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'accommodations/add_accommodation_sheet.dart';
import 'docs/doc_detail.dart';
import 'money/receipt_detail.dart';
import 'plan/item_detail.dart';
import 'spots/spot_detail.dart';
import 'travel/travel_item_detail.dart';

// Opens the full-trip search dialog. Caller must supply tripId + metadata so
// results can navigate directly to detail screens without re-injecting TripState.
Future<void> showGlobalSearch(
  BuildContext context, {
  required String tripId,
  required String tripName,
  required String userId,
  List<AppTripMember> members = const [],
}) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _GlobalSearchScreen(
        tripId:   tripId,
        tripName: tripName,
        userId:   userId,
        members:  members,
      ),
    ),
  );
}

// ─── Result model ─────────────────────────────────────────────────────────────

enum _ResultKind { spot, doc, travel, receipt, plan, stay }

class _Result {
  const _Result({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final _ResultKind kind;
  final String title;
  final String subtitle;
  final IconData icon;
  // Navigation action — executed in the search screen's context.
  final void Function(BuildContext) onTap;
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class _GlobalSearchScreen extends StatefulWidget {
  const _GlobalSearchScreen({
    required this.tripId,
    required this.tripName,
    required this.userId,
    required this.members,
  });
  final String tripId;
  final String tripName;
  final String userId;
  final List<AppTripMember> members;

  @override
  State<_GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<_GlobalSearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';
  bool _loading = true;

  List<Spot> _spots = [];
  List<TripDocument> _docs = [];
  List<TravelItem> _travel = [];
  List<Receipt> _receipts = [];
  List<Accommodation> _stays = [];
  // Full day objects kept so we can find the containing day for plan items.
  List<TripDay> _planDays = [];
  List<ItineraryItem> _planItems = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // All six data sources are fetched in parallel so the search screen is
  // ready in one round-trip instead of six sequential ones. The order of
  // results[0..5] must match the order of the Future.wait list.
  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        SpotService.loadSpots(widget.tripId),
        DocService.loadDocuments(widget.tripId),
        TravelService.loadItems(widget.tripId),
        MoneyService.loadReceipts(widget.tripId),
        PlanService.loadAll(widget.tripId),
        AccommodationService.loadAll(widget.tripId),
      ]);
      if (!mounted) return;
      final days = results[4] as List<TripDay>;
      setState(() {
        _spots     = results[0] as List<Spot>;
        _docs      = results[1] as List<TripDocument>;
        _travel    = results[2] as List<TravelItem>;
        _receipts  = results[3] as List<Receipt>;
        _planDays  = days;
        _planItems = days.expand((d) => d.items).toList();
        _stays     = results[5] as List<Accommodation>;
        _loading   = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─── Derived: convert AppTripMember to money TripMember for receipt screens

  List<TripMember> get _moneyMembers => widget.members.isEmpty
      ? [TripMember(id: widget.userId.isEmpty ? 'you' : widget.userId, name: 'You')]
      : widget.members
          .map((m) => TripMember(
                id:   m.userId,
                name: m.userId == widget.userId ? 'You' : m.profile.displayName,
              ))
          .toList();

  // ─── Search filter ────────────────────────────────────────────────────────────

  List<_Result> get _results {
    final q = _query.toLowerCase().trim();
    if (q.isEmpty) return const [];
    bool m(String? s) => s != null && s.toLowerCase().contains(q);

    final out = <_Result>[];

    for (final s in _spots) {
      if (m(s.name) || m(s.city) || m(s.notes) || m(s.area)) {
        // Capture loop variables before the closure to avoid late-binding bugs
        // where every result would navigate to the last item in the list.
        final spot = s;
        final docs = List<TripDocument>.unmodifiable(_docs);
        out.add(_Result(
          kind:     _ResultKind.spot,
          title:    s.name,
          subtitle: [s.city, s.category.label].whereType<String>().join(' · '),
          icon:     Icons.place_rounded,
          onTap: (ctx) => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => SpotDetailScreen(spot: spot, docs: docs),
            ),
          ),
        ));
      }
    }

    for (final d in _docs) {
      if (m(d.title) || m(d.notes) || m(d.type.label)) {
        final doc = d;
        final spots = List<Spot>.unmodifiable(_spots);
        out.add(_Result(
          kind:     _ResultKind.doc,
          title:    d.title,
          subtitle: d.type.label,
          icon:     Icons.folder_rounded,
          onTap: (ctx) => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => DocDetailScreen(
                doc:             doc,
                tripId:          widget.tripId,
                tripName:        widget.tripName,
                availableSpots:  spots,
              ),
            ),
          ),
        ));
      }
    }

    for (final t in _travel) {
      if (m(t.title) || m(t.location) || m(t.notes) || m(t.confirmationNumber)) {
        final item = t;
        final docs = List<TripDocument>.unmodifiable(_docs);
        final days = List<TripDay>.unmodifiable(_planDays);
        out.add(_Result(
          kind:     _ResultKind.travel,
          title:    t.title,
          subtitle: t.type.label,
          icon:     Icons.luggage_rounded,
          onTap: (ctx) => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => TravelItemDetailScreen(
                item: item,
                docs: docs,
                days: days,
              ),
            ),
          ),
        ));
      }
    }

    final moneyMembers = _moneyMembers;
    for (final r in _receipts) {
      if (m(r.title) || m(r.notes) || m(r.category.label)) {
        final receipt = r;
        out.add(_Result(
          kind:     _ResultKind.receipt,
          title:    r.title,
          subtitle: '${r.category.label} · ${fmtAmount(r.amount, r.currency)}',
          icon:     Icons.receipt_long_rounded,
          onTap: (ctx) => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => ReceiptDetailScreen(
                receipt: receipt,
                myId:    widget.userId,
                members: moneyMembers,
                tripId:  widget.tripId,
              ),
            ),
          ),
        ));
      }
    }

    for (final p in _planItems) {
      if (m(p.title) || m(p.location) || m(p.notes) || m(p.city)) {
        final planItem = p;
        // Find the containing day so ItemDetailScreen can show day context.
        final day = _planDays.where((d) => d.items.any((i) => i.id == p.id)).firstOrNull;
        if (day == null) continue;
        final docs = List<TripDocument>.unmodifiable(_docs);
        final spots = List<Spot>.unmodifiable(_spots);
        final days = List<TripDay>.unmodifiable(_planDays);
        out.add(_Result(
          kind:     _ResultKind.plan,
          title:    p.title,
          subtitle: [p.city, p.location].where((s) => s != null && s.isNotEmpty).join(' · '),
          icon:     Icons.map_rounded,
          onTap: (ctx) => Navigator.push(
            ctx,
            MaterialPageRoute(
              builder: (_) => ItemDetailScreen(
                item:  planItem,
                day:   day,
                docs:  docs,
                spots: spots,
                days:  days,
              ),
            ),
          ),
        ));
      }
    }

    for (final a in _stays) {
      if (m(a.name) || m(a.city) || m(a.address) || m(a.notes)) {
        final stay = a;
        out.add(_Result(
          kind:     _ResultKind.stay,
          title:    a.name,
          subtitle: [a.city.isNotEmpty ? a.city : null, a.status.label]
              .whereType<String>()
              .join(' · '),
          icon:     Icons.hotel_rounded,
          onTap: (ctx) => showModalBottomSheet<void>(
            context: ctx,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddAccommodationSheet(
              tripId:  widget.tripId,
              userId:  widget.userId,
              editing: stay,
            ),
          ),
        ));
      }
    }

    return out;
  }

  static const _kindLabel = {
    _ResultKind.spot:    'Spots',
    _ResultKind.doc:     'Documents',
    _ResultKind.travel:  'Travel',
    _ResultKind.receipt: 'Receipts',
    _ResultKind.plan:    'Itinerary',
    _ResultKind.stay:    'Stays',
  };

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final grouped = <_ResultKind, List<_Result>>{};
    for (final r in results) {
      grouped.putIfAbsent(r.kind, () => []).add(r);
    }

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        backgroundColor: kColorPaper,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: kColorInkSoft,
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          style: kStyleBody,
          decoration: InputDecoration(
            hintText: 'Search spots, stays, travel, docs, receipts…',
            hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              color: kColorInkSoft,
              onPressed: () {
                _ctrl.clear();
                setState(() => _query = '');
              },
            ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: _loading
          ? const Center(
              child: SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kColorPrimary),
                ),
              ),
            )
          : _query.trim().isEmpty
              ? const Center(
                  child: WabwayEmptyState(
                    icon: Icons.search_rounded,
                    title: 'Search across your trip',
                    description:
                        'Type to search spots, documents, travel, receipts, and itinerary items.',
                  ),
                )
              : results.isEmpty
                  ? Center(
                      child: WabwayEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No results',
                        description:
                            'Nothing matched "$_query". Try a different search term.',
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(kSpace4),
                      children: [
                        for (final kind in _ResultKind.values)
                          if (grouped.containsKey(kind)) ...[
                            Padding(
                              padding: const EdgeInsets.only(
                                  bottom: kSpace2, top: kSpace3),
                              child: Text(
                                _kindLabel[kind]!,
                                style: kStyleCaptionMedium.copyWith(
                                    color: kColorInk),
                              ),
                            ),
                            ...grouped[kind]!.map(
                              (r) => Padding(
                                padding: const EdgeInsets.only(bottom: kSpace2),
                                child: WabwayCard(
                                  hoverable: true,
                                  onTap: () => r.onTap(context),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: kSpace4, vertical: kSpace3),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: kColorCream,
                                          borderRadius: kRadiusMd,
                                        ),
                                        child: Icon(r.icon,
                                            size: 18, color: kColorPrimary),
                                      ),
                                      const SizedBox(width: kSpace3),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(r.title,
                                                style: kStyleBodyMedium),
                                            if (r.subtitle.isNotEmpty)
                                              Text(r.subtitle,
                                                  style: kStyleCaption),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: kColorInkSoft,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                      ],
                    ),
    );
  }
}
