import 'package:flutter/material.dart';
import '../../core/ocr/parse_counter.dart';
import '../../core/ocr/parsed_booking.dart';
import '../../core/supabase/travel_service.dart';
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
    this.onDone,
  });

  final List<ParsedBooking> bookings;
  final String tripId;
  final String userId;
  final VoidCallback? onDone;

  @override
  State<ParsedItineraryScreen> createState() => _ParsedItineraryScreenState();
}

class _ParsedItineraryScreenState extends State<ParsedItineraryScreen> {
  late final List<bool> _selected;
  late final List<TextEditingController> _titleCtrls;
  bool _saving = false;
  int _remaining = ParseCounter.dailyLimit;

  @override
  void initState() {
    super.initState();
    _selected  = List.filled(widget.bookings.length, true);
    _titleCtrls = widget.bookings
        .map((b) => TextEditingController(text: b.title))
        .toList();
    _loadRemaining();
  }

  Future<void> _loadRemaining() async {
    final r = await ParseCounter.remaining();
    if (mounted) setState(() => _remaining = r);
  }

  @override
  void dispose() {
    for (final c in _titleCtrls) c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (int i = 0; i < widget.bookings.length; i++) {
        if (!_selected[i]) continue;
        final b = widget.bookings[i];
        await TravelService.createItem(
          tripId:    widget.tripId,
          title:     _titleCtrls[i].text.trim().isEmpty ? b.title : _titleCtrls[i].text.trim(),
          type:      b.itemType,
          createdBy: widget.userId,
          date:      b.date,
          notes:     b.notes.isEmpty ? null : b.notes,
        );
      }
      if (!mounted) return;
      final count = _selected.where((s) => s).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved $count booking${count == 1 ? '' : 's'} to Travel',
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
            child: _SourceBanner(isAi: isAi, remaining: _remaining),
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
                booking:   widget.bookings[i],
                selected:  _selected[i],
                titleCtrl: _titleCtrls[i],
                onToggle:  (v) => setState(() => _selected[i] = v),
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
  const _SourceBanner({required this.isAi, required this.remaining});
  final bool isAi;
  final int remaining;

  @override
  Widget build(BuildContext context) {
    if (isAi) {
      final pct = (remaining / ParseCounter.dailyLimit * 100).round();
      final low = remaining < 100;
      return Container(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpace3, vertical: kSpace2),
        decoration: BoxDecoration(
          color: low
              ? const Color(0xFFFFF3E0)
              : const Color(0xFFE8F5EE),
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
          ],
        ),
      );
    }

    // OCR fallback
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
              'Parsed on-device (no AI key set — flights only)',
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          ),
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
    required this.titleCtrl,
    required this.onToggle,
  });

  final ParsedBooking booking;
  final bool selected;
  final TextEditingController titleCtrl;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return WabwayCard(
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
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

            // Route / detail row
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
                labelStyle:
                    kStyleCaption.copyWith(color: kColorInkSoft),
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
