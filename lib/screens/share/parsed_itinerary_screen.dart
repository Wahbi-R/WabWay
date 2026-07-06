import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../core/ocr/parse_counter.dart';
import '../../core/ocr/parsed_booking.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/plan_service.dart';
import '../../core/supabase/travel_service.dart';
import '../../data/docs_data.dart';
import '../../data/plan_data.dart';
import '../../data/travel_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

class ParsedItineraryScreen extends StatefulWidget {
  const ParsedItineraryScreen({
    super.key,
    required this.bookings,
    required this.tripId,
    required this.userId,
    this.sourceBytes,
    this.sourceExt,
    this.sourceFileName,
    this.onDone,
  });

  final List<ParsedBooking> bookings;
  final String tripId;
  final String userId;
  final Uint8List? sourceBytes;
  final String?    sourceExt;
  final String?    sourceFileName;
  final VoidCallback? onDone;

  @override
  State<ParsedItineraryScreen> createState() => _ParsedItineraryScreenState();
}

class _ParsedItineraryScreenState extends State<ParsedItineraryScreen> {
  late final List<bool> _selected;
  late final List<bool> _addToPlan;
  late final List<TextEditingController> _titleCtrls;
  bool   _saving      = false;
  int    _remaining   = ParseCounter.dailyLimit;
  List<TripDay> _days = [];
  bool   _daysLoading = false;

  @override
  void initState() {
    super.initState();
    _selected   = List.filled(widget.bookings.length, true);
    // Default add-to-plan to true for all confirmed booking types
    _addToPlan  = widget.bookings.map(_defaultAddToPlan).toList();
    _titleCtrls = widget.bookings
        .map((b) => TextEditingController(text: b.title))
        .toList();
    _loadRemaining();
    _loadDays();
  }

  static bool _defaultAddToPlan(ParsedBooking b) =>
      b.itemType == TravelItemType.flight ||
      b.itemType == TravelItemType.train  ||
      b.itemType == TravelItemType.hotel  ||
      b.itemType == TravelItemType.reservation;

  Future<void> _loadRemaining() async {
    final r = await ParseCounter.remaining();
    if (mounted) setState(() => _remaining = r);
  }

  Future<void> _loadDays() async {
    setState(() => _daysLoading = true);
    try {
      final days = await PlanService.loadAll(widget.tripId);
      if (mounted) setState(() => _days = days);
    } finally {
      if (mounted) setState(() => _daysLoading = false);
    }
  }

  TripDay? _matchingDay(DateTime bookingDate) {
    for (final d in _days) {
      if (d.date.year  == bookingDate.year  &&
          d.date.month == bookingDate.month &&
          d.date.day   == bookingDate.day) return d;
    }
    return null;
  }

  @override
  void dispose() {
    for (final c in _titleCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // 1. Upload source file once if provided
      String? docId;
      if (widget.sourceBytes != null && widget.sourceExt != null) {
        final ext = widget.sourceExt!;
        final doc = await DocService.uploadAndCreate(
          tripId:  widget.tripId,
          userId:  widget.userId,
          title:   widget.sourceFileName?.replaceAll(RegExp(r'\.[^.]+$'), '') ?? 'Booking document',
          type:    ext == 'pdf' ? DocType.other : DocType.flight,
          ext:     ext,
          bytes:   widget.sourceBytes!,
        );
        docId = doc.id;
      }

      // 2. Save each selected booking
      int count = 0;
      for (int i = 0; i < widget.bookings.length; i++) {
        if (!_selected[i]) continue;
        final b     = widget.bookings[i];
        final title = _titleCtrls[i].text.trim().isEmpty ? b.title : _titleCtrls[i].text.trim();

        // 2a. Create plan item first (if requested) so we get its ID for linking
        String? planItemId;
        if (_addToPlan[i]) {
          final day = _matchingDay(b.date);
          if (day != null) {
            final planItem = await PlanService.createItem(
              tripId:      widget.tripId,
              dayId:       day.id,
              title:       title,
              type:        _planType(b.itemType),
              createdBy:   widget.userId,
              time:        b.departureTime,
              notes:       b.notes.isEmpty ? null : b.notes,
              linkedDocIds: docId != null ? [docId] : [],
            );
            planItemId = planItem.id;
          }
        }

        // 2b. Create travel item
        final travelItem = await TravelService.createItem(
          tripId:                widget.tripId,
          title:                 title,
          type:                  b.itemType,
          createdBy:             widget.userId,
          date:                  b.date,
          time:                  b.departureTime,
          notes:                 b.notes.isEmpty ? null : b.notes,
          linkedItineraryItemId: planItemId,
          linkedDocIds:          docId != null ? [docId] : [],
        );

        // 2c. Link doc → travel item
        if (docId != null) {
          await DocService.addLink(
            documentId: docId,
            linkedType: DocLinkedType.travelItem,
            linkedId:   travelItem.id,
            createdBy:  widget.userId,
          );
        }

        // 2d. Link doc → plan item
        if (docId != null && planItemId != null) {
          await DocService.addLink(
            documentId: docId,
            linkedType: DocLinkedType.itineraryItem,
            linkedId:   planItemId,
            createdBy:  widget.userId,
          );
        }

        count++;
      }

      if (!mounted) return;
      final planCount = _selected
          .asMap()
          .entries
          .where((e) => e.value && _addToPlan[e.key] && _matchingDay(widget.bookings[e.key].date) != null)
          .length;
      final msg = planCount > 0
          ? 'Saved $count booking${count == 1 ? '' : 's'} to Travel and $planCount to Plan'
          : 'Saved $count booking${count == 1 ? '' : 's'} to Travel';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg,
            style: kStyleBodyMedium.copyWith(color: kColorTextOnPrimary)),
        backgroundColor: kColorPrimary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
        margin: const EdgeInsets.all(kSpace4),
      ));
      widget.onDone?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static ItineraryItemType _planType(TravelItemType t) => switch (t) {
        TravelItemType.flight      => ItineraryItemType.travel,
        TravelItemType.train       => ItineraryItemType.travel,
        TravelItemType.hotel       => ItineraryItemType.other,
        TravelItemType.reservation => ItineraryItemType.activity,
        TravelItemType.ticket      => ItineraryItemType.activity,
        _                          => ItineraryItemType.other,
      };

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.where((s) => s).length;
    final isAi = widget.bookings.any((b) => b.isAi);

    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Parsed bookings', style: kStyleTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── Source banner ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, 0),
            child: _SourceBanner(
              isAi: isAi,
              remaining: _remaining,
              hasFile: widget.sourceBytes != null,
            ),
          ),
          const SizedBox(height: kSpace3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpace4),
            child: Text(
              'Found ${widget.bookings.length} booking${widget.bookings.length == 1 ? '' : 's'}. '
              'Deselect any you don\'t want to save.',
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          ),
          const SizedBox(height: kSpace3),

          // ── Booking cards ──────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: kSpace4, vertical: kSpace2),
              itemCount: widget.bookings.length,
              separatorBuilder: (_, __) => const SizedBox(height: kSpace3),
              itemBuilder: (_, i) => _BookingCard(
                booking:    widget.bookings[i],
                selected:   _selected[i],
                addToPlan:  _addToPlan[i],
                titleCtrl:  _titleCtrls[i],
                matchingDay: _matchingDay(widget.bookings[i].date),
                daysLoading: _daysLoading,
                onToggle:    (v) => setState(() => _selected[i] = v),
                onPlanToggle: (v) => setState(() => _addToPlan[i] = v),
              ),
            ),
          ),

          // ── Save button ───────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(kSpace4),
              child: FilledButton(
                onPressed: selectedCount == 0 || _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: kColorPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Save $selectedCount item${selectedCount == 1 ? '' : 's'} to Travel',
                        style: kStyleBodyMedium.copyWith(
                            color: kColorTextOnPrimary),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Source banner ─────────────────────────────────────────────────────────────

class _SourceBanner extends StatelessWidget {
  const _SourceBanner({
    required this.isAi,
    required this.remaining,
    required this.hasFile,
  });
  final bool isAi;
  final int  remaining;
  final bool hasFile;

  @override
  Widget build(BuildContext context) {
    if (isAi) {
      final pct = (remaining / ParseCounter.dailyLimit * 100).round();
      final low = remaining < 100;
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpace3, vertical: kSpace2),
        decoration: BoxDecoration(
          color: low ? const Color(0xFFFFF3E0) : const Color(0xFFE8F5EE),
          borderRadius: kRadiusMd,
          border: Border.all(
            color: low
                ? const Color(0xFFE65100).withValues(alpha: 0.3)
                : kColorSuccess.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(
              low ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
              size: 16,
              color: low ? const Color(0xFFE65100) : kColorSuccess,
            ),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Text(
                low
                    ? 'Only $remaining AI parses left today ($pct% remaining)'
                    : 'AI-parsed · $remaining free parses left today',
                style: kStyleCaption.copyWith(
                  color: low ? const Color(0xFFE65100) : kColorSuccess,
                ),
              ),
            ),
            if (hasFile) ...[
              const SizedBox(width: kSpace2),
              const Icon(Icons.attach_file_rounded, size: 14, color: kColorInkSoft),
              const SizedBox(width: kSpace1),
              Text('File linked', style: kStyleCaption.copyWith(color: kColorInkSoft)),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: kSpace3, vertical: kSpace2),
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.document_scanner_rounded,
              size: 16, color: kColorInkSoft),
          const SizedBox(width: kSpace2),
          Expanded(
            child: Text(
              'Parsed on-device (OCR)',
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          ),
          if (hasFile) ...[
            const SizedBox(width: kSpace2),
            const Icon(Icons.attach_file_rounded, size: 14, color: kColorInkSoft),
            const SizedBox(width: kSpace1),
            Text('File linked', style: kStyleCaption.copyWith(color: kColorInkSoft)),
          ],
        ],
      ),
    );
  }
}

// ─── Booking card ──────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.selected,
    required this.addToPlan,
    required this.titleCtrl,
    required this.matchingDay,
    required this.daysLoading,
    required this.onToggle,
    required this.onPlanToggle,
  });

  final ParsedBooking   booking;
  final bool            selected;
  final bool            addToPlan;
  final TextEditingController titleCtrl;
  final TripDay?        matchingDay;
  final bool            daysLoading;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onPlanToggle;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return WabwayCard(
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: b.itemType.softColor,
                    borderRadius: kRadiusSm,
                  ),
                  child: Icon(b.itemType.icon, size: 18, color: b.itemType.color),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.itemType.label, style: kStyleBodySemibold),
                      if (b.airline != null)
                        Text(b.airline!,
                            style: kStyleCaption.copyWith(color: kColorInkSoft)),
                    ],
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: (v) => onToggle(v ?? false),
                  activeColor: kColorPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4)),
                ),
              ],
            ),
            const SizedBox(height: kSpace3),

            // Route row
            if (b.departureCity != null && b.arrivalCity != null)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.departureTime ?? '', style: kStyleBodySemibold),
                        Text(b.departureCity!,
                            style: kStyleCaption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: kColorInkSoft),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${b.arrivalTime ?? ''}${b.nextDay ? ' +1' : ''}',
                          style: kStyleBodySemibold,
                        ),
                        Text(b.arrivalCity!,
                            style: kStyleCaption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right),
                      ],
                    ),
                  ),
                ],
              )
            else
              Text(b.notes,
                  style: kStyleCaption.copyWith(color: kColorInkSoft),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis),

            const SizedBox(height: kSpace3),

            // Date + cabin
            Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 12, color: kColorInkSoft),
                const SizedBox(width: kSpace1),
                Text(_fmtDate(b.date),
                    style: kStyleCaption.copyWith(color: kColorInkSoft)),
                if (b.cabinClass != null) ...[
                  const SizedBox(width: kSpace3),
                  const Icon(Icons.airline_seat_recline_normal_rounded,
                      size: 12, color: kColorInkSoft),
                  const SizedBox(width: kSpace1),
                  Text(b.cabinClass!,
                      style: kStyleCaption.copyWith(color: kColorInkSoft)),
                ],
              ],
            ),

            // Editable title
            const SizedBox(height: kSpace3),
            TextField(
              controller: titleCtrl,
              style: kStyleCaption,
              decoration: InputDecoration(
                labelText: 'Travel item title',
                labelStyle: kStyleCaption.copyWith(color: kColorInkSoft),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: kSpace3, vertical: kSpace2),
                border: OutlineInputBorder(
                  borderRadius: kRadiusSm,
                  borderSide: const BorderSide(color: kColorBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: kRadiusSm,
                  borderSide: const BorderSide(color: kColorBorder),
                ),
              ),
            ),

            // ── Add to plan toggle ─────────────────────────────────────────
            const SizedBox(height: kSpace3),
            const Divider(color: kColorBorder, height: 1),
            const SizedBox(height: kSpace2),
            _PlanToggle(
              addToPlan:   addToPlan,
              matchingDay: matchingDay,
              daysLoading: daysLoading,
              onToggle:    onPlanToggle,
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) {
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month]} ${d.day}, ${d.year}';
  }
}

// ─── Plan toggle row ───────────────────────────────────────────────────────────

class _PlanToggle extends StatelessWidget {
  const _PlanToggle({
    required this.addToPlan,
    required this.matchingDay,
    required this.daysLoading,
    required this.onToggle,
  });

  final bool     addToPlan;
  final TripDay? matchingDay;
  final bool     daysLoading;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    if (daysLoading) {
      return Row(
        children: [
          const SizedBox(
            width: 14, height: 14,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: kColorInkSoft),
          ),
          const SizedBox(width: kSpace2),
          Text('Checking plan days…',
              style: kStyleCaption.copyWith(color: kColorInkSoft)),
        ],
      );
    }

    final canAdd = matchingDay != null;
    final sub = canAdd
        ? 'Day ${matchingDay!.dayNumber} – ${matchingDay!.city}'
        : 'No matching plan day for this date';

    return Row(
      children: [
        SizedBox(
          width: 20, height: 20,
          child: Checkbox(
            value: canAdd && addToPlan,
            onChanged: canAdd ? (v) => onToggle(v ?? false) : null,
            activeColor: kColorPrimary,
            visualDensity: VisualDensity.compact,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: kSpace2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Also add to itinerary',
                style: kStyleCaption.copyWith(
                  color: canAdd ? kColorInk : kColorInkSoft,
                ),
              ),
              Text(
                sub,
                style: kStyleCaption.copyWith(
                  color: canAdd ? kColorInkSoft : kColorInkSoft.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
