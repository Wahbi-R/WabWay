import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/supabase/doc_service.dart';
import '../../data/plan_data.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'add_item_sheet.dart';

// â”€â”€â”€ Mobile screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ItemDetailScreen extends StatelessWidget {
  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.day,
    this.spots = const [],
    this.docs = const [],
    this.days = const [],
    this.onDelete,
    this.onUpdated,
    this.onMove,
    this.onDuplicate,
  });

  final ItineraryItem item;
  final TripDay day;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final List<TripDay> days;
  final VoidCallback? onDelete;
  final ValueChanged<ItineraryItem>? onUpdated;
  final ValueChanged<String>? onMove;
  final VoidCallback? onDuplicate;

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
            onPressed: () => _showActionsSheet(
              context, item, spots, docs, onDelete, onUpdated,
              days: days, onMove: onMove, onDuplicate: onDuplicate,
            ),
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
          days: days,
          onDelete: onDelete,
          onUpdated: onUpdated,
          onMove: onMove,
          onDuplicate: onDuplicate,
        ),
      ),
    );
  }
}

// â”€â”€â”€ Shared content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class ItemDetailContent extends StatelessWidget {
  const ItemDetailContent({
    super.key,
    required this.item,
    required this.day,
    this.spots = const [],
    this.docs = const [],
    this.days = const [],
    this.onDelete,
    this.onUpdated,
    this.onMove,
    this.onDuplicate,
  });

  final ItineraryItem item;
  final TripDay day;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final List<TripDay> days;
  final VoidCallback? onDelete;
  final ValueChanged<ItineraryItem>? onUpdated;
  final ValueChanged<String>? onMove;
  final VoidCallback? onDuplicate;

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
              _ActionsSection(
                item: item, spots: spots, docs: docs, days: days,
                onDelete: onDelete, onUpdated: onUpdated,
                onMove: onMove, onDuplicate: onDuplicate,
              ),
              const SizedBox(height: kSpace8),
            ],
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€ Header band â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
                          'Day ${day.dayNumber} Â· ${fmtDate(day.date)}',
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

// â”€â”€â”€ Metadata card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Linked spot section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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

// â”€â”€â”€ Linked documents section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
      onTap: () => _openDoc(context, doc),
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

// â”€â”€â”€ Actions section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.item,
    this.spots = const [],
    this.docs = const [],
    this.days = const [],
    this.onDelete,
    this.onUpdated,
    this.onMove,
    this.onDuplicate,
  });
  final ItineraryItem item;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final List<TripDay> days;
  final VoidCallback? onDelete;
  final ValueChanged<ItineraryItem>? onUpdated;
  final ValueChanged<String>? onMove;
  final VoidCallback? onDuplicate;

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
                onPressed: () => _openMaps(context, item.mapsUrl!),
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
              onPressed: () => _editItem(context),
            ),
            if (onDuplicate != null)
              WabwayButton(
                label: 'Duplicate',
                icon: Icons.copy_rounded,
                variant: WabwayButtonVariant.ghost,
                size: WabwayButtonSize.sm,
                onPressed: onDuplicate,
              ),
            if (onMove != null && days.length > 1)
              WabwayButton(
                label: 'Move day',
                icon: Icons.swap_vert_rounded,
                variant: WabwayButtonVariant.ghost,
                size: WabwayButtonSize.sm,
                onPressed: () => _moveItem(context),
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

  Future<void> _editItem(BuildContext context) async {
    final updated = await showAddItemSheet(
      context,
      dayId: item.dayId,
      spots: spots,
      docs: docs,
      initialItem: item,
    );
    if (updated != null && context.mounted) {
      onUpdated?.call(updated);
      Navigator.maybePop(context);
    }
  }

  Future<void> _moveItem(BuildContext context) async {
    final otherDays = days.where((d) => d.id != item.dayId).toList();
    if (otherDays.isEmpty || !context.mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoveToDaySheet(days: otherDays),
    );
    if (picked != null && context.mounted) onMove?.call(picked);
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

// â”€â”€â”€ Shared helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

Future<void> _openMaps(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Could not open Maps.', style: kStyleBody.copyWith(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

Future<void> _openDoc(BuildContext context, TripDocument doc) async {
  final String? url;
  if (doc.ext == 'url') {
    url = doc.notes;
  } else if (doc.storagePath != null) {
    url = await DocService.getSignedUrl(doc.storagePath!);
  } else {
    url = null;
  }
  if (url == null || url.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not open document.', style: kStyleBody.copyWith(color: Colors.white)),
        behavior: SnackBarBehavior.floating,
      ));
    }
    return;
  }
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Could not open document.', style: kStyleBody.copyWith(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
    ));
  }
}

// â”€â”€â”€ Mobile actions sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

void _showActionsSheet(
  BuildContext context,
  ItineraryItem item,
  List<Spot> spots,
  List<TripDocument> docs,
  VoidCallback? onDelete,
  ValueChanged<ItineraryItem>? onUpdated, {
  List<TripDay> days = const [],
  ValueChanged<String>? onMove, // newDayId
  VoidCallback? onDuplicate,
}) {
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
                _openMaps(context, item.mapsUrl!);
              },
            ),
          WabwayActionTile(
            icon: Icons.edit_rounded,
            label: 'Edit item',
            onTap: () async {
              Navigator.pop(ctx);
              final updated = await showAddItemSheet(
                context,
                dayId: item.dayId,
                spots: spots,
                docs: docs,
                initialItem: item,
              );
              if (updated != null && context.mounted) {
                onUpdated?.call(updated);
                Navigator.maybePop(context);
              }
            },
          ),
          if (onDuplicate != null)
            WabwayActionTile(
              icon: Icons.copy_rounded,
              label: 'Duplicate item',
              onTap: () {
                Navigator.pop(ctx);
                onDuplicate();
              },
            ),
          if (onMove != null && days.length > 1)
            WabwayActionTile(
              icon: Icons.swap_vert_rounded,
              label: 'Move to another day',
              onTap: () async {
                Navigator.pop(ctx);
                final otherDays =
                    days.where((d) => d.id != item.dayId).toList();
                if (otherDays.isEmpty || !context.mounted) return;
                final picked = await showModalBottomSheet<String>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _MoveToDaySheet(days: otherDays),
                );
                if (picked != null && context.mounted) onMove(picked);
              },
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

// â”€â”€â”€ Move-to-day picker â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MoveToDaySheet extends StatelessWidget {
  const _MoveToDaySheet({required this.days});
  final List<TripDay> days;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: kColorPaper,
        borderRadius: kRadiusSheet,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          kSpace4, kSpace3, kSpace4,
          kSpace6 + MediaQuery.paddingOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const WabwayDragHandle(),
            const SizedBox(height: kSpace3),
            Text('Move to day', style: kStyleTitle),
            const SizedBox(height: kSpace4),
            DecoratedBox(
              decoration: kCardDecoration(),
              child: Column(
                children: days.asMap().entries.map((e) {
                  final i   = e.key;
                  final day = e.value;
                  return Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: kSpace4, vertical: kSpace2),
                        leading: Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: kColorPrimarySoft,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${day.dayNumber}',
                              style: kStyleCaptionMedium.copyWith(
                                color: kColorPrimaryDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          'Day ${day.dayNumber} Â· ${day.city}',
                          style: kStyleBodyMedium,
                        ),
                        subtitle: Text(fmtDate(day.date),
                            style: kStyleCaption),
                        onTap: () => Navigator.pop(context, day.id),
                      ),
                      if (i < days.length - 1)
                        const Divider(height: 1, indent: kSpace4 + 30 + kSpace3),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

