import 'dart:async';
import 'dart:math' show min, max;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/async_screen_mixin.dart';
import '../core/providers/trip_provider.dart';
import '../core/supabase/accommodation_service.dart';
import '../core/supabase/client.dart';
import '../core/supabase/spot_service.dart';
import '../data/accommodation_data.dart';
import '../data/spot_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'spots/spot_detail.dart';
import 'spots/add_spot_sheet.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.initialFocus});

  final LatLng? initialFocus;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with AsyncScreenMixin {
  List<Spot> _spots = [];
  List<Accommodation> _accommodations = [];
  bool _showMap = true;
  final Set<SpotCategory> _hiddenCategories = {};
  String? _activeTripId;
  RealtimeChannel? _realtimeChannel;
  Timer? _debounce;

  final _mapController = MapController();
  bool _needsFit = true;   // fit-to-bounds on first successful load only
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeTripId = ref.read(activeTripIdProvider);
      _load(_activeTripId!);
      _subscribeRealtime(_activeTripId!);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _realtimeChannel?.unsubscribe();
    _mapController.dispose();
    super.dispose();
  }

  void _subscribeRealtime(String tripId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supabase
        .channel('map-all-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'spots',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400),
                () { if (mounted) _load(tripId, silent: true); });
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'spot_votes',
          callback: (_) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 400),
                () { if (mounted) _load(tripId, silent: true); });
          },
        )
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
            _debounce = Timer(const Duration(milliseconds: 400),
                () { if (mounted) _load(tripId, silent: true); });
          },
        )
        .subscribe();
  }

  Future<void> _load(String tripId, {bool silent = false}) async {
    final gen = beginLoad(silent: silent);
    try {
      final results = await Future.wait([
        SpotService.loadSpots(tripId),
        AccommodationService.loadAll(tripId).catchError((_) => <Accommodation>[]),
      ]);
      commitLoad(gen, () {
        _spots = results[0] as List<Spot>;
        _accommodations = results[1] as List<Accommodation>;
      });
      if (!isStale(gen)) _fitIfNeeded();
    } catch (_) {
      failLoad(gen, silent: silent || _spots.isNotEmpty);
    }
  }

  List<Spot> get _mappedSpots =>
      _spots.where((s) => s.isMapReady).toList();

  List<Accommodation> get _mappedAccommodations =>
      _accommodations.where((a) => a.latitude != null && a.longitude != null).toList();

  List<LatLng> get _allMappedPoints => [
    ..._mappedSpots.map((s) => LatLng(s.latitude!, s.longitude!)),
    ..._mappedAccommodations.map((a) => LatLng(a.latitude!, a.longitude!)),
  ];

  List<Spot> get _visibleSpots => _hiddenCategories.isEmpty
      ? _mappedSpots
      : _mappedSpots.where((s) => !_hiddenCategories.contains(s.category)).toList();

  List<SpotCategory> get _presentCategories {
    final seen = <SpotCategory>{};
    for (final s in _mappedSpots) {
      seen.add(s.category);
    }
    return SpotCategory.values.where(seen.contains).toList();
  }

  void _fitIfNeeded() {
    if (!_needsFit) return;
    final focus = widget.initialFocus;
    if (focus != null) {
      _needsFit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _mapController.move(focus, 16);
      });
      return;
    }
    final pts = _allMappedPoints;
    if (pts.isEmpty) return; // leave _needsFit=true so we retry when spots load
    _needsFit = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (pts.length == 1) {
        _mapController.move(pts.first, 14);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: _boundsOf(pts),
            padding: const EdgeInsets.all(56),
          ),
        );
      }
    });
  }

  LatLngBounds _boundsOf(List<LatLng> pts) {
    final lats = pts.map((p) => p.latitude);
    final lngs = pts.map((p) => p.longitude);
    return LatLngBounds(
      LatLng(lats.reduce(min), lngs.reduce(min)),
      LatLng(lats.reduce(max), lngs.reduce(max)),
    );
  }

  LatLng get _center {
    final pts = _allMappedPoints;
    if (pts.isEmpty) return const LatLng(35.6762, 139.6503); // Tokyo default
    final lat = pts.map((p) => p.latitude).reduce((a, b) => a + b) / pts.length;
    final lng = pts.map((p) => p.longitude).reduce((a, b) => a + b) / pts.length;
    return LatLng(lat, lng);
  }

  VoteType? _myVoteFor(Spot spot, String? userId) {
    if (userId == null) return null;
    if (spot.votes.mustDo.contains(userId)) return VoteType.mustDo;
    if (spot.votes.want.contains(userId)) return VoteType.want;
    if (spot.votes.maybe.contains(userId)) return VoteType.maybe;
    if (spot.votes.skip.contains(userId)) return VoteType.skip;
    return null;
  }

  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      if (kIsWeb) {
        // On web the browser handles the permission prompt directly.
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 15),
          ),
        );
        if (mounted) _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
        return;
      }
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are off — enable them in Settings')),
          );
          await Geolocator.openLocationSettings();
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location access is blocked — opening Settings')),
          );
          await Geolocator.openAppSettings();
        }
        return;
      }
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      if (mounted) {
        _mapController.move(LatLng(pos.latitude, pos.longitude), 15);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get location')),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addSpotAtLatLng(LatLng point) async {
    final tripId = ref.read(activeTripIdProvider);
    final userId = supabase.auth.currentUser?.id ?? '';
    final spot = await showAddSpotSheet(
      context,
      tripId: tripId,
      userId: userId,
      initialLatitude:  point.latitude,
      initialLongitude: point.longitude,
    );
    if (spot != null && mounted) {
      setState(() => _spots.insert(0, spot));
    }
  }

  void _openStayDetail(Accommodation stay) {
    final linkedSpot = stay.spotId != null
        ? _spots.where((s) => s.id == stay.spotId).firstOrNull
        : null;
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StayDetailSheet(stay: stay, linkedSpot: linkedSpot),
    );
  }

  void _openDetail(Spot spot) {
    final userId = supabase.auth.currentUser?.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, ctrl) => DecoratedBox(
          decoration: const BoxDecoration(
            color: kColorPaper,
            borderRadius: kRadiusSheet,
          ),
          child: SingleChildScrollView(
            controller: ctrl,
            padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
            child: SpotDetailContent(
              spot: spot,
              myVote: _myVoteFor(spot, userId),
              canDelete: spot.addedById == userId,
              onEdit: (updated) => setState(() {
                final idx = _spots.indexWhere((s) => s.id == updated.id);
                if (idx != -1) _spots[idx] = updated;
              }),
              onDelete: spot.addedById == userId
                  ? () async {
                      final nav = Navigator.of(ctx);
                      try {
                        await SpotService.deleteSpot(spot.id);
                        if (!mounted) return;
                        setState(() => _spots.removeWhere((s) => s.id == spot.id));
                        nav.pop();
                      } catch (_) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not delete spot. Try again.')),
                        );
                      }
                    }
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(activeTripIdProvider, (prev, next) {
      if (next != _activeTripId) {
        _activeTripId = next;
        _debounce?.cancel();
        _load(next);
        _subscribeRealtime(next);
      }
    });
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Map', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _activeTripId == null ? null : () => _load(_activeTripId!), // explicit user refresh — show spinner
          ),
          // Map / List toggle
          Padding(
            padding: const EdgeInsets.only(right: kSpace3),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.map_rounded, size: 16),
                  label: Text('Map'),
                ),
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.list_rounded, size: 16),
                  label: Text('List'),
                ),
              ],
              selected: {_showMap},
              onSelectionChanged: (s) => setState(() => _showMap = s.first),
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : error
              ? Center(
                  child: WabwayEmptyState(
                    icon: Icons.wifi_off_rounded,
                    title: 'Failed to load',
                    description: 'Could not load spots.',
                    action: WabwayButton(
                      label: 'Retry',
                      onPressed: () => _load(_activeTripId!),
                    ),
                  ),
                )
              : _showMap
                  ? _buildMap()
                  : _buildList(),
    );
  }

  // ─── Map view ────────────────────────────────────────────────────────────────

  Widget _categoryFilterStrip() {
    final cats = _presentCategories;
    if (cats.length < 2) return const SizedBox.shrink();
    return Positioned(
      top: kSpace2,
      left: 0,
      right: 0,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kSpace3),
        child: Row(
          children: cats.map((cat) {
            final hidden = _hiddenCategories.contains(cat);
            final count  = _mappedSpots.where((s) => s.category == cat).length;
            return Padding(
              padding: const EdgeInsets.only(right: kSpace2),
              child: GestureDetector(
                onTap: () => setState(() {
                  if (hidden) {
                    _hiddenCategories.remove(cat);
                  } else {
                    _hiddenCategories.add(cat);
                  }
                }),
                child: AnimatedContainer(
                  duration: kDurationFast,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: hidden
                        ? kColorInkSoft.withValues(alpha: 0.08)
                        : kColorPaper,
                    borderRadius: kRadiusPill,
                    border: Border.all(
                      color: hidden ? kColorBorder : kColorBorderStrong,
                    ),
                    boxShadow: hidden ? [] : kShadowSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        cat.icon,
                        size: 13,
                        color: hidden ? kColorInkSoft : kColorInk,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${cat.label} $count',
                        style: kStyleCaption.copyWith(
                          color: hidden ? kColorInkSoft : kColorInk,
                          fontWeight: hidden ? FontWeight.w400 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMap() {
    final pts = _allMappedPoints;

    if (pts.isEmpty) {
      return const Center(
        child: WabwayEmptyState(
          icon: Icons.map_outlined,
          title: 'No spots or stays on map yet',
          description: 'Add spots with a Google Maps URL or add stays with an address to see them here.',
        ),
      );
    }

    final visible        = _visibleSpots;
    final mappedStays    = _mappedAccommodations;
    final unmappedSpots  = _spots.length - _mappedSpots.length;
    final unmappedStays  = _accommodations.length - mappedStays.length;
    final totalUnmapped  = unmappedSpots + unmappedStays;

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _center,
            initialZoom: 12,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onLongPress: (_, point) => _addSpotAtLatLng(point),
          ),
          children: [
            TileLayer(
              // Esri World Street Map — English labels worldwide, no API key required
              urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
              userAgentPackageName: 'ca.wabble.wabway',
              maxNativeZoom: 19,
              maxZoom: 22,
            ),
            const SimpleAttributionWidget(
              source: Text('Tiles © Esri'),
            ),
            MarkerLayer(
              markers: visible.map((spot) {
                return Marker(
                  point: LatLng(spot.latitude!, spot.longitude!),
                  width: 40,
                  height: 56,
                  child: GestureDetector(
                    onTap: () => _openDetail(spot),
                    child: _SpotMarker(spot: spot),
                  ),
                );
              }).toList(),
            ),
            MarkerLayer(
              markers: mappedStays.map((stay) {
                return Marker(
                  point: LatLng(stay.latitude!, stay.longitude!),
                  width: 40,
                  height: 56,
                  child: GestureDetector(
                    onTap: () => _openStayDetail(stay),
                    child: _StayMarker(stay: stay),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        _categoryFilterStrip(),

        // FAB + unmapped banner stacked in a column at the bottom
        Positioned(
          bottom: MediaQuery.paddingOf(context).bottom + kSpace3,
          left: kSpace4,
          right: kSpace4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.small(
                heroTag: 'map_location',
                backgroundColor: Colors.white,
                foregroundColor: kColorPrimary,
                elevation: 2,
                tooltip: 'Go to my location',
                onPressed: _locating ? null : _goToMyLocation,
                child: _locating
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
              if (totalUnmapped > 0) ...[
                const SizedBox(height: kSpace3),
                DecoratedBox(
                  decoration: kCardDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpace4, vertical: kSpace3),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: kColorInkSoft),
                        const SizedBox(width: kSpace2),
                        Expanded(
                          child: Text(
                            '$totalUnmapped item${totalUnmapped == 1 ? '' : 's'} without coordinates — switch to List to see all.',
                            style: kStyleCaption.copyWith(color: kColorInkSoft),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _showMap = false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: kSpace2, vertical: 0),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('See all',
                              style: kStyleCaptionMedium.copyWith(
                                  color: kColorPrimary)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─── List view ────────────────────────────────────────────────────────────────

  Widget _buildList() {
    final hasSpots = _spots.isNotEmpty;
    final hasStays = _accommodations.isNotEmpty;

    if (!hasSpots && !hasStays) {
      return const Center(
        child: WabwayEmptyState(
          icon: Icons.place_outlined,
          title: 'Nothing here yet',
          description: 'Add spots from the Spots tab or stays from the Stays tab.',
        ),
      );
    }

    final mappedSpots     = _mappedSpots;
    final unmappedSpots   = _spots.where((s) => !s.isMapReady).toList();
    final mappedStays     = _mappedAccommodations;
    final unmappedStays   = _accommodations.where((a) => a.latitude == null || a.longitude == null).toList();

    return RefreshIndicator(
      onRefresh: () => _load(_activeTripId!),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            kSpace4, kSpace3, kSpace4,
            kSpace6 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (mappedSpots.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.my_location_rounded,
              label: 'Spots on map (${mappedSpots.length})',
              color: kColorSuccess,
            ),
            const SizedBox(height: kSpace2),
            ...mappedSpots.map((s) => _SpotListRow(
                  spot: s,
                  showMapIcon: true,
                  onTap: () {
                    setState(() => _showMap = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _mapController.move(
                          LatLng(s.latitude!, s.longitude!), 15);
                    });
                  },
                  onDetailTap: () => _openDetail(s),
                )),
            const SizedBox(height: kSpace4),
          ],
          if (mappedStays.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.hotel_rounded,
              label: 'Stays on map (${mappedStays.length})',
              color: const Color(0xFF7B61FF),
            ),
            const SizedBox(height: kSpace2),
            ...mappedStays.map((a) => _StayListRow(
                  stay: a,
                  showMapIcon: true,
                  onTap: () {
                    setState(() => _showMap = true);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _mapController.move(
                          LatLng(a.latitude!, a.longitude!), 15);
                    });
                  },
                  onDetailTap: () => _openStayDetail(a),
                )),
            const SizedBox(height: kSpace4),
          ],
          if (unmappedSpots.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.location_off_rounded,
              label: 'Spots without coordinates (${unmappedSpots.length})',
              color: kColorInkSoft,
            ),
            const SizedBox(height: kSpace2),
            ...unmappedSpots.map((s) => _SpotListRow(
                  spot: s,
                  showMapIcon: false,
                  onTap: () => _openDetail(s),
                  onDetailTap: () => _openDetail(s),
                )),
            const SizedBox(height: kSpace4),
          ],
          if (unmappedStays.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.location_off_rounded,
              label: 'Stays without coordinates (${unmappedStays.length})',
              color: kColorInkSoft,
            ),
            const SizedBox(height: kSpace2),
            ...unmappedStays.map((a) => _StayListRow(
                  stay: a,
                  showMapIcon: false,
                  onTap: () => _openStayDetail(a),
                  onDetailTap: () => _openStayDetail(a),
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Map marker ───────────────────────────────────────────────────────────────

class _SpotMarker extends StatelessWidget {
  const _SpotMarker({required this.spot});
  final Spot spot;

  Color get _color => switch (spot.status) {
        SpotStatus.idea      => const Color(0xFF9E9E9E),
        SpotStatus.wantToGo  => kColorPrimary,
        SpotStatus.mustDo    => kColorAccent,
        SpotStatus.confirmed => kColorSuccess,
        SpotStatus.planned   => const Color(0xFF7D9A75),
        SpotStatus.booked    => kColorSuccess,
        SpotStatus.visited   => kColorSuccess,
        SpotStatus.skipped   => kColorDanger,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: Icon(
            spot.category.icon,
            size: 15,
            color: Colors.white,
          ),
        ),
        CustomPaint(
          size: const Size(10, 8),
          painter: _PinTailPainter(color: _color),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  const _PinTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = ui.Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

// ─── List row ─────────────────────────────────────────────────────────────────

class _SpotListRow extends StatelessWidget {
  const _SpotListRow({
    required this.spot,
    required this.showMapIcon,
    required this.onTap,
    required this.onDetailTap,
  });

  final Spot     spot;
  final bool     showMapIcon;
  final VoidCallback onTap;
  final VoidCallback onDetailTap;

  Color get _statusColor => switch (spot.status) {
        SpotStatus.idea      => const Color(0xFF9E9E9E),
        SpotStatus.wantToGo  => kColorPrimary,
        SpotStatus.mustDo    => kColorAccent,
        SpotStatus.confirmed => kColorSuccess,
        SpotStatus.planned   => const Color(0xFF7D9A75),
        SpotStatus.booked    => kColorSuccess,
        SpotStatus.visited   => kColorSuccess,
        SpotStatus.skipped   => kColorDanger,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: WabwayCard(
        hoverable: true,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(spot.category.icon, size: 18, color: _statusColor),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(spot.name,
                      style: kStyleBodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('${spot.city}, ${spot.area}',
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: kSpace2),
            if (showMapIcon)
              const Icon(Icons.my_location_rounded,
                  size: 14, color: kColorSuccess),
            const SizedBox(width: kSpace2),
            WabwayBadge(label: spot.status.label, tone: spot.status.tone),
            const SizedBox(width: kSpace2),
            GestureDetector(
              onTap: onDetailTap,
              child: const Icon(Icons.chevron_right_rounded,
                  size: 18, color: kColorInkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: kStyleOverline.copyWith(color: color, letterSpacing: 0.5)),
      ],
    );
  }
}

// ─── Stay marker ──────────────────────────────────────────────────────────────

class _StayMarker extends StatelessWidget {
  const _StayMarker({required this.stay});
  final Accommodation stay;

  Color get _color => switch (stay.status) {
        AccommodationStatus.brainstorming => const Color(0xFF9E9E9E),
        AccommodationStatus.shortlisted   => const Color(0xFFB8860B),
        AccommodationStatus.booked        => kColorSuccess,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.hotel_rounded, size: 15, color: Colors.white),
        ),
        CustomPaint(
          size: const Size(10, 8),
          painter: _PinTailPainter(color: _color),
        ),
      ],
    );
  }
}

// ─── Stay list row ────────────────────────────────────────────────────────────

class _StayListRow extends StatelessWidget {
  const _StayListRow({
    required this.stay,
    required this.showMapIcon,
    required this.onTap,
    required this.onDetailTap,
  });

  final Accommodation stay;
  final bool          showMapIcon;
  final VoidCallback  onTap;
  final VoidCallback  onDetailTap;

  Color get _statusColor => switch (stay.status) {
        AccommodationStatus.brainstorming => const Color(0xFF9E9E9E),
        AccommodationStatus.shortlisted   => const Color(0xFFB8860B),
        AccommodationStatus.booked        => kColorSuccess,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: WabwayCard(
        hoverable: true,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.hotel_rounded, size: 18, color: _statusColor),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(stay.name,
                      style: kStyleBodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(stay.city,
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: kSpace2),
            if (showMapIcon)
              const Icon(Icons.my_location_rounded, size: 14, color: kColorSuccess),
            const SizedBox(width: kSpace2),
            WabwayBadge(label: stay.status.label, tone: stay.status.tone),
            const SizedBox(width: kSpace2),
            GestureDetector(
              onTap: onDetailTap,
              child: const Icon(Icons.chevron_right_rounded,
                  size: 18, color: kColorInkSoft),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stay detail sheet ────────────────────────────────────────────────────────

class _StayDetailSheet extends StatelessWidget {
  const _StayDetailSheet({required this.stay, this.linkedSpot});
  final Accommodation stay;
  final Spot? linkedSpot;

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusSheet,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kSpace4,
          kSpace4,
          kSpace4,
          kSpace4 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kColorPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.hotel_rounded, size: 20, color: kColorPrimary),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stay.name, style: kStyleBodyBold),
                      Text(stay.city, style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    ],
                  ),
                ),
                WabwayBadge(label: stay.status.label, tone: stay.status.tone),
              ],
            ),
            if (stay.address != null) ...[
              const SizedBox(height: kSpace3),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined, size: 14, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(stay.address!,
                        style: kStyleCaption.copyWith(color: kColorInkSoft)),
                  ),
                ],
              ),
            ],
            if (stay.checkIn != null || stay.checkOut != null) ...[
              const SizedBox(height: kSpace2),
              Row(
                children: [
                  const Icon(Icons.date_range_rounded, size: 14, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Text('${_fmt(stay.checkIn)} → ${_fmt(stay.checkOut)}',
                      style: kStyleCaption.copyWith(color: kColorInkSoft)),
                  if (stay.nights != null) ...[
                    const SizedBox(width: kSpace2),
                    Text('(${stay.nights} nights)',
                        style: kStyleCaption.copyWith(color: kColorInkSoft)),
                  ],
                ],
              ),
            ],
            if (linkedSpot != null) ...[
              const SizedBox(height: kSpace2),
              Row(
                children: [
                  Icon(linkedSpot!.category.icon, size: 14, color: kColorInkSoft),
                  const SizedBox(width: kSpace2),
                  Expanded(
                    child: Text(linkedSpot!.name,
                        style: kStyleCaption.copyWith(color: kColorInkSoft),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  WabwayBadge(
                    label: linkedSpot!.status.label,
                    tone: linkedSpot!.status.tone,
                  ),
                ],
              ),
            ],
            if (stay.notes != null) ...[
              const SizedBox(height: kSpace2),
              Text(stay.notes!,
                  style: kStyleCaption.copyWith(color: kColorInkSoft),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}
