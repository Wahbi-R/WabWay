import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/accommodation_service.dart';
import '../../core/supabase/client.dart';
import '../../data/accommodation_data.dart';
import '../../data/date_utils.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'add_accommodation_sheet.dart';

enum _StaySort { checkIn, alphabetical, newest }

class AccommodationsScreen extends ConsumerStatefulWidget {
  const AccommodationsScreen({super.key});

  @override
  ConsumerState<AccommodationsScreen> createState() => _AccommodationsScreenState();
}

class _AccommodationsScreenState extends ConsumerState<AccommodationsScreen> {
  List<Accommodation> _items = [];
  bool _loading = true;
  bool _error   = false;
  bool _offline  = false;

  String? _activeTripId;
  AccommodationStatus? _filterStatus;
  _StaySort _sort = _StaySort.checkIn;
  String _search = '';
  RealtimeChannel? _channel;
  Timer? _debounce;

  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeTripId = ref.read(activeTripIdProvider);
      _load();
      _subscribe(_activeTripId!);
    });
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
      final items  = await AccommodationService.loadAll(_activeTripId!);
      if (!mounted) return;
      setState(() { _items = items; _loading = false; _offline = false; });
    } catch (_) {
      if (!mounted) return;
      if (silent) { setState(() => _offline = true); return; }
      setState(() { _loading = false; _error = true; });
    }
  }

  List<Accommodation> get _filtered {
    var list = _filterStatus == null
        ? List<Accommodation>.from(_items)
        : _items.where((a) => a.status == _filterStatus).toList();
    final q = _search.toLowerCase().trim();
    if (q.isNotEmpty) {
      bool m(String? s) => s != null && s.toLowerCase().contains(q);
      list = list.where((a) => m(a.name) || m(a.city) || m(a.address) || m(a.notes)).toList();
    }
    switch (_sort) {
      case _StaySort.checkIn:
        list.sort((a, b) {
          if (a.checkIn == null && b.checkIn == null) return 0;
          if (a.checkIn == null) return 1;
          if (b.checkIn == null) return -1;
          return a.checkIn!.compareTo(b.checkIn!);
        });
      case _StaySort.alphabetical:
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case _StaySort.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    return list;
  }

  int _count(AccommodationStatus? status) {
    if (status == null) return _items.length;
    return _items.where((a) => a.status == status).length;
  }

  void _exportCsv() {
    final list = _filtered;
    if (list.isEmpty || kIsWeb) return;
    final tripName = ref.read(activeTripProvider)?.name ?? 'Trip';
    final buf = StringBuffer();
    buf.writeln('Name,City,Check-in,Check-out,Nights,Price/night,Currency,Total,Status,Source,Confirmation,URL,Notes');
    for (final a in list) {
      final row = [
        _c(a.name),
        _c(a.city),
        _c(a.checkIn != null ? fmtDate(a.checkIn!) : ''),
        _c(a.checkOut != null ? fmtDate(a.checkOut!) : ''),
        _c(a.nights?.toString() ?? ''),
        _c(a.pricePerNight?.toStringAsFixed(2) ?? ''),
        _c(a.currency),
        _c(a.totalPrice?.toStringAsFixed(2) ?? ''),
        _c(a.status.label),
        _c(a.detectedSource.label),
        _c(a.confirmationNumber ?? ''),
        _c(a.url ?? ''),
        _c(a.notes ?? ''),
      ].join(',');
      buf.writeln(row);
    }
    Share.share(buf.toString().trim(), subject: '$tripName — Stays');
  }

  static String _c(String v) => '"${v.replaceAll('"', '""')}"';

  Future<void> _deleteItem(BuildContext context, Accommodation item) async {
    setState(() => _items.removeWhere((a) => a.id == item.id));
    try {
      await AccommodationService.delete(item.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.insert(0, item));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not delete "${item.name}". Try again.',
            style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${item.name}" deleted.',
            style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openAdd(BuildContext context, {Accommodation? editing}) async {
    final tripId = _activeTripId!;
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
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _activeTripId) {
        _activeTripId = next;
        _load();
        _subscribe(next);
      }
    });
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

    final scaffold = Scaffold(
      backgroundColor: kColorCream,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text('Stay', style: kStyleTitle),
            pinned: true,
            actions: [
              if (_items.isNotEmpty) ...[
                if (!kIsWeb)
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded),
                    color: kColorInkSoft,
                    tooltip: 'Export stays as CSV',
                    onPressed: _exportCsv,
                  ),
                PopupMenuButton<_StaySort>(
                  icon: Icon(
                    Icons.sort_rounded,
                    color: _sort != _StaySort.checkIn ? kColorPrimary : kColorInkSoft,
                  ),
                  tooltip: 'Sort stays',
                  initialValue: _sort,
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => [
                    _staySortItem(_StaySort.checkIn,     'By check-in date', _sort),
                    _staySortItem(_StaySort.alphabetical, 'A – Z',            _sort),
                    _staySortItem(_StaySort.newest,       'Newest added',     _sort),
                  ],
                ),
              ],
              const SizedBox(width: kSpace2),
            ],
          ),
          SliverToBoxAdapter(
            child: WabwaySearchBar(
              controller: _searchCtrl,
              hint: 'Search stays…',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          SliverToBoxAdapter(
            child: WabwayFilterStrip<AccommodationStatus>(
              selected: _filterStatus,
              options: AccommodationStatus.values.map((s) => (
                value: s,
                label: s.label,
                count: _count(s),
              )).toList(),
              allCount: _count(null),
              autoHide: false,
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
                    itemBuilder: (ctx, i) {
                      final item = filtered[i];
                      return Dismissible(
                        key: ValueKey('stay_${item.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          await _deleteItem(ctx, item);
                          return false;
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: kSpace5),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: kRadiusMd,
                          ),
                          child: const Icon(Icons.delete_rounded,
                              color: Colors.red, size: 22),
                        ),
                        child: _AccommodationCard(
                          item: item,
                          onTap: () => _openAdd(context, editing: item),
                        ),
                      );
                    },
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
    if (!_offline) return scaffold;
    return Stack(
      children: [
        scaffold,
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: OfflineBanner(onRetry: _load),
        ),
      ],
    );
  }
}

// â"€â"€â"€ Accommodation card â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€â"€

class _AccommodationCard extends StatelessWidget {
  const _AccommodationCard({required this.item, required this.onTap});

  final Accommodation item;
  final VoidCallback onTap;

  // Returns a short countdown string based on today's date, or null if there
  // are no dates or the stay is already over.
  String? _countdownLabel() {
    if (item.checkIn == null || item.checkOut == null) return null;
    final now     = DateTime.now();
    final today   = DateTime(now.year, now.month, now.day);
    final checkIn = DateTime(item.checkIn!.year, item.checkIn!.month, item.checkIn!.day);
    final checkOut = DateTime(item.checkOut!.year, item.checkOut!.month, item.checkOut!.day);
    if (today.isAfter(checkOut)) return null;
    if (!today.isBefore(checkIn)) return "Staying now";
    final diff = checkIn.difference(today).inDays;
    if (diff == 0) return "Check-in today!";
    if (diff == 1) return "Check-in tomorrow";
    return "Check-in in $diff days";
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imageUrl != null && item.imageUrl!.isNotEmpty;
    final source   = item.detectedSource;
    final nightStr = item.nights != null ? "${item.nights} night${item.nights == 1 ? "" : "s"}" : null;
    final countdown = _countdownLabel();

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
      dateStr = '${fmtDate(item.checkIn!)} → ${fmtDate(item.checkOut!)}';
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
                      if (countdown != null) ...[
                        const SizedBox(height: kSpace2),
                        Text(
                          countdown,
                          style: kStyleCaption.copyWith(
                            color: countdown == 'Staying now'
                                ? kColorSuccess
                                : kColorPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      if (item.confirmationNumber != null) ...[
                        const SizedBox(height: kSpace2),
                        Row(
                          children: [
                            const Icon(Icons.confirmation_number_outlined, size: 13, color: kColorInkSoft),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                item.confirmationNumber!,
                                style: kStyleCaption.copyWith(color: kColorInkSoft),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: item.confirmationNumber!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Confirmation number copied'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              },
                              child: const Icon(Icons.copy_rounded, size: 13, color: kColorInkSoft),
                            ),
                          ],
                        ),
                      ],
                      if (item.url != null && item.url!.isNotEmpty) ...[
                        const SizedBox(height: kSpace2),
                        GestureDetector(
                          onTap: () async {
                            final uri = Uri.tryParse(item.url!);
                            if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                          child: Text(
                            'Open booking →',
                            style: kStyleCaption.copyWith(
                              color: kColorPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
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

  static String _currencySymbol(String code) => switch (code) {
        'USD' => '\$',
        'EUR' => 'â‚¬',
        'GBP' => 'Â£',
        'JPY' => 'Â¥',
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

// ─── Sort helper ──────────────────────────────────────────────────────────────

PopupMenuItem<_StaySort> _staySortItem(
    _StaySort value, String label, _StaySort current) {
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

// ─── Sheet result ─────────────────────────────────────────────────────────────

class AccommodationSheetResult {
  const AccommodationSheetResult({this.accommodation, this.deleted = false});
  final Accommodation? accommodation;
  final bool deleted;
}
