import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../core/image_cache_manager.dart';
import '../../core/places/listing_parser.dart';
import '../../core/supabase/accommodation_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../data/accommodation_data.dart';
import '../../data/connection_data.dart' show EntityType;
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'accommodations_screen.dart';
import '../shared/attached_docs_section.dart';
import '../../data/docs_data.dart';
import '../shared/connections_section.dart';
import '../../data/date_utils.dart';
import '../../data/currencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/stay_receipt_sync.dart';
import '../../data/money_data.dart' show fmtAmount, TripMember;
import '../../widgets/place_search_field.dart';

/// Add / edit a stay. Pops with an [AccommodationSheetResult].
Future<AccommodationSheetResult?> showAddStaySheet(
  BuildContext context, {
  required String tripId,
  required String userId,
  Accommodation? editing,
  Accommodation? draft,
  ListingResult? prefilled,
  String? initialUrl,
}) =>
    showWabwayFormSheet<AccommodationSheetResult>(
      context,
      desktopHeightFactor: 0.9,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (ctx, scroll, handle, close) => AddAccommodationSheet(
        tripId: tripId,
        userId: userId,
        editing: editing,
        draft: draft,
        prefilled: prefilled,
        initialUrl: initialUrl,
        scrollController: scroll,
        showDragHandle: handle,
      ),
    );

class AddAccommodationSheet extends StatefulWidget {
  const AddAccommodationSheet({
    super.key,
    required this.tripId,
    required this.userId,
    this.editing,
    this.draft,
    this.prefilled,
    this.initialUrl,
    this.scrollController,
    this.showDragHandle = true,
  });

  final String tripId;
  final String userId;
  final Accommodation? editing;

  /// A complete new stay to start from (Read booking's review screen):
  /// fills every field like [editing] but saving creates a new stay.
  final Accommodation? draft;
  final ListingResult? prefilled;
  final String? initialUrl;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<AddAccommodationSheet> createState() => _AddAccommodationSheetState();
}

class _AddAccommodationSheetState extends State<AddAccommodationSheet> {
  int _step = 0;

  final _urlCtrl     = TextEditingController();
  final _nameCtrl    = TextEditingController();
  final _cityCtrl    = TextEditingController();
  final _priceCtrl   = TextEditingController();
  final _notesCtrl   = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool   _parsing   = false;
  bool   _saving    = false;
  bool   _deleting  = false;

  String _currency = 'USD';
  /// The price field holds the whole stay's total (only offered once the
  /// dates give a number of nights); saved as total ÷ nights.
  bool _priceIsTotal = false;
  AccommodationStatus _status = AccommodationStatus.brainstorming;
  AccommodationSource? _source;
  DateTime? _checkIn;
  DateTime? _checkOut;
  TimeOfDay? _checkInTime;
  TimeOfDay? _checkOutTime;
  String? _imageUrl;
  String? _address;
  String? _parseError;

  String? _linkedSpotId;
  Spot?   _linkedSpot;

  @override
  void initState() {
    super.initState();
    final e = widget.editing ?? widget.draft;
    if (e != null) {
      _step        = 1;
      _nameCtrl.text = e.name;
      _cityCtrl.text = e.city;
      _urlCtrl.text  = e.url ?? '';
      // Bookings are paid as a total, so show that when the nights are known.
      final total = e.totalPrice;
      if (total != null) {
        _priceIsTotal   = true;
        _priceCtrl.text = _priceText(total);
      } else if (e.pricePerNight != null) {
        _priceCtrl.text = _priceText(e.pricePerNight!);
      }
      _notesCtrl.text    = e.notes ?? '';
      _confirmCtrl.text  = e.confirmationNumber ?? '';
      _currency   = e.currency;
      _status     = e.status;
      _source     = e.source;
      _checkIn    = e.checkIn;
      _checkOut   = e.checkOut;
      _checkInTime  = parseTimeOfDay(e.checkInTime);
      _checkOutTime = parseTimeOfDay(e.checkOutTime);
      _imageUrl        = e.imageUrl;
      _address         = e.address;
      _linkedSpotId    = e.spotId;
      if (e.spotId != null) _loadLinkedSpot(e.spotId!);
    } else if (widget.prefilled != null) {
      _applyPrefilled(widget.prefilled!);
      if (widget.initialUrl != null) _urlCtrl.text = widget.initialUrl!;
      _step = 1;
    } else if (widget.initialUrl != null) {
      _urlCtrl.text = widget.initialUrl!;
    }
  }

  void _applyPrefilled(ListingResult r) {
    _nameCtrl.text = r.name;
    _cityCtrl.text = r.city ?? '';
    _imageUrl      = r.imageUrl;
    _source        = r.source;
    if (r.pricePerNight != null) {
      _priceCtrl.text = _priceText(r.pricePerNight!);
    }
    if (r.currency != null) _currency = r.currency!;
    if (r.checkIn != null) _checkIn = r.checkIn;
    if (r.checkOut != null) _checkOut = r.checkOut;
    if (r.confirmationNumber != null) _confirmCtrl.text = r.confirmationNumber!;
  }

  static String _priceText(double v) =>
      v % 1 == 0 ? '${v.toInt()}' : v.toStringAsFixed(2);

  int? get _nights {
    if (_checkIn == null || _checkOut == null) return null;
    final n = _checkOut!.difference(_checkIn!).inDays;
    return n > 0 ? n : null;
  }

  bool get _isTotal => _priceIsTotal && _nights != null;

  /// What the price field means per night.
  double? get _pricePerNight {
    final v = double.tryParse(_priceCtrl.text.trim());
    if (v == null) return null;
    return _isTotal ? v / _nights! : v;
  }

  /// Switch the field between per night and total, converting what's typed.
  void _setPriceIsTotal(bool total) {
    if (total == _isTotal) return;
    final v = double.tryParse(_priceCtrl.text.trim());
    final n = _nights;
    setState(() {
      if (v != null && n != null) {
        _priceCtrl.text = _priceText(total ? v * n : double.parse((v / n).toStringAsFixed(2)));
      }
      _priceIsTotal = total;
    });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _priceCtrl.dispose();
    _notesCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _parseUrl() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _parsing = true; _parseError = null; });
    try {
      final result = await ListingParser.parse(url);
      if (!mounted) return;
      if (result != null) {
        _applyPrefilled(result);
        setState(() { _step = 1; _parsing = false; });
      } else {
        setState(() {
          _parsing    = false;
          _parseError = 'Could not parse that URL — please fill in manually.';
          _step       = 1;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _parsing    = false;
        _parseError = 'Could not reach that URL.';
        _step       = 1;
      });
    }
  }

  Future<void> _save() async {
    final name   = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    try {
      final price   = _pricePerNight;
      final url     = _urlCtrl.text.trim();
      final city    = _cityCtrl.text.trim();
      final notes   = _notesCtrl.text.trim();
      final confirm = _confirmCtrl.text.trim();
      final inTime  = _fmtTime(_checkInTime);
      final outTime = _fmtTime(_checkOutTime);

      Accommodation result;
      if (widget.editing != null) {
        final updated = widget.editing!.copyWith(
          name:               name,
          url:                url.isEmpty ? null : url,
          city:               city,
          pricePerNight:      price,
          currency:           _currency,
          checkIn:            _checkIn,
          checkOut:           _checkOut,
          checkInTime:        inTime,
          checkOutTime:       outTime,
          status:             _status,
          source:             _source,
          notes:              notes.isEmpty ? null : notes,
          imageUrl:           _imageUrl,
          confirmationNumber: confirm.isEmpty ? null : confirm,
          spotId:             _linkedSpotId,
        );
        result = await AccommodationService.update(updated);
      } else {
        result = await AccommodationService.create(
          tripId:             widget.tripId,
          userId:             widget.userId,
          name:               name,
          city:               city,
          url:                url.isEmpty ? null : url,
          address:            _address,
          pricePerNight:      price,
          currency:           _currency,
          checkIn:            _checkIn,
          checkOut:           _checkOut,
          checkInTime:        inTime,
          checkOutTime:       outTime,
          status:             _status,
          source:             _source ?? (url.isNotEmpty ? AccommodationSource.fromUrl(url) : null),
          notes:              notes.isEmpty ? null : notes,
          imageUrl:           _imageUrl,
          confirmationNumber: confirm.isEmpty ? null : confirm,
          spotId:             _linkedSpotId,
        );
      }
      if (!mounted) return;
      // Changed the total: offer to change its receipt in Money to match.
      if (widget.editing != null) {
        final container = ProviderScope.containerOf(context, listen: false);
        await offerReceiptUpdateForStay(
          context,
          before: widget.editing!,
          after: result,
          members: [
            for (final m in container.read(tripMembersProvider))
              TripMember(id: m.userId, name: m.profile.displayName, isMe: m.userId == widget.userId),
          ],
          homeCurrency: container.read(activeTripProvider)?.homeCurrency,
        );
        if (!mounted) return;
      }
      Navigator.pop(context, AccommodationSheetResult(accommodation: result));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showWabwaySnack(context, 'Could not save stay.', error: true);
    }
  }

  static String? _fmtTime(TimeOfDay? t) =>
      t == null ? null : fmtTimeOfDay(t.hour, t.minute);

  Future<void> _delete() async {
    final id = widget.editing?.id;
    if (id == null) return;
    setState(() => _deleting = true);
    try {
      await AccommodationService.delete(id);
      if (!mounted) return;
      Navigator.pop(context, const AccommodationSheetResult(deleted: true));
    } catch (_) {
      if (!mounted) return;
      setState(() => _deleting = false);
      showWabwaySnack(context, 'Could not delete stay.', error: true);
    }
  }

  Future<void> _loadLinkedSpot(String spotId) async {
    try {
      final spots = await SpotService.loadSpots(widget.tripId);
      if (!mounted) return;
      setState(() => _linkedSpot = spots.where((s) => s.id == spotId).firstOrNull);
    } catch (_) {}
  }

  Future<void> _pickSpot() async {
    List<Spot> spots;
    try {
      spots = await SpotService.loadSpots(widget.tripId);
    } catch (_) {
      spots = [];
    }
    if (!mounted) return;

    final result = await showModalBottomSheet<_SpotPickerResult>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SpotPickerSheet(
        spots: spots,
        selectedId: _linkedSpotId,
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _linkedSpotId = result.spot?.id;
      _linkedSpot   = result.spot;
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(
        start: _checkIn ?? now,
        end: _checkOut ??
            (_checkIn?.add(const Duration(days: 1)) ??
                now.add(const Duration(days: 1))),
      ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _checkIn = picked.start;
      _checkOut = picked.end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scrollCtrl = widget.scrollController;
          return Column(
            children: [
              if (widget.showDragHandle) const WabwayDragHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, 0),
                child: Row(
                  children: [
                    Text(
                      widget.editing != null ? 'Edit stay' : 'Add stay',
                      style: kStyleTitle,
                    ),
                    const Spacer(),
                    WabwayIconButton(
                      icon: Icons.close_rounded,
                      label: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _step == 0 ? _buildStep0(scrollCtrl) : _buildStep1(scrollCtrl),
              ),
            ],
          );
  }

  // ─── Step 0: URL input ──────────────────────────────────────────────────────

  Widget _buildStep0(ScrollController? ctrl) {
    return SingleChildScrollView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, kSpace8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: kSpace2),
          WabwayTextField(
            label: 'Paste a listing URL',
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _parseUrl(),
          ),
          if (_parseError != null) ...[
            const SizedBox(height: kSpace2),
            Text(_parseError!, style: kStyleCaption.copyWith(color: kColorDanger)),
          ],
          const SizedBox(height: kSpace4),
          WabwayButton(
            label: 'Parse listing',
            icon: Icons.travel_explore_rounded,
            loading: _parsing,
            onPressed: _parsing ? null : _parseUrl,
            fullWidth: true,
          ),
          const SizedBox(height: kSpace3),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _step = 1),
              child: Text(
                'Add manually',
                style: kStyleBodyMedium.copyWith(color: kColorInkSoft),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step 1: Form ────────────────────────────────────────────────────────────

  Widget _buildStep1(ScrollController? ctrl) {
    final hasImage = _imageUrl != null && _imageUrl!.isNotEmpty;
    final isEditing = widget.editing != null;
    final detectedSrc = _source ??
        (_urlCtrl.text.trim().isNotEmpty
            ? AccommodationSource.fromUrl(_urlCtrl.text.trim())
            : null);

    return SingleChildScrollView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage) ...[
            ClipRRect(
              borderRadius: kRadiusMd,
              child: CachedNetworkImage(
                imageUrl: _imageUrl!,
                cacheManager: WabwayImageCache.instance,
                width: double.infinity,
                height: 160,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: kSpace4),
          ],

          WabwayTextField(
            label: 'Name',
            controller: _nameCtrl,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: kSpace3),

          PlaceSearchField(
            label: 'City',
            hint: 'e.g. Kyoto',
            controller: _cityCtrl,
            textInputAction: TextInputAction.next,
            limit: 4,
            onSelected: (p) => _cityCtrl.text = p.city.isNotEmpty ? p.city : p.name,
          ),
          const SizedBox(height: kSpace3),

          if (_nights != null) ...[
            WabwayChoiceChips<bool>(
              label: 'Price',
              choices: const [WabwayChoice(false, 'Per night'), WabwayChoice(true, 'Total')],
              selected: _isTotal,
              onChanged: _setPriceIsTotal,
            ),
            const SizedBox(height: kSpace2),
          ],
          Row(
            children: [
              Expanded(
                child: WabwayTextField(
                  label: _isTotal ? 'Total for ${_nights == 1 ? '1 night' : '$_nights nights'}' : 'Price per night',
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: kSpace3),
              SizedBox(
                width: 100,
                child: _CurrencySelector(
                  value: _currency,
                  onChanged: (v) => setState(() => _currency = v),
                ),
              ),
            ],
          ),
          if (_nights != null && _pricePerNight != null) ...[
            const SizedBox(height: kSpace1),
            Text(
              _isTotal
                  ? '${fmtAmount(_pricePerNight!, _currency)} / night'
                  : '${fmtAmount(_pricePerNight! * _nights!, _currency)} total',
              style: kStyleCaption,
            ),
          ],
          const SizedBox(height: kSpace3),

          Row(
            children: [
              Expanded(
                child: WabwayPickerField(
                  label: 'Check-in',
                  value: _checkIn == null ? null : fmtDateLong(_checkIn!),
                  onTap: _pickDateRange,
                ),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: WabwayPickerField(
                  label: 'Check-out',
                  value: _checkOut == null ? null : fmtDateLong(_checkOut!),
                  onTap: _pickDateRange,
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),

          // Hotel policy times, e.g. "check-in from 15:00, check-out by 11:00".
          Row(
            children: [
              Expanded(
                child: WabwayTimeField(
                  label: 'Check-in from',
                  value: _checkInTime,
                  initialPickerTime: const TimeOfDay(hour: 15, minute: 0),
                  onChanged: (t) => setState(() => _checkInTime = t),
                ),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: WabwayTimeField(
                  label: 'Check-out by',
                  value: _checkOutTime,
                  initialPickerTime: const TimeOfDay(hour: 11, minute: 0),
                  onChanged: (t) => setState(() => _checkOutTime = t),
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace4),

          WabwayChoiceChips<AccommodationStatus>(
            label: 'Status',
            choices: [for (final s in AccommodationStatus.values) WabwayChoice(s, s.label)],
            selected: _status,
            onChanged: (s) => setState(() => _status = s),
          ),
          const SizedBox(height: kSpace3),

          WabwayTextField(
            label: 'Confirmation number (optional)',
            controller: _confirmCtrl,
            textInputAction: TextInputAction.next,
            hint: 'e.g. ABC123',
          ),
          const SizedBox(height: kSpace3),

          WabwayTextField(
            label: 'Notes (optional)',
            controller: _notesCtrl,
            maxLines: 3,
            textInputAction: TextInputAction.newline,
          ),
          const SizedBox(height: kSpace3),

          WabwayTextField(
            label: 'Listing URL',
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),

          const SizedBox(height: kSpace3),
          _SpotLinkTile(
            linkedSpot: _linkedSpot,
            linkedSpotId: _linkedSpotId,
            onTap: _pickSpot,
          ),

          if (detectedSrc != null && detectedSrc != AccommodationSource.other) ...[
            const SizedBox(height: kSpace3),
            Row(
              children: [
                Icon(detectedSrc.icon, size: 16, color: kColorInkSoft),
                const SizedBox(width: kSpace2),
                Text(detectedSrc.label,
                    style: kStyleCaption.copyWith(color: kColorInkSoft)),
              ],
            ),
          ],

          if (isEditing) ...[
            const SizedBox(height: kSpace5),
            const Divider(height: 1),
            const SizedBox(height: kSpace5),
            AttachedDocsSection(
              entityType: EntityType.stay,
              entityId: widget.editing!.id,
              tripId: widget.tripId,
              entityName: widget.editing!.name,
              uploadType: DocType.hotel,
            ),
            const SizedBox(height: kSpace5),
            ConnectionsSection(
              entityType: EntityType.stay,
              entityId: widget.editing!.id,
              tripId: widget.tripId,
            ),
          ],

          const SizedBox(height: kSpace5),

          WabwayButton(
            label: isEditing ? 'Update' : 'Save stay',
            loading: _saving,
            onPressed: _saving || _deleting ? null : _save,
            fullWidth: true,
            size: WabwayButtonSize.lg,
          ),

          if (isEditing) ...[
            const SizedBox(height: kSpace3),
            WabwayButton(
              label: 'Delete stay',
              variant: WabwayButtonVariant.dangerOutline,
              loading: _deleting,
              onPressed: _saving || _deleting ? null : _delete,
              fullWidth: true,
              size: WabwayButtonSize.lg,
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Currency selector ────────────────────────────────────────────────────────

class _CurrencySelector extends StatelessWidget {
  const _CurrencySelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;


  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: ButtonTheme(
          alignedDropdown: true,
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            style: kStyleBody.copyWith(color: kColorInk),
            dropdownColor: kColorPaper,
            borderRadius: kRadiusMd,
            items: [
              for (final c in currencyOptions(include: value))
                DropdownMenuItem(value: c.$1, child: Text(c.$1, style: kStyleBody)),
            ],
            onChanged: (v) { if (v != null) onChanged(v); },
          ),
        ),
      ),
    );
  }
}

// ─── Spot link tile ──────────────────────────────────────────────────────────

class _SpotPickerResult {
  const _SpotPickerResult(this.spot);
  final Spot? spot;
}

class _SpotLinkTile extends StatelessWidget {
  const _SpotLinkTile({
    required this.linkedSpot,
    required this.linkedSpotId,
    required this.onTap,
  });

  final Spot?   linkedSpot;
  final String? linkedSpotId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLinked = linkedSpotId != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 14),
        decoration: BoxDecoration(
          color: kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border: Border.all(
            color: isLinked ? kColorPrimary.withValues(alpha: 0.4) : kColorBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isLinked ? Icons.place_rounded : Icons.link_rounded,
              size: 16,
              color: isLinked ? kColorPrimary : kColorInkSoft,
            ),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Linked spot', style: kStyleOverline),
                  const SizedBox(height: 2),
                  Text(
                    isLinked
                        ? (linkedSpot?.name ?? 'Spot linked')
                        : 'None — tap to link',
                    style: kStyleBody.copyWith(
                      color: isLinked ? kColorInk : kColorInkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: kColorInkSoft),
          ],
        ),
      ),
    );
  }
}

// ─── Spot picker sheet ────────────────────────────────────────────────────────

class _SpotPickerSheet extends StatelessWidget {
  const _SpotPickerSheet({required this.spots, required this.selectedId});

  final List<Spot> spots;
  final String?    selectedId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollCtrl) {
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: kColorPaper,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
                child: Row(children: [WabwayDragHandle()]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(kSpace4, kSpace2, kSpace4, kSpace3),
                child: Row(
                  children: [
                    Text('Link to spot', style: kStyleTitle),
                    const Spacer(),
                    WabwayIconButton(
                      icon: Icons.close_rounded,
                      label: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: kSpace4, vertical: kSpace3),
                  children: [
                    if (selectedId != null)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.link_off_rounded,
                            color: kColorDanger),
                        title: Text('Remove link',
                            style: kStyleBody.copyWith(color: kColorDanger)),
                        onTap: () => Navigator.pop(
                            context, const _SpotPickerResult(null)),
                      ),
                    if (spots.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: kSpace8),
                        child: Text(
                          'No spots in this trip yet.',
                          style: kStyleCaption.copyWith(color: kColorInkSoft),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ...spots.map((s) {
                      final isSelected = s.id == selectedId;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          s.category.icon,
                          color: isSelected ? kColorPrimary : kColorInkSoft,
                          size: 20,
                        ),
                        title: Text(s.name,
                            style: kStyleBody.copyWith(
                              color: isSelected ? kColorPrimary : kColorInk,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            )),
                        subtitle: Text(s.city,
                            style: kStyleCaption.copyWith(
                                color: kColorInkSoft)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: kColorPrimary)
                            : null,
                        onTap: () =>
                            Navigator.pop(context, _SpotPickerResult(s)),
                      );
                    }),
                    const SizedBox(height: kSpace8),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

