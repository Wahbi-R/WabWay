import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/travel_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';

// Returns a short countdown label relative to today, or null when there is
// no date or the item's start date has already passed.
String? _countdownLabel(TravelItem item) {
  final start = item.date;
  if (start == null) return null;
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day   = DateTime(start.year, start.month, start.day);
  if (today.isAfter(day)) return null;
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today!';
  if (diff == 1) return 'Tomorrow';
  return 'In $diff days';
}

class TravelItemCard extends StatefulWidget {
  const TravelItemCard({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
  });

  final TravelItem item;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  State<TravelItemCard> createState() => _TravelItemCardState();
}

class _TravelItemCardState extends State<TravelItemCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final color = item.type.color;
    final softColor = item.type.softColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: kDurationFast,
          curve: kEaseStandard,
          decoration: BoxDecoration(
            color: widget.isSelected ? softColor : kColorPaper,
            borderRadius: kRadiusLg,
            border: Border.all(
              color: widget.isSelected
                  ? color.withValues(alpha: 0.35)
                  : _hovered
                      ? kColorBorderStrong
                      : kColorBorder,
              width: widget.isSelected ? 1.5 : 1,
            ),
            boxShadow: _hovered && !widget.isSelected ? kShadowMd : kShadowSm,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Type stripe
                Container(
                  width: 5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        kSpace3, kSpace3, kSpace3, kSpace3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _TypeChip(type: item.type),
                            if (item.status != TravelBookingStatus.booked) ...[
                              const SizedBox(width: kSpace2),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: item.status.softColor,
                                  borderRadius: kRadiusPill,
                                  border: Border.all(color: item.status.color.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  item.status.label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: item.status.color,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (item.time != null)
                              Text(
                                item.time!,
                                style: GoogleFonts.ibmPlexMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: kSpace2),
                        Text(
                          item.title,
                          style: kStyleBodySemibold,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: kSpace1),
                        _RouteRow(item: item),
                        if (item.hasDate) ...[
                          const SizedBox(height: kSpace2),
                          _DateRow(item: item),
                        ],
                        if (_countdownLabel(item) != null) ...[
                          const SizedBox(height: kSpace1),
                          Text(
                            _countdownLabel(item)!,
                            style: kStyleCaption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (item.hasConfirmation) ...[
                          const SizedBox(height: kSpace2),
                          _ConfirmationRow(number: item.confirmationNumber!),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Type chip ────────────────────────────────────────────────────────────────

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.type});
  final TravelItemType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: kRadiusPill,
        border: Border.all(color: type.color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: type.color),
          const SizedBox(width: 4),
          Text(
            type.label,
            style: kStyleCaption.copyWith(
              color: type.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Route row ────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  const _RouteRow({required this.item});
  final TravelItem item;

  @override
  Widget build(BuildContext context) {
    if (item.isTransit && item.location != null && item.destination != null) {
      return Row(
        children: [
          Flexible(
            child: Text(
              item.location!,
              style: kStyleCaption.copyWith(color: kColorInkSoft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpace1),
            child: Icon(
              item.type == TravelItemType.flight
                  ? Icons.flight_rounded
                  : Icons.arrow_forward_rounded,
              size: 12,
              color: kColorInkSoft,
            ),
          ),
          Flexible(
            child: Text(
              item.destination!,
              style: kStyleCaption.copyWith(color: kColorInkSoft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    final loc = item.address ?? item.location;
    if (loc == null) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(Icons.place_rounded, size: 12, color: kColorInkSoft),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            loc,
            style: kStyleCaption.copyWith(color: kColorInkSoft),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Date row ─────────────────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  const _DateRow({required this.item});
  final TravelItem item;

  @override
  Widget build(BuildContext context) {
    final dateStr = item.hasEndDate
        ? fmtTravelDateRange(item.date!, item.endDate!)
        : fmtTravelDate(item.date!);

    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded, size: 12, color: kColorInkSoft),
        const SizedBox(width: 3),
        Text(
          dateStr,
          style: GoogleFonts.ibmPlexMono(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: kColorInkSoft,
          ),
        ),
      ],
    );
  }
}

// ─── Confirmation row ─────────────────────────────────────────────────────────

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.number});
  final String number;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.confirmation_number_rounded, size: 12, color: kColorInkSoft),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            number,
            style: GoogleFonts.ibmPlexMono(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: kColorInkSoft,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
