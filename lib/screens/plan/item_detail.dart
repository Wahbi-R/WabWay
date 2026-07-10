import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/profile_state.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/plan_service.dart';
import '../../data/plan_data.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart' show Spot, fmtCommentTime;
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'add_item_sheet.dart';

// ─── Mobile screen ────────────────────────────────────────────────────────────

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

// ─── Shared content ───────────────────────────────────────────────────────────

class ItemDetailContent extends StatefulWidget {
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
  State<ItemDetailContent> createState() => _ItemDetailContentState();
}

class _ItemDetailContentState extends State<ItemDetailContent> {
  List<ItineraryItemComment> _comments = [];
  bool _commentsLoading = true;
  bool _commentSubmitting = false;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final comments = await PlanService.fetchComments(widget.item.id);
    if (mounted) setState(() { _comments = comments; _commentsLoading = false; });
  }

  Future<void> _submitComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _commentSubmitting) return;
    final authorId = ProfileState.maybeOf(context)?.id;
    if (authorId == null) return;
    setState(() => _commentSubmitting = true);
    try {
      final comment = await PlanService.addComment(
        itemId: widget.item.id,
        authorId: authorId,
        body: body,
      );
      if (mounted) {
        setState(() {
          _comments.add(comment);
          _commentCtrl.clear();
          _commentSubmitting = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _commentSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkedSpot = widget.item.linkedSpotId != null
        ? widget.spots.where((s) => s.id == widget.item.linkedSpotId).firstOrNull
        : null;
    final linkedDocs = widget.item.linkedDocIds
        .map((id) => widget.docs.where((d) => d.id == id).firstOrNull)
        .whereType<TripDocument>()
        .toList();
    final myName = ProfileState.maybeOf(context)?.displayName ?? 'You';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ItemHeader(item: widget.item, day: widget.day),
        Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MetaCard(item: widget.item),

              if (linkedSpot != null) ...[
                const SizedBox(height: kSpace4),
                _SpotSection(spot: linkedSpot),
              ],

              if (linkedDocs.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                _DocsSection(docs: linkedDocs),
              ],

              if (widget.item.notes != null && widget.item.notes!.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                WabwayNotesSection(notes: widget.item.notes!),
              ],

              const SizedBox(height: kSpace4),
              _ActionsSection(
                item: widget.item, spots: widget.spots, docs: widget.docs, days: widget.days,
                onDelete: widget.onDelete, onUpdated: widget.onUpdated,
                onMove: widget.onMove, onDuplicate: widget.onDuplicate,
              ),

              // ── Comments ─────────────────────────────────────────────────────
              const SizedBox(height: kSpace4),
              const Divider(height: 1),
              const SizedBox(height: kSpace4),
              Row(
                children: [
                  Text('Comments', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                  if (_comments.isNotEmpty) ...[
                    const SizedBox(width: kSpace2),
                    WabwayBadge(label: '${_comments.length}', tone: WabwayBadgeTone.neutral),
                  ],
                ],
              ),
              const SizedBox(height: kSpace3),

              if (_commentsLoading)
                const Center(child: WabwayLoadingIndicator())
              else if (_comments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: kSpace3),
                  child: Text('No comments yet. Leave a note for the group.', style: kStyleCaption),
                )
              else
                ..._comments.map((c) => _ItemCommentRow(comment: c)),

              const SizedBox(height: kSpace3),
              _ItemCommentInput(
                controller: _commentCtrl,
                myName: myName,
                loading: _commentSubmitting,
                onSubmit: _submitComment,
              ),
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
                          'Day ${day.dayNumber} · ${fmtDate(day.date)}',
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

// ─── Actions section ──────────────────────────────────────────────────────────

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

// ─── Shared helpers ───────────────────────────────────────────────────────────

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

// ─── Mobile actions sheet ─────────────────────────────────────────────────────

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

// ─── Move-to-day picker ────────────────────────────────────────────────────────

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
                          'Day ${day.dayNumber} · ${day.city}',
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

// ─── Item comment widgets ─────────────────────────────────────────────────────

String _commentAuthorName(BuildContext context, String authorId) {
  final me = ProfileState.maybeOf(context);
  if (me?.id == authorId) return 'You';
  return authorId.length >= 8 ? authorId.substring(0, 8) : authorId;
}

class _ItemCommentRow extends StatelessWidget {
  const _ItemCommentRow({required this.comment});
  final ItineraryItemComment comment;

  @override
  Widget build(BuildContext context) {
    final name = _commentAuthorName(context, comment.authorId);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WabwayAvatar(name: name, size: WabwayAvatarSize.sm),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: kStyleBodySemibold),
                    const Spacer(),
                    Text(fmtCommentTime(comment.createdAt), style: kStyleOverline),
                  ],
                ),
                const SizedBox(height: kSpace1),
                Text(comment.body, style: kStyleBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemCommentInput extends StatelessWidget {
  const _ItemCommentInput({
    required this.controller,
    required this.myName,
    required this.loading,
    required this.onSubmit,
  });
  final TextEditingController controller;
  final String myName;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        WabwayAvatar(name: myName, size: WabwayAvatarSize.sm),
        const SizedBox(width: kSpace3),
        Expanded(
          child: TextField(
            controller: controller,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: kStyleBody,
            decoration: InputDecoration(
              hintText: 'Add a note for the group…',
              hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
              filled: true,
              fillColor: kColorSurfaceSunken,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: kSpace4,
                vertical: kSpace3,
              ),
              border: const OutlineInputBorder(
                borderRadius: kRadiusSm,
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: kRadiusSm,
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: kRadiusSm,
                borderSide: BorderSide(color: kColorPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(width: kSpace2),
        WabwayIconButton(
          icon: loading ? Icons.hourglass_empty_rounded : Icons.send_rounded,
          label: 'Send',
          variant: WabwayIconButtonVariant.solid,
          size: WabwayIconButtonSize.sm,
          onPressed: loading ? null : onSubmit,
        ),
      ],
    );
  }
}
