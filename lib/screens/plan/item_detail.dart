import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/plan_data.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

// ─── Mobile screen ────────────────────────────────────────────────────────────

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.day,
    this.spots = const [],
    this.docs = const [],
    this.onDelete,
  });

  final ItineraryItem item;
  final TripDay day;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text(item.title, style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            color: kColorInkSoft,
            onPressed: () => _showActionsSheet(context, item, onDelete),
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        child: ItemDetailContent(
          item: item,
          day: day,
          spots: spots,
          docs: docs,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

// ─── Shared content ───────────────────────────────────────────────────────────

class ItemDetailContent extends StatelessWidget {
  const ItemDetailContent({
    super.key,
    required this.item,
    required this.day,
    this.spots = const [],
    this.docs = const [],
    this.onDelete,
  });

  final ItineraryItem item;
  final TripDay day;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final linkedSpot = item.linkedSpotId != null
        ? spots.where((s) => s.id == item.linkedSpotId).firstOrNull
        : null;
    final linkedDocs = item.linkedDocIds
        .map((id) => docs.where((d) => d.id == id).firstOrNull)
        .whereType<TripDocument>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemHeader(item: item, day: day),
        Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaCard(item: item),

              if (linkedSpot != null) ...[
                const SizedBox(height: kSpace4),
                _SpotSection(spot: linkedSpot),
              ],

              if (linkedDocs.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                _DocsSection(docs: linkedDocs),
              ],

              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                WabwayNotesSection(notes: item.notes!),
              ],

              const SizedBox(height: kSpace4),
              _ActionsSection(item: item, onDelete: onDelete),
              const SizedBox(height: kSpace8),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Header band ──────────────────────────────────────────────────────────────

class _ItemHeader extends StatelessWidget {
  const _ItemHeader({required this.item, required this.day});
  final ItineraryItem item;
  final TripDay day;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace5, kSpace4, kSpace5),
      decoration: BoxDecoration(color: item.type.softColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: item.type.color.withValues(alpha: 0.14),
                  borderRadius: kRadiusLg,
                ),
                child: Icon(item.type.icon, size: 26, color: item.type.color),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WabwayEntityBadge(icon: item.type.icon, label: item.type.label, color: item.type.color, iconSize: 12),
                    const SizedBox(height: kSpace1),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: item.type.color.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Day ${day.dayNumber} · ${fmtDayDate(day.date)}',
                          style: kStyleCaption.copyWith(
                            color: item.type.color.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (item.hasTime)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: item.type.color,
                    borderRadius: kRadiusPill,
                  ),
                  child: Text(
                    item.time!,
                    style: GoogleFonts.ibmPlexMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Text(
            item.title,
            style: kStyleTitle.copyWith(fontSize: 20, height: 1.25),
          ),
          if (item.city != null) ...[
            const SizedBox(height: kSpace1),
            Row(
              children: [
                Icon(
                  Icons.location_city_rounded,
                  size: 13,
                  color: item.type.color.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 4),
                Text(
                  item.city!,
                  style: kStyleCaption.copyWith(
                    color: item.type.color.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Metadata card ────────────────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.item});
  final ItineraryItem item;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String?)>[
      if (item.hasTime)
        (Icons.schedule_rounded, 'Time', item.time),
      if (item.city != null)
        (Icons.location_city_rounded, 'City', item.city),
      if (item.location != null)
        (Icons.place_rounded, 'Location', item.location),
      if (item.mapsUrl != null)
        (Icons.map_rounded, 'Google Maps', 'Link available'),
      if (item.confirmationUrl != null)
        (Icons.confirmation_number_rounded, 'Confirmation', 'Link available'),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusLg,
        border: Border.all(color: kColorBorder),
        boxShadow: kShadowSm,
      ),
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: kSpace4, thickness: 1, color: kColorBorder),
            WabwayMetaRow(icon: rows[i].$1, label: rows[i].$2, value: rows[i].$3 ?? ''),
          ],
        ],
      ),
    );
  }
}

// ─── Linked spot section ──────────────────────────────────────────────────────

class _SpotSection extends StatelessWidget {
  const _SpotSection({required this.spot});
  final Spot spot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Linked Spot', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        WabwayCard(
          hoverable: true,
          padding: const EdgeInsets.all(kSpace3),
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Navigate to spot: ${spot.name}',
                  style: kStyleBody.copyWith(color: Colors.white)),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ));
          },
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: kColorPrimarySoft,
                  borderRadius: kRadiusMd,
                ),
                child: const Icon(Icons.place_rounded,
                    size: 18, color: kColorPrimary),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spot.name, style: kStyleBodyMedium),
                    Text(
                      spot.city,
                      style: kStyleCaption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: kColorInkSoft),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Linked documents section ─────────────────────────────────────────────────

class _DocsSection extends StatelessWidget {
  const _DocsSection({required this.docs});
  final List<TripDocument> docs;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Documents', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: docs.map((d) => _DocChip(doc: d)).toList(),
        ),
      ],
    );
  }
}

class _DocChip extends StatelessWidget {
  const _DocChip({required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Open "${doc.title}"',
              style: kStyleBody.copyWith(color: Colors.white)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
        decoration: BoxDecoration(
          color: doc.type.softColor,
          borderRadius: kRadiusPill,
          border: Border.all(color: doc.type.color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(doc.type.icon, size: 13, color: doc.type.color),
            const SizedBox(width: kSpace1),
            Flexible(
              child: Text(
                doc.title,
                style: kStyleCaption.copyWith(
                  color: doc.type.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Actions section ──────────────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({required this.item, this.onDelete});
  final ItineraryItem item;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace3),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: [
            if (item.mapsUrl != null)
              WabwayButton(
                label: 'Open Maps',
                icon: Icons.map_rounded,
                size: WabwayButtonSize.sm,
                onPressed: () => _snack(context, 'Opening in Maps…'),
              ),
            WabwayButton(
              label: 'Attach Document',
              icon: Icons.attach_file_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _snack(context, 'Attach a document to this item'),
            ),
            WabwayButton(
              label: 'Edit',
              icon: Icons.edit_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _snack(context, 'Edit "${item.title}"'),
            ),
            WabwayButton(
              label: 'Delete',
              icon: Icons.delete_outline_rounded,
              variant: WabwayButtonVariant.danger,
              size: WabwayButtonSize.sm,
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ),
      ],
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: kStyleBody.copyWith(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Delete item?', style: kStyleBodySemibold),
        content: Text(
          'Remove "${item.title}" from the itinerary?',
          style: kStyleBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: kStyleBody.copyWith(color: kColorInkSoft)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call();
              if (context.mounted) Navigator.maybePop(context);
            },
            child: Text('Delete',
                style: kStyleBodyMedium.copyWith(color: kColorDanger)),
          ),
        ],
      ),
    );
  }
}

// ─── Mobile actions sheet ─────────────────────────────────────────────────────

void _showActionsSheet(
  BuildContext context,
  ItineraryItem item,
  VoidCallback? onDelete,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kColorPaper,
    shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WabwayDragHandle(),
          if (item.mapsUrl != null)
            WabwayActionTile(
              icon: Icons.map_rounded,
              label: 'Open in Maps',
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Opening in Maps…',
                      style: kStyleBody.copyWith(color: Colors.white)),
                  behavior: SnackBarBehavior.floating,
                ));
              },
            ),
          WabwayActionTile(
            icon: Icons.attach_file_rounded,
            label: 'Attach Document',
            onTap: () => Navigator.pop(ctx),
          ),
          WabwayActionTile(
            icon: Icons.edit_rounded,
            label: 'Edit item',
            onTap: () => Navigator.pop(ctx),
          ),
          WabwayActionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: kColorDanger,
            onTap: () {
              Navigator.pop(ctx);
              onDelete?.call();
              Navigator.maybePop(context);
            },
          ),
          const SizedBox(height: kSpace4),
        ],
      ),
    ),
  );
}

