import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/plan_service.dart';
import '../../data/money_data.dart' show fmtAmount;
import '../../data/accommodation_data.dart' show Accommodation;
import '../../data/plan_data.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart' show Spot, fmtCommentTime;
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import '../../data/connection_data.dart';
import '../shared/attached_docs_section.dart';
import '../shared/connections_section.dart';
import '../../core/async_screen_mixin.dart';
import 'add_item_sheet.dart';
import '../../core/text_utils.dart';

// ─── Mobile screen ────────────────────────────────────────────────────────────

class ItemDetailScreen extends ConsumerWidget {
  const ItemDetailScreen({
    super.key,
    required this.item,
    required this.day,
    this.spots = const [],
    this.docs = const [],
    this.stays = const [],
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
  final List<Accommodation> stays;
  final List<TripDay> days;
  final VoidCallback? onDelete;
  final ValueChanged<ItineraryItem>? onUpdated;
  final ValueChanged<String>? onMove;
  final VoidCallback? onDuplicate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defaultCurrency = ref.read(activeTripProvider)?.homeCurrency ?? '';
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
              stays: stays, days: days, onMove: onMove, onDuplicate: onDuplicate,
              defaultCurrency: defaultCurrency,
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
          stays: stays,
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

class ItemDetailContent extends ConsumerStatefulWidget {
  const ItemDetailContent({
    super.key,
    required this.item,
    required this.day,
    this.spots = const [],
    this.docs = const [],
    this.stays = const [],
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
  final List<Accommodation> stays;
  final List<TripDay> days;
  final VoidCallback? onDelete;
  final ValueChanged<ItineraryItem>? onUpdated;
  final ValueChanged<String>? onMove;
  final VoidCallback? onDuplicate;

  @override
  ConsumerState<ItemDetailContent> createState() => _ItemDetailContentState();
}

class _ItemDetailContentState extends ConsumerState<ItemDetailContent>
    with AsyncScreenMixin {
  List<ItineraryItemComment> _comments = [];
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
    final gen = beginLoad();
    try {
      final comments = await PlanService.fetchComments(widget.item.id);
      commitLoad(gen, () => _comments = comments);
    } catch (_) {
      failLoad(gen);
    }
  }

  Future<void> _submitComment() async {
    final body = _commentCtrl.text.trim();
    if (body.isEmpty || _commentSubmitting) return;
    final authorId = ref.read(profileProvider)?.id;
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
          error = false;
          offline = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _commentSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myName = ref.watch(profileProvider)?.displayName ?? 'You';

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

              const SizedBox(height: kSpace4),
              AttachedDocsSection(
                entityType: EntityType.planItem,
                entityId:   widget.item.id,
                tripId:     ref.watch(activeTripIdProvider),
                entityName: widget.item.title,
                uploadType: DocType.reservation,
                onChanged: (ids) =>
                    widget.onUpdated?.call(widget.item.copyWith(linkedDocIds: ids)),
              ),

              if (widget.item.notes != null && widget.item.notes!.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                WabwayNotesSection(notes: widget.item.notes!),
              ],

              const SizedBox(height: kSpace4),
              _ActionsSection(
                item: widget.item, spots: widget.spots, docs: widget.docs,
                stays: widget.stays, days: widget.days,
                onDelete: widget.onDelete, onUpdated: widget.onUpdated,
                onMove: widget.onMove, onDuplicate: widget.onDuplicate,
              ),

              // ── Connections ───────────────────────────────────────────────────
              Builder(builder: (context) {
                final tripId = ref.watch(activeTripProvider)?.id;
                if (tripId == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: kSpace4),
                    const Divider(height: 1),
                    const SizedBox(height: kSpace4),
                    ConnectionsSection(
                      entityType: EntityType.planItem,
                      entityId: widget.item.id,
                      tripId: tripId,
                      days: widget.days,
                    ),
                  ],
                );
              }),

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

              if (loading)
                const Center(child: WabwayLoadingIndicator())
              else if (error)
                WabwayErrorState(
                  title: "Couldn't load comments",
                  action: TextButton(
                    onPressed: _loadComments,
                    child: const Text('Retry'),
                  ),
                )
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
    final hasCost = item.plannedCost != null && item.plannedCost! > 0;
    final staticRows = <(IconData, String, String?)>[
      if (item.hasTime)         (Icons.schedule_rounded,        'Time',     item.time),
      if (item.city != null)    (Icons.location_city_rounded,   'City',     item.city),
      if (item.location != null)(Icons.place_rounded,            'Location', item.location),
      if (hasCost)              (Icons.account_balance_wallet_rounded,
                                                                 'Est. cost',
                                                                 fmtAmount(item.plannedCost!, item.currency ?? '')),
    ];

    final hasMaps   = item.mapsUrl != null;
    final hasConf   = item.confirmationUrl != null;
    final totalRows = staticRows.length + (hasMaps ? 1 : 0) + (hasConf ? 1 : 0);

    if (totalRows == 0) return const SizedBox.shrink();

    Widget divider() => const Divider(height: kSpace4, thickness: 1, color: kColorBorder);

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
          for (int i = 0; i < staticRows.length; i++) ...[
            if (i > 0) divider(),
            WabwayMetaRow(icon: staticRows[i].$1, label: staticRows[i].$2, value: staticRows[i].$3 ?? ''),
          ],
          if (hasMaps) ...[
            if (staticRows.isNotEmpty) divider(),
            _LinkRow(icon: Icons.map_rounded, label: 'Google Maps', url: item.mapsUrl!),
          ],
          if (hasConf) ...[
            if (staticRows.isNotEmpty || hasMaps) divider(),
            _LinkRow(icon: Icons.confirmation_number_rounded, label: 'Confirmation', url: item.confirmationUrl!),
          ],
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.icon, required this.label, required this.url});
  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Row(
        children: [
          Icon(icon, size: 16, color: kColorInkSoft),
          const SizedBox(width: kSpace2),
          Text(label, style: kStyleCaption),
          const Spacer(),
          Text(
            'Open →',
            style: kStyleBodyMedium.copyWith(color: kColorPrimary, decoration: TextDecoration.underline),
          ),
        ],
      ),
    );
  }
}



// ─── Actions section ──────────────────────────────────────────────────────────

class _ActionsSection extends ConsumerStatefulWidget {
  const _ActionsSection({
    required this.item,
    this.spots = const [],
    this.docs = const [],
    this.stays = const [],
    this.days = const [],
    this.onDelete,
    this.onUpdated,
    this.onMove,
    this.onDuplicate,
  });
  final ItineraryItem item;
  final List<Spot> spots;
  final List<TripDocument> docs;
  final List<Accommodation> stays;
  final List<TripDay> days;
  final VoidCallback? onDelete;
  final ValueChanged<ItineraryItem>? onUpdated;
  final ValueChanged<String>? onMove;
  final VoidCallback? onDuplicate;

  @override
  ConsumerState<_ActionsSection> createState() => _ActionsSectionState();
}

class _ActionsSectionState extends ConsumerState<_ActionsSection> {
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
            if (widget.item.mapsUrl != null)
              WabwayButton(
                label: 'Open Maps',
                icon: Icons.map_rounded,
                size: WabwayButtonSize.sm,
                onPressed: () => _openMaps(context, widget.item.mapsUrl!),
              ),
            WabwayButton(
              label: 'Edit',
              icon: Icons.edit_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _editItem(context),
            ),
            if (widget.onDuplicate != null)
              WabwayButton(
                label: 'Duplicate',
                icon: Icons.copy_rounded,
                variant: WabwayButtonVariant.ghost,
                size: WabwayButtonSize.sm,
                onPressed: widget.onDuplicate,
              ),
            if (widget.onMove != null && widget.days.length > 1)
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
    final updated = await showAddItemSheet(
      context,
      dayId: widget.item.dayId,
      defaultCurrency: ref.read(activeTripProvider)?.homeCurrency ?? '',
      spots: widget.spots,
      docs: widget.docs,
      stays: widget.stays,
      initialItem: widget.item,
    );
    if (updated != null && context.mounted) {
      widget.onUpdated?.call(updated);
      Navigator.maybePop(context);
    }
  }

  Future<void> _moveItem(BuildContext context) async {
    final otherDays = widget.days.where((d) => d.id != widget.item.dayId).toList();
    if (otherDays.isEmpty || !context.mounted) return;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoveToDaySheet(days: otherDays),
    );
    if (picked != null && context.mounted) widget.onMove?.call(picked);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    if (!await showWabwayDeleteConfirm(context, entity: 'plan item', name: widget.item.title)) return;
    widget.onDelete?.call();
    if (context.mounted) Navigator.maybePop(context);
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

Future<void> _openMaps(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else if (context.mounted) {
    showWabwaySnack(context, 'Could not open Maps.');
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
  List<Accommodation> stays = const [],
  List<TripDay> days = const [],
  ValueChanged<String>? onMove,
  VoidCallback? onDuplicate,
  String defaultCurrency = '',
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
                defaultCurrency: defaultCurrency,
                spots: spots,
                docs: docs,
                stays: stays,
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
                          joinNonEmpty(['Day ${day.dayNumber}', day.city]),
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

class _ItemCommentRow extends ConsumerWidget {
  const _ItemCommentRow({required this.comment});
  final ItineraryItemComment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.memberLabel(comment.authorId);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WabwayAvatar(name: ref.memberName(comment.authorId), size: WabwayAvatarSize.sm),
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
