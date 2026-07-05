import 'package:flutter/material.dart';
import '../../core/ocr/itinerary_parser.dart';
import '../../core/supabase/travel_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

class ParsedItineraryScreen extends StatefulWidget {
  const ParsedItineraryScreen({
    super.key,
    required this.flights,
    required this.tripId,
    required this.userId,
    this.onDone,
  });

  final List<ParsedFlight> flights;
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

  @override
  void initState() {
    super.initState();
    _selected = List.filled(widget.flights.length, true);
    _titleCtrls = widget.flights
        .map((f) => TextEditingController(text: f.title))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _titleCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      for (int i = 0; i < widget.flights.length; i++) {
        if (!_selected[i]) continue;
        final f = widget.flights[i];
        await TravelService.createItem(
          tripId:    widget.tripId,
          title:     _titleCtrls[i].text.trim().isEmpty
              ? f.title
              : _titleCtrls[i].text.trim(),
          type:      f.itemType,
          createdBy: widget.userId,
          date:      f.date,
          notes:     f.notes,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          'Saved ${_selected.where((s) => s).length} flight(s)',
          style: kStyleBodyMedium.copyWith(color: kColorTextOnPrimary),
        ),
        backgroundColor: kColorPrimary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
        margin: const EdgeInsets.all(kSpace4),
      ));
      widget.onDone?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selected.where((s) => s).length;
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Parsed flights', style: kStyleTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, 0),
            child: Text(
              'Found ${widget.flights.length} flight leg(s). '
              'Deselect any you don\'t want to save.',
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          ),
          const SizedBox(height: kSpace3),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(
                  horizontal: kSpace4, vertical: kSpace2),
              itemCount: widget.flights.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: kSpace3),
              itemBuilder: (context, i) =>
                  _FlightCard(
                    flight: widget.flights[i],
                    selected: _selected[i],
                    titleCtrl: _titleCtrls[i],
                    onToggle: (v) =>
                        setState(() => _selected[i] = v),
                  ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(kSpace4),
              child: FilledButton(
                onPressed: selectedCount == 0 || _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: kColorPrimary,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: kRadiusMd),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white),
                      )
                    : Text(
                        'Save $selectedCount flight${selectedCount == 1 ? '' : 's'} to Travel',
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

class _FlightCard extends StatelessWidget {
  const _FlightCard({
    required this.flight,
    required this.selected,
    required this.titleCtrl,
    required this.onToggle,
  });

  final ParsedFlight flight;
  final bool selected;
  final TextEditingController titleCtrl;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + checkbox
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: flight.itemType.softColor,
                    borderRadius: kRadiusSm,
                  ),
                  child: Icon(
                    flight.itemType.icon,
                    size: 18,
                    color: flight.itemType.color,
                  ),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        flight.flightNumber,
                        style: kStyleBodySemibold,
                      ),
                      if (flight.airline != null)
                        Text(
                          flight.airline!,
                          style: kStyleCaption.copyWith(
                              color: kColorInkSoft),
                        ),
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
            // Route + times
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(flight.departureTime,
                          style: kStyleBodySemibold),
                      Text(flight.departureCity,
                          style: kStyleCaption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded,
                    size: 16, color: kColorInkSoft),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${flight.arrivalTime}${flight.nextDay ? ' +1' : ''}',
                        style: kStyleBodySemibold,
                      ),
                      Text(flight.arrivalCity,
                          style: kStyleCaption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: kSpace3),
            // Date + cabin
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: kColorInkSoft),
                const SizedBox(width: kSpace1),
                Text(
                  _formatDate(flight.date),
                  style: kStyleCaption.copyWith(color: kColorInkSoft),
                ),
                if (flight.cabinClass != null) ...[
                  const SizedBox(width: kSpace3),
                  Icon(Icons.airline_seat_recline_normal_rounded,
                      size: 12, color: kColorInkSoft),
                  const SizedBox(width: kSpace1),
                  Text(
                    flight.cabinClass!,
                    style:
                        kStyleCaption.copyWith(color: kColorInkSoft),
                  ),
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
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month]} ${d.day}, ${d.year}';
  }
}
