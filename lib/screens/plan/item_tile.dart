import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/plan_data.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';

// ─── Single itinerary item row in timeline ────────────────────────────────────

class ItineraryItemTile extends StatelessWidget {
  const ItineraryItemTile({
    super.key,
    required this.item,
    required this.isLast,
    this.selected = false,
    required this.onTap,
  });

  final ItineraryItem item;
  final bool isLast;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: selected
            ? item.type.color.withValues(alpha: 0.07)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: kSpace4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time column
              SizedBox(
                width: 50,
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: item.hasTime
                      ? Text(
                          item.time!,
                          style: GoogleFonts.ibmPlexMono(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected ? item.type.color : kColorInkSoft,
                          ),
                          textAlign: TextAlign.right,
                        )
                      : Text(
                          '—',
                          style: kStyleCaption.copyWith(
                            color: kColorInkSoft.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.right,
                        ),
                ),
              ),

              const SizedBox(width: kSpace3),

              // Timeline dot + vertical line
              Column(
                children: [
                  const SizedBox(height: 16),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: item.type.color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: item.type.color.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: const BoxDecoration(
                          color: kColorBorder,
                          borderRadius: kRadiusPill,
                        ),
                      ),
                    ),
                  if (isLast) const SizedBox(height: kSpace4),
                ],
              ),

              const SizedBox(width: kSpace3),

              // Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: kSpace2,
                    bottom: isLast ? kSpace4 : kSpace3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Type icon
                          Padding(
                            padding: const EdgeInsets.only(top: 1, right: 6),
                            child: Icon(
                              item.type.icon,
                              size: 14,
                              color: item.type.color,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.title,
                              style: kStyleBodyMedium.copyWith(
                                color: selected ? item.type.color : kColorInk,
                              ),
                            ),
                          ),
                          if (item.hasLinks) _LinkBadges(item: item),
                        ],
                      ),
                      if (item.city != null || item.location != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.location ?? item.city!,
                          style: kStyleCaption.copyWith(
                            fontSize: 11,
                            color: kColorInkSoft,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Chevron
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: kColorInkSoft.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Link badges ──────────────────────────────────────────────────────────────

class _LinkBadges extends StatelessWidget {
  const _LinkBadges({required this.item});
  final ItineraryItem item;

  @override
  Widget build(BuildContext context) {
    final hasSpot = item.linkedSpotId != null;
    final docCount = item.linkedDocIds.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSpot) ...[
          const SizedBox(width: kSpace1),
          _MiniChip(
            icon: Icons.place_rounded,
            color: ItineraryItemType.spot.color,
            softColor: ItineraryItemType.spot.softColor,
          ),
        ],
        if (docCount > 0) ...[
          const SizedBox(width: kSpace1),
          _MiniChip(
            icon: Icons.insert_drive_file_rounded,
            color: const Color(0xFF5B6E8A),
            softColor: const Color(0xFFEBEFF4),
            count: docCount > 1 ? docCount : null,
          ),
        ],
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.icon,
    required this.color,
    required this.softColor,
    this.count,
  });

  final IconData icon;
  final Color color;
  final Color softColor;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: kRadiusPill,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          if (count != null) ...[
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Spot name lookup helper ──────────────────────────────────────────────────

String? spotName(String? id) {
  if (id == null) return null;
  return kMockSpots.where((s) => s.id == id).firstOrNull?.name;
}

// ─── Doc title lookup helper ──────────────────────────────────────────────────

TripDocument? docById(String id) =>
    kMockDocuments.where((d) => d.id == id).firstOrNull;
