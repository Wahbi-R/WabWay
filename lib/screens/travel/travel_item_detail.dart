import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/plan_service.dart';
import '../../core/supabase/travel_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/trip_provider.dart';
import '../../data/travel_data.dart';
import '../../data/docs_data.dart';
import '../../data/plan_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'add_travel_sheet.dart';
import '../plan/day_picker_sheet.dart';
import '../../data/connection_data.dart';
import '../shared/attached_docs_section.dart';
import '../shared/connections_section.dart';
import '../../core/text_utils.dart';
import '../../data/date_utils.dart' show parseTimeOfDay;
import 'travellers_section.dart';

// ─── Mobile screen ────────────────────────────────────────────────────────────

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

// ─── Shared detail content ────────────────────────────────────────────────────

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

              if (item.travellers.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                TravellersList(travellers: item.travellers),
              ],

              const SizedBox(height: kSpace4),
              Consumer(
                builder: (context, ref, _) => AttachedDocsSection(
                  entityType: EntityType.travel,
                  entityId:   item.id,
                  tripId:     ref.watch(activeTripIdProvider),
                  entityName: item.title,
                  uploadType: switch (item.type) {
                    TravelItemType.flight => DocType.flight,
                    TravelItemType.train  => DocType.train,
                    _                     => DocType.reservation,
                  },
                  onChanged: (ids) => onUpdated?.call(item.withDocIds(ids)),
                ),
              ),

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
              Consumer(
                builder: (context, ref, _) => ConnectionsSection(
                  entityType: EntityType.travel,
                  entityId:   item.id,
                  tripId:     ref.watch(activeTripIdProvider),
                  days:       days,
                ),
              ),

              const SizedBox(height: kSpace4),
              _ActionsSection(item: item, docs: docs, days: days, onDelete: onDelete, onUpdated: onUpdated),
              const SizedBox(height: kSpace8),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Header band ──────────────────────────────────────────────────────────────

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
                      '${item.location!} → ${item.destination!}',
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

// ─── Metadata card ────────────────────────────────────────────────────────────

class _MetaCard extends StatelessWidget {
  const _MetaCard({required this.item});
  final TravelItem item;

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[];

    if (item.boardingTime != null) {
      rows.add((Icons.timer_rounded, 'Boards', item.boardingTime!));
    }
    if (item.time != null) {
      final timeLabel = item.type == TravelItemType.car ? 'Pick-up' : 'Departs';
      rows.add((Icons.schedule_rounded, timeLabel, item.time!));
    }
    if (item.endTime != null) {
      final endLabel = item.type == TravelItemType.car ? 'Return' : 'Arrives';
      rows.add((Icons.schedule_rounded, endLabel, item.endTime!));
    }
    if (item.isTransit) {
      if (item.location != null) rows.add((Icons.flight_takeoff_rounded, 'From', item.location!));
      if (item.departureTerminal != null)
        rows.add((Icons.sensors_rounded, 'Dep. terminal', item.departureTerminal!));
      if (item.gate != null)
        rows.add((Icons.door_sliding_rounded, 'Gate', item.gate!));
      if (item.destination != null) rows.add((Icons.flight_land_rounded, 'To', item.destination!));
      if (item.arrivalTerminal != null)
        rows.add((Icons.sensors_rounded, 'Arr. terminal', item.arrivalTerminal!));
    } else {
      if (item.location != null) rows.add((Icons.place_rounded, 'Location', item.location!));
      if (item.address != null) rows.add((Icons.pin_drop_rounded, 'Address', item.address!));
    }
    if (item.seat != null) {
      rows.add((Icons.airline_seat_recline_extra_rounded, 'Seat', item.seat!));
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
                  rows[i].$2 == 'Departs'      ||
                  rows[i].$2 == 'Arrives'      ||
                  rows[i].$2 == 'Boards'       ||
                  rows[i].$2 == 'Pick-up'      ||
                  rows[i].$2 == 'Return'       ||
                  rows[i].$2 == 'Time'         ||
                  rows[i].$2 == 'Check-in'     ||
                  rows[i].$2 == 'Check-out',
              copyable: rows[i].$2 == 'Confirmation' ||
                  rows[i].$2 == 'Address'      ||
                  rows[i].$2 == 'Seat',
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
    this.copyable = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool isMono;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final row = Row(
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
        if (copyable) ...[
          const SizedBox(width: kSpace2),
          const Icon(Icons.copy_rounded, size: 12, color: kColorInkSoft),
        ],
      ],
    );
    if (!copyable) return row;
    return GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: value));
        if (context.mounted) {
          showWabwaySnack(context, 'Copied', duration: Duration(seconds: 2));
        }
      },
      child: row,
    );
  }
}



// ─── Linked plan item ─────────────────────────────────────────────────────────

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
          onTap: () => showWabwaySnack(context, 'Go to itinerary: ${item.title}', duration: const Duration(seconds: 2)),
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
                      'Day ${day.dayNumber} · ${fmtDate(day.date)}',
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
          onTap: () => showWabwaySnack(context, 'Go to Day ${day.dayNumber}', duration: const Duration(seconds: 2)),
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
                      '${fmtDate(day.date)} · ${day.city}',
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

// ─── Notes section ────────────────────────────────────────────────────────────

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

// ─── Actions section ──────────────────────────────────────────────────────────

class _ActionsSection extends ConsumerStatefulWidget {
  const _ActionsSection({
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
  ConsumerState<_ActionsSection> createState() => _ActionsSectionState();
}

class _ActionsSectionState extends ConsumerState<_ActionsSection> {
  bool _itineraryLoading = false;

  ItineraryItemType get _planItemType => switch (widget.item.type) {
    TravelItemType.flight => ItineraryItemType.travel,
    TravelItemType.train  => ItineraryItemType.transport,
    TravelItemType.bus    => ItineraryItemType.transport,
    TravelItemType.ferry  => ItineraryItemType.transport,
    TravelItemType.car    => ItineraryItemType.transport,
    _                     => ItineraryItemType.other,
  };

  Future<void> _addToItinerary() async {
    if (_itineraryLoading) return;
    if (widget.days.isEmpty) {
      showWabwaySnack(context, 'Set your trip dates in Trip settings to start planning days.');
      return;
    }

    final suggestedDay = widget.item.date != null
        ? widget.days.where((d) => d.date == widget.item.date).firstOrNull
        : null;
    final suggestedTime = parseTimeOfDay(widget.item.time);

    final result = await showDayPickerSheet(
      context,
      days: widget.days,
      suggestedDayId: suggestedDay?.id,
      suggestedTime: suggestedTime,
    );
    if (result == null || !mounted) return;

    final (dayId, timeOfDay) = result;
    final day = widget.days.where((d) => d.id == dayId).firstOrNull;
    if (day == null) return;

    final timeStr = timeOfDay != null
        ? '${timeOfDay.hour.toString().padLeft(2, '0')}:${timeOfDay.minute.toString().padLeft(2, '0')}'
        : widget.item.time;

    final tripId = ref.read(activeTripIdProvider);
    final userId = supabase.auth.currentUser?.id ?? '';

    setState(() => _itineraryLoading = true);
    try {
      final planItem = await PlanService.createItem(
        tripId:    tripId,
        dayId:     dayId,
        title:     widget.item.title,
        type:      _planItemType,
        createdBy: userId,
        time:      timeStr,
        location:  widget.item.location ?? widget.item.destination,
        sortOrder: day.items.length,
      );
      await TravelService.linkToDay(
        widget.item.id,
        dayId: dayId,
        itineraryItemId: planItem.id,
      );
      if (!mounted) return;
      final updated = widget.item.withPlanLink(dayId: dayId, itineraryItemId: planItem.id);
      widget.onUpdated?.call(updated);
      showWabwaySnack(context, 'Added to ${joinNonEmpty(['Day ${day.dayNumber}', day.city])}');
    } catch (e) {
      if (!mounted) return;
      showWabwaySnack(context, 'Could not add to plan: $e', error: true);
    } finally {
      if (mounted) setState(() => _itineraryLoading = false);
    }
  }

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
            if (widget.item.url != null)
              WabwayButton(
                label: 'Open booking',
                icon: Icons.open_in_new_rounded,
                size: WabwayButtonSize.sm,
                onPressed: () async {
                  final uri = Uri.tryParse(widget.item.url!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            WabwayButton(
              label: _itineraryLoading ? 'Adding…' : 'Add to itinerary',
              icon: Icons.event_note_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: _itineraryLoading ? null : _addToItinerary,
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
              variant: WabwayButtonVariant.dangerOutline,
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
      docs: widget.docs,
      initialItem: widget.item,
    );
    if (updated != null && context.mounted) {
      widget.onUpdated?.call(updated);
      Navigator.maybePop(context);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (!await showWabwayDeleteConfirm(context, entity: 'travel item', name: widget.item.title)) return;
    widget.onDelete?.call();
    if (context.mounted) Navigator.maybePop(context);
  }
}

// ─── Mobile actions sheet ─────────────────────────────────────────────────────

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

// ─── Type badge ───────────────────────────────────────────────────────────────

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

// ─── Status badge ─────────────────────────────────────────────────────────────

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

