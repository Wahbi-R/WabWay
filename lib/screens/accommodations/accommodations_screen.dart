import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../../core/supabase/accommodation_service.dart';
import '../../core/supabase/client.dart';
import '../../core/trip/trip_state.dart';
import '../../data/accommodation_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'add_accommodation_sheet.dart';

class AccommodationsScreen extends StatefulWidget {
  const AccommodationsScreen({super.key});

  @override
  State<AccommodationsScreen> createState() => _AccommodationsScreenState();
}

class _AccommodationsScreenState extends State<AccommodationsScreen> {
  List<Accommodation> _items = [];
  bool _loading = true;
  bool _error   = false;

  String? _activeTripId;
  AccommodationStatus? _filterStatus;
  String _search = '';
  RealtimeChannel? _channel;
  Timer? _debounce;

  final _searchCtrl = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tripId = TripState.tripOf(context).id;
    if (tripId != _activeTripId) {
      _activeTripId = tripId;
      _load();
      _subscribe(tripId);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    _channel?.unsubscribe();
    super.dispose();
  }

  void _subscribe(String tripId) {
    _channel?.unsubscribe();
    _channel = supabase
        .channel('accommodations-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'accommodations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 400),
              () => _load(silent: true),
            );
          },
        )
        .subscribe();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = false; });
    try {
      final tripId = TripState.tripOf(context).id;
      final items  = await AccommodationService.loadAll(tripId);
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  List<Accommodation> get _filtered {
    var list = _filterStatus == null
        ? _items
        : _items.where((a) => a.status == _filterStatus).toList();
    final q = _search.toLowerCase().trim();
    if (q.isNotEmpty) {
      bool m(String? s) => s != null && s.toLowerCase().contains(q);
      list = list.where((a) => m(a.name) || m(a.city) || m(a.address) || m(a.notes)).toList();
    }
    return list;
  }

  int _count(AccommodationStatus? status) {
    if (status == null) return _items.length;
    return _items.where((a) => a.status == status).length;
  }

  Future<void> _openAdd(BuildContext context, {Accommodation? editing}) async {
    final tripId = TripState.tripOf(context).id;
    final userId = supabase.auth.currentUser?.id ?? '';
    final result = await showModalBottomSheet<AccommodationSheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddAccommodationSheet(
        tripId:  tripId,
        userId:  userId,
        editing: editing,
      ),
    );
    if (result == null || !mounted) return;
    if (result.deleted) {
      setState(() => _items.removeWhere((a) => a.id == editing?.id));
    } else if (result.accommodation != null) {
      setState(() {
        final idx = _items.indexWhere((a) => a.id == result.accommodation!.id);
        if (idx >= 0) {
          _items[idx] = result.accommodation!;
        } else {
          _items.insert(0, result.accommodation!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const WabwayLoadingScaffold();

    if (_error) {
      return Scaffold(
        backgroundColor: kColorCream,
        body: Center(
          child: WabwayEmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'Could not load stays',
            description: 'Check your connection and try again.',
            action: WabwayButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              onPressed: _load,
            ),
          ),
        ),
      );
    }

    final filtered = _filtered;

    return Scaffold(
      backgroundColor: kColorCream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Stay', style: kStyleTitle),
            pinned: true,
          ),
          SliverToBoxAdapter(
            child: WabwaySearchBar(
              controller: _searchCtrl,
              hint: 'Search stays…',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SliverToBoxAdapter(
            child: _FilterStrip(
              selected: _filterStatus,
              counts: {
                null:                              _count(null),
                AccommodationStatus.brainstorming: _count(AccommodationStatus.brainstorming),
                AccommodationStatus.shortlisted:   _count(AccommodationStatus.shortlisted),
                AccommodationStatus.booked:        _count(AccommodationStatus.booked),
              },
              onChanged: (s) => setState(() => _filterStatus = s),
            ),
          ),
          filtered.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: _items.isEmpty
                        ? WabwayEmptyState(
                            icon: Icons.hotel_rounded,
                            title: 'No stays yet',
                            description: 'Share or paste a listing URL to add one.',
                            action: WabwayButton(
                              label: 'Add stay',
                              icon: Icons.add_rounded,
                              onPressed: () => _openAdd(context),
                            ),
                          )
                        : WabwayEmptyState(
                            icon: _search.isNotEmpty ? Icons.search_off_rounded : Icons.hotel_rounded,
                            title: _search.isNotEmpty
                                ? 'No results for "$_search"'
                                : 'No ${_filterStatus?.label ?? ''} stays',
                            description: _search.isNotEmpty
                                ? 'Try a different search term.'
                                : 'Change the filter to see others.',
                          ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, kSpace4),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
                    itemBuilder: (_, i) => _AccommodationCard(
                      item: filtered[i],
                      onTap: () => _openAdd(context, editing: filtered[i]),
                    ),
                  ),
                ),
          const SliverToBoxAdapter(child: SizedBox(height: kSpace16)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'stays_fab',
        onPressed: () => _openAdd(context),
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'Add stay',
          style: kStyleButtonMd.copyWith(color: kColorTextOnPrimary),
        ),
      ),
    );
  }
}

// ─── Filter strip ─────────────────────────────────────────────────────────────

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final AccommodationStatus? selected;
  final Map<AccommodationStatus?, int> counts;
  final ValueChanged<AccommodationStatus?> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <(AccommodationStatus?, String)>[
      (null, 'All'),
      (AccommodationStatus.brainstorming, 'Brainstorming'),
      (AccommodationStatus.shortlisted, 'Shortlisted'),
      (AccommodationStatus.booked, 'Booked'),
    ];
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kSpace4, vertical: kSpace3),
        children: options.map((opt) {
          final (status, label) = opt;
          final count = counts[status] ?? 0;
          final isSelected = selected == status;
          return Padding(
            padding: const EdgeInsets.only(right: kSpace2),
            child: WabwayTag(
              label: '$label ($count)',
              selected: isSelected,
              onTap: () => onChanged(isSelected ? null : status),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Accommodation card ───────────────────────────────────────────────────────

class _AccommodationCard extends StatelessWidget {
  const _AccommodationCard({required this.item, required this.onTap});

  final Accommodation item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final source   = item.detectedSource;
    final nightStr = item.nights != null ? '${item.nights} night${item.nights == 1 ? '' : 's'}' : null;

    String? priceStr;
    if (item.pricePerNight != null) {
      final sym = _currencySymbol(item.currency);
      final formatted = item.pricePerNight! % 1 == 0
          ? '${item.pricePerNight!.toInt()}'
          : item.pricePerNight!.toStringAsFixed(2);
      priceStr = '$sym$formatted/night';
    }

    String? dateStr;
    if (item.checkIn != null && item.checkOut != null) {
      dateStr = '${_fmtDate(item.checkIn!)} → ${_fmtDate(item.checkOut!)}';
      if (nightStr != null) dateStr = '$dateStr ($nightStr)';
    }

    return DecoratedBox(
      decoration: kCardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: kRadiusMd,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(kSpace4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasImage) ...[
                  ClipRRect(
                    borderRadius: kRadiusSm,
                    child: Image.network(
                      item.imageUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _ImagePlaceholder(source: source),
                    ),
                  ),
                  const SizedBox(width: kSpace3),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: kStyleBodySemibold,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: kSpace2),
                          WabwayBadge(
                            label: item.status.label,
                            tone: item.status.tone,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.city.isNotEmpty
                            ? '${item.city} · ${source.label}'
                            : source.label,
                        style: kStyleCaption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: kSpace2),
                      if (priceStr != null)
                        Text(
                          priceStr,
                          style: kStyleCaption.copyWith(
                            color: kColorInk,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                      else
                        Text(
                          'No price',
                          style: kStyleCaption.copyWith(
                            color: kColorInkSoft,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      if (dateStr != null) ...[
                        const SizedBox(height: 2),
                        Text(dateStr, style: kStyleCaption),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  static String _currencySymbol(String code) => switch (code) {
        'USD' => '\$',
        'EUR' => '€',
        'GBP' => '£',
        'JPY' => '¥',
        'CAD' => 'CA\$',
        'AUD' => 'A\$',
        _     => '$code ',
      };
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.source});
  final AccommodationSource source;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      color: kColorSurfaceSunken,
      child: Icon(source.icon, size: 24, color: kColorInkSoft),
    );
  }
}

// ─── Sheet result ─────────────────────────────────────────────────────────────

class AccommodationSheetResult {
  const AccommodationSheetResult({this.accommodation, this.deleted = false});
  final Accommodation? accommodation;
  final bool deleted;
}
