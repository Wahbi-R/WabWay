import 'dart:math' show min, max;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show PostgresChangeEvent, PostgresChangeFilter, PostgresChangeFilterType, RealtimeChannel;
import '../core/supabase/client.dart';
import '../core/supabase/spot_service.dart';
import '../core/trip/trip_state.dart';
import '../data/spot_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';
import '../widgets/widgets.dart';
import 'spots/spot_detail.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Spot> _spots = [];
  bool _loading = true;
  bool _error = false;
  bool _showMap = true;
  String? _activeTripId;
  RealtimeChannel? _realtimeChannel;

  final _mapController = MapController();
  bool _needsFit = true;   // fit-to-bounds on first successful load only

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tripId = TripState.tripOf(context).id;
    if (tripId != _activeTripId) {
      _activeTripId = tripId;
      _load(tripId);
      _subscribeRealtime(tripId);
    }
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    _mapController.dispose();
    super.dispose();
  }

  void _subscribeRealtime(String tripId) {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = supabase
        .channel('map-spots-$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'spots',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) { if (mounted) _load(tripId); },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'spot_votes',
          callback: (_) { if (mounted) _load(tripId); },
        )
        .subscribe();
  }

  Future<void> _load(String tripId) async {
    setState(() { _loading = true; _error = false; });
    try {
      final spots = await SpotService.loadSpots(tripId);
      if (!mounted) return;
      setState(() { _spots = spots; _loading = false; });
      _fitIfNeeded();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  void _fitIfNeeded() {
    if (!_needsFit) return;
    final mapped = _mappedSpots;
    if (mapped.isEmpty) return;
    _needsFit = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (mapped.length == 1) {
        _mapController.move(
            LatLng(mapped.first.latitude!, mapped.first.longitude!), 14);
      } else {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: _spotBounds(mapped),
            padding: const EdgeInsets.all(56),
          ),
        );
      }
    });
  }

  LatLngBounds _spotBounds(List<Spot> spots) {
    final lats = spots.map((s) => s.latitude!);
    final lngs = spots.map((s) => s.longitude!);
    return LatLngBounds(
      LatLng(lats.reduce(min), lngs.reduce(min)),
      LatLng(lats.reduce(max), lngs.reduce(max)),
    );
  }

  List<Spot> get _mappedSpots =>
      _spots.where((s) => s.isMapReady).toList();

  LatLng get _center {
    final mapped = _mappedSpots;
    if (mapped.isEmpty) return const LatLng(35.6762, 139.6503); // Tokyo default
    final lat = mapped.map((s) => s.latitude!).reduce((a, b) => a + b) / mapped.length;
    final lng = mapped.map((s) => s.longitude!).reduce((a, b) => a + b) / mapped.length;
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

  void _openDetail(Spot spot) {
    final userId = supabase.auth.currentUser?.id;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
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
            child: SpotDetailContent(
              spot: spot,
              myVote: _myVoteFor(spot, userId),
              canDelete: spot.addedById == userId,
              onEdit: (updated) => setState(() {
                final idx = _spots.indexWhere((s) => s.id == updated.id);
                if (idx != -1) _spots[idx] = updated;
              }),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Map', style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh',
            onPressed: _activeTripId == null ? null : () => _load(_activeTripId!),
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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error
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

  Widget _buildMap() {
    final mapped = _mappedSpots;

    if (mapped.isEmpty) {
      return const Center(
        child: WabwayEmptyState(
          icon: Icons.map_outlined,
          title: 'No spots on map yet',
          description: 'Add spots with a Google Maps URL or use the search in the Spots screen to get coordinates.',
        ),
      );
    }

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
          ),
          children: [
            TileLayer(
              // Carto Voyager — English/Latin labels worldwide
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.example.wabway',
              maxNativeZoom: 19,
              maxZoom: 22,
              additionalOptions: const {'lang': 'en'},
              tileProvider: CancellableNetworkTileProvider(),
            ),
            MarkerLayer(
              markers: mapped.map((spot) {
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
          ],
        ),

        // Unmapped count banner
        if (_spots.length > mapped.length)
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + kSpace3,
            left: kSpace4,
            right: kSpace4,
            child: DecoratedBox(
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
                        '${_spots.length - mapped.length} spot${_spots.length - mapped.length == 1 ? '' : 's'} without coordinates — switch to List to see all.',
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
          ),
      ],
    );
  }

  // ─── List view ────────────────────────────────────────────────────────────────

  Widget _buildList() {
    if (_spots.isEmpty) {
      return const Center(
        child: WabwayEmptyState(
          icon: Icons.place_outlined,
          title: 'No spots yet',
          description: 'Add spots from the Spots tab.',
        ),
      );
    }

    // Group: mapped first, then unmapped
    final mapped   = _mappedSpots;
    final unmapped = _spots.where((s) => !s.isMapReady).toList();

    return RefreshIndicator(
      onRefresh: () => _load(_activeTripId!),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
            kSpace4, kSpace3, kSpace4,
            kSpace6 + MediaQuery.paddingOf(context).bottom),
        children: [
          if (mapped.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.my_location_rounded,
              label: 'On map (${mapped.length})',
              color: kColorSuccess,
            ),
            const SizedBox(height: kSpace2),
            ...mapped.map((s) => _SpotListRow(
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
          if (unmapped.isNotEmpty) ...[
            _SectionLabel(
              icon: Icons.location_off_rounded,
              label: 'No coordinates (${unmapped.length})',
              color: kColorInkSoft,
            ),
            const SizedBox(height: kSpace2),
            ...unmapped.map((s) => _SpotListRow(
                  spot: s,
                  showMapIcon: false,
                  onTap: () => _openDetail(s),
                  onDetailTap: () => _openDetail(s),
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
