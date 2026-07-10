import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/supabase/doc_service.dart';
import '../../data/travel_data.dart';
import '../../data/docs_data.dart';
import '../../data/plan_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'add_travel_sheet.dart';

// â”€â”€â”€ Mobile screen â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class TravelItemDetailScreen extends StatelessWidget {
  const TravelItemDetailScreen({
    super.key,
    required this.item,
    this.docs = const [],
    this.days = const [],
    this.onDelete,
    this.onUpdated,
  });

  final TravelItem item;
  final List<TripDocument> docs;
  final List<TripDay> days;
  final VoidCallback? onDelete;
  final ValueChanged<TravelItem>? onUpdated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text(item.title, style: kStyleTitle, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            color: kColorInkSoft,
            onPressed: () => _showActionsSheet(context, item, docs, onDelete, onUpdated),
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        child: TravelItemDetailContent(
          item: item,
          docs: docs,
          days: days,
          onDelete: onDelete,
          onUpdated: onUpdated,
        ),
      ),
    );
  }
}

// â”€â”€â”€ Shared detail content â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class TravelItemDetailContent extends StatelessWidget {
  const TravelItemDetailContent({
    super.key,
    required this.item,
    this.docs = const [],
    this.days = const [],
    this.onDelete,
    this.onUpdated,
  });

  final TravelItem item;
  final List<TripDocument> docs;
  final List<TripDay> days;
  final VoidCallback? onDelete;
  final ValueChanged<TravelItem>? onUpdated;

  @override
  Widget build(BuildContext context) {
    final linkedDocs = item.linkedDocIds
        .map((id) => docs.where((d) => d.id == id).firstOrNull)
        .whereType<TripDocument>()
        .toList();

    ItineraryItem? linkedPlanItem;
    TripDay? linkedDay;
    if (item.linkedItineraryItemId != null) {
      linkedPlanItem = itemById(days, item.linkedItineraryItemId!);
      if (linkedPlanItem != null) {
        linkedDay = dayForItem(days, item.linkedItineraryItemId!);
      }
    } else if (item.linkedDayId != null) {
      linkedDay = days.where((d) => d.id == item.linkedDayId).firstOrNull;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TravelDetailHeader(item: item),
        Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaCard(item: item),

              if (linkedDocs.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                _DocsSection(docs: linkedDocs),
              ],

              if (linkedPlanItem != null && linkedDay != null) ...[
                const SizedBox(height: kSpace4),
                _PlanItemSection(item: linkedPlanItem, day: linkedDay),
              ] else if (linkedDay != null) ...[
                const SizedBox(height: kSpace4),
                _PlanDaySection(day: linkedDay),
              ],

              if (item.notes != null && item.notes!.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                _NotesSection(notes: item.notes!),
              ],

              const SizedBox(height: kSpace4),
              _ActionsSection(item: item, docs: docs, onDelete: onDelete, onUpdated: onUpdated),
              const SizedBox(height: kSpace8),
            ],
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€ Header band â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TravelDetailHeader extends StatelessWidget {
  const _TravelDetailHeader({required this.item});
  final TravelItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.type.color;
    final softColor = item.type.softColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace5, kSpace4, kSpace5),
      decoration: BoxDecoration(color: softColor),
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
                  color: color.withValues(alpha: 0.14),
                  borderRadius: kRadiusLg,
                ),
                child: Icon(item.type.icon, size: 26, color: color),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TypeBadge(type: item.type),
                        const SizedBox(width: kSpace2),
                        _StatusBadge(status: item.status),
                      ],
                    ),
                    if (item.hasDate) ...[
                      const SizedBox(height: kSpace1),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 11, color: color.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            item.hasEndDate
                                ? fmtTravelDateRange(item.date!, item.endDate!)
                                : fmtTravelDate(item.date!),
                            style: GoogleFonts.ibmPlexMono(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: color.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (item.time != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color,
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
          if (item.location != null) ...[
            const SizedBox(height: kSpace1),
            if (item.isTransit && item.destination != null)
              Row(
                children: [
                  Icon(Icons.place_rounded,
                      size: 13, color: color.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${item.location!} â†’ ${item.destination!}',
                      style: kStyleCaption.copyWith(
                          color: color.withValues(alpha: 0.8)),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(Icons.place_rounded,
                      size: 13, color: color.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      item.location!,
                      style: kStyleCaption.copyWith(
                          color: color.withValues(alpha: 0.8)),
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
  final TravelItem item;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[];

    if (item.time != null) {
      final timeLabel = item.type == TravelItemType.hotel
          ? 'Check-in'
          : item.type == TravelItemType.reservation
              ? 'Time'
              : 'Departs';
      rows.add((Icons.schedule_rounded, timeLabel, item.time!));
    }
    if (item.endTime != null) {
      final endLabel = item.type == TravelItemType.hotel ? 'Check-out' : 'Arrives';
      rows.add((Icons.schedule_rounded, endLabel, item.endTime!));
    }
    if (item.isTransit) {
      if (item.location != null) rows.add((Icons.flight_takeoff_rounded, 'From', item.location!));
      if (item.destination != null) rows.add((Icons.flight_land_rounded, 'To', item.destination!));
    } else {
      if (item.location != null) rows.add((Icons.place_rounded, 'Location', item.location!));
      if (item.address != null) rows.add((Icons.pin_drop_rounded, 'Address', item.address!));
    }
    if (item.confirmationNumber != null) {
      rows.add((Icons.confirmation_number_rounded, 'Confirmation', item.confirmationNumber!));
    }

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
            if (i > 0)
              const Divider(height: kSpace4, thickness: 1, color: kColorBorder),
            _MetaRow(
              icon: rows[i].$1,
              label: rows[i].$2,
              value: rows[i].$3,
              isMono: rows[i].$2 == 'Confirmation' ||
                  rows[i].$2 == 'Departs' ||
                  rows[i].$2 == 'Arrives' ||
                  rows[i].$2 == 'Time' ||
                  rows[i].$2 == 'Check-in' ||
                  rows[i].$2 == 'Check-out',
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isMono = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: kColorInkSoft),
        const SizedBox(width: kSpace2),
        Text(label, style: kStyleCaption),
        const Spacer(),
        const SizedBox(width: kSpace3),
        Flexible(
          child: Text(
            value,
            style: isMono
                ? GoogleFonts.ibmPlexMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kColorInk,
                  )
                : kStyleBodyMedium,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€ Linked documents â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

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
        ...docs.map((d) => _DocTile(doc: d)),
      ],
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: WabwayCard(
        hoverable: true,
        padding: const EdgeInsets.all(kSpace3),
        onTap: () => _openDoc(context, doc),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: doc.type.softColor,
                borderRadius: kRadiusMd,
              ),
              child: Icon(doc.type.icon, size: 18, color: doc.type.color),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(doc.title, style: kStyleBodyMedium),
                  Text(
                    '${doc.type.label} Â· ${doc.extUpper}',
                    style: kStyleCaption.copyWith(color: kColorInkSoft, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, size: 16, color: kColorInkSoft),
          ],
        ),
      ),
    );
  }

}

// â”€â”€â”€ Linked plan item â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _PlanItemSection extends StatelessWidget {
  const _PlanItemSection({required this.item, required this.day});
  final ItineraryItem item;
  final TripDay day;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Linked itinerary item',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        WabwayCard(
          hoverable: true,
          padding: const EdgeInsets.all(kSpace3),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Go to itinerary: ${item.title}',
                style: kStyleBody.copyWith(color: Colors.white)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          )),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: item.type.softColor,
                  borderRadius: kRadiusMd,
                ),
                child: Icon(item.type.icon, size: 18, color: item.type.color),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: kStyleBodyMedium),
                    Text(
                      'Day ${day.dayNumber} Â· ${fmtDate(day.date)}',
                      style: kStyleCaption.copyWith(
                          color: kColorInkSoft, fontSize: 12),
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

class _PlanDaySection extends StatelessWidget {
  const _PlanDaySection({required this.day});
  final TripDay day;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Linked itinerary day',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        WabwayCard(
          hoverable: true,
          padding: const EdgeInsets.all(kSpace3),
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Go to Day ${day.dayNumber}',
                style: kStyleBody.copyWith(color: Colors.white)),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          )),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: kColorPrimarySoft,
                  borderRadius: kRadiusMd,
                ),
                child: Center(
                  child: Text(
                    '${day.dayNumber}',
                    style: kStyleBodySemibold.copyWith(color: kColorPrimary),
                  ),
                ),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day ${day.dayNumber}', style: kStyleBodyMedium),
                    Text(
                      '${fmtDate(day.date)} Â· ${day.city}',
                      style: kStyleCaption.copyWith(
                          color: kColorInkSoft, fontSize: 12),
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

// â”€â”€â”€ Notes section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _NotesSection extends StatelessWidget {
  const _NotesSection({required this.notes});
  final String notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notes', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(kSpace3),
          decoration: const BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
          ),
          child: Text(notes, style: kStyleBody.copyWith(height: 1.6)),
        ),
      ],
    );
  }
}

// â”€â”€â”€ Actions section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({
    required this.item,
    this.docs = const [],
    this.onDelete,
    this.onUpdated,
  });
  final TravelItem item;
  final List<TripDocument> docs;
  final VoidCallback? onDelete;
  final ValueChanged<TravelItem>? onUpdated;

  @override
  Widget build(BuildContext context) {
    final linkedDocs = item.linkedDocIds
        .map((id) => docs.where((d) => d.id == id).firstOrNull)
        .whereType<TripDocument>()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace3),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: [
            if (linkedDocs.isNotEmpty)
              WabwayButton(
                label: 'Open document',
                icon: Icons.open_in_new_rounded,
                size: WabwayButtonSize.sm,
                onPressed: () => _openDoc(context, linkedDocs.first),
              ),
            WabwayButton(
              label: 'Attach document',
              icon: Icons.attach_file_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _snack(context, 'Attach a document to this item'),
            ),
            WabwayButton(
              label: 'Add to itinerary',
              icon: Icons.event_note_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _snack(context, 'Link to an itinerary item'),
            ),
            WabwayButton(
              label: 'Edit',
              icon: Icons.edit_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _editItem(context),
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
    final updated = await showAddTravelSheet(
      context,
      docs: docs,
      initialItem: item,
    );
    if (updated != null && context.mounted) {
      onUpdated?.call(updated);
      Navigator.maybePop(context);
    }
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
        title: Text('Delete travel item?', style: kStyleBodySemibold),
        content: Text(
          'Remove "${item.title}" from your travel list?',
          style: kStyleBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: kStyleBody.copyWith(color: kColorInkSoft)),
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
  TravelItem item,
  List<TripDocument> docs,
  VoidCallback? onDelete,
  ValueChanged<TravelItem>? onUpdated,
) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kColorPaper,
    shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: kSpace3, bottom: kSpace1),
            child: Container(
              width: 40,
              height: 4,
              decoration: const BoxDecoration(
                  color: kColorBorder, borderRadius: kRadiusPill),
            ),
          ),
          if (item.linkedDocIds.isNotEmpty)
            _SheetTile(
              icon: Icons.open_in_new_rounded,
              label: 'Open document',
              onTap: () {
                Navigator.pop(ctx);
                final linkedDoc = docs
                    .where((d) => item.linkedDocIds.contains(d.id))
                    .firstOrNull;
                if (linkedDoc != null) _openDoc(context, linkedDoc);
              },
            ),
          _SheetTile(
            icon: Icons.attach_file_rounded,
            label: 'Attach document',
            onTap: () => Navigator.pop(ctx),
          ),
          _SheetTile(
            icon: Icons.event_note_rounded,
            label: 'Add to itinerary',
            onTap: () => Navigator.pop(ctx),
          ),
          _SheetTile(
            icon: Icons.edit_rounded,
            label: 'Edit',
            onTap: () async {
              Navigator.pop(ctx);
              final updated = await showAddTravelSheet(
                context,
                docs: docs,
                initialItem: item,
              );
              if (updated != null && context.mounted) {
                onUpdated?.call(updated);
                Navigator.maybePop(context);
              }
            },
          ),
          _SheetTile(
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

class _SheetTile extends StatelessWidget {
  const _SheetTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? kColorInk;
    return ListTile(
      leading: Icon(icon, color: c, size: 20),
      title: Text(label, style: kStyleBodyMedium.copyWith(color: c)),
      onTap: onTap,
    );
  }
}

// â”€â”€â”€ Type badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final TravelItemType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: kRadiusPill,
        border: Border.all(color: type.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: type.color),
          const SizedBox(width: 5),
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

// â”€â”€â”€ Status badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TravelBookingStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: status.softColor,
        borderRadius: kRadiusPill,
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: kStyleCaption.copyWith(
              color: status.color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
