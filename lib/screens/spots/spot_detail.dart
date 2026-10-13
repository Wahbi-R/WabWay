import 'package:cached_network_image_ce/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/image_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/plan_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../data/accommodation_data.dart';
import '../../data/docs_data.dart';
import '../../data/plan_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import '../plan/day_picker_sheet.dart';
import '../../data/connection_data.dart';
import '../shared/connections_section.dart';
import 'add_spot_sheet.dart';
import 'spot_vote_chip.dart';
import '../../data/date_utils.dart';
import '../../core/text_utils.dart';

// ─── Full-screen route for mobile ─────────────────────────────────────────────

class SpotDetailScreen extends ConsumerStatefulWidget {
  const SpotDetailScreen({
    super.key,
    required this.spot,
    this.myVote,
    this.onVote,
    this.canDelete = false,
    this.onDelete,
    this.onEdit,
    this.onShowOnMap,
    this.docs = const [],
    this.linkedStay,
    this.onOpenStay,
  });

  final Spot spot;
  final VoteType? myVote;
  final ValueChanged<VoteType?>? onVote;
  final bool canDelete;
  final VoidCallback? onDelete;
  final ValueChanged<Spot>? onEdit;
  final VoidCallback? onShowOnMap;
  final List<TripDocument> docs;
  final Accommodation? linkedStay;
  final VoidCallback? onOpenStay;

  @override
  ConsumerState<SpotDetailScreen> createState() => _SpotDetailScreenState();
}

class _SpotDetailScreenState extends ConsumerState<SpotDetailScreen> {
  // Local copy so status changes / edits redraw this pushed route (the
  // parent list is updated through widget.onEdit as well).
  late Spot spot = widget.spot;

  void _updated(Spot s) {
    setState(() => spot = s);
    widget.onEdit?.call(s);
  }

  @override
  Widget build(BuildContext context) {
    final onEdit = widget.onEdit == null ? null : _updated;
    final canDelete = widget.canDelete;
    final onDelete = widget.onDelete;
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          color: kColorInkSoft,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(spot.name, style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            color: kColorInkSoft,
            onPressed: () => _openLink(context, spot.mapsUrl ?? spot.name),
          ),
          if (onEdit != null && canDelete)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              color: kColorInkSoft,
              onPressed: () async {
                final tripId = ref.read(activeTripIdProvider);
                final userId = supabase.auth.currentUser?.id ?? '';
                final updated = await showEditSpotSheet(
                  context,
                  tripId: tripId,
                  userId: userId,
                  spot: spot,
                );
                if (updated != null) onEdit(updated);
              },
            ),
          if (canDelete && onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: kColorDanger,
              onPressed: () => _confirmDelete(context, spot.name, onDelete),
            ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: kSpace12 + MediaQuery.paddingOf(context).bottom),
        child: SpotDetailContent(
          spot: spot,
          myVote: widget.myVote,
          onVote: widget.onVote,
          // Lifecycle actions need onEdit; edit/delete icons stay in the
          // app bar (canDelete not passed, so the content doesn't repeat them).
          onEdit: onEdit,
          docs: widget.docs,
          linkedStay: widget.linkedStay,
          onOpenStay: widget.onOpenStay,
          onShowOnMap: widget.onShowOnMap,
        ),
      ),
    );
  }
}

// ─── Shared detail content (mobile screen + desktop panel) ────────────────────

class SpotDetailContent extends ConsumerStatefulWidget {
  const SpotDetailContent({
    super.key,
    required this.spot,
    this.myVote,
    this.onVote,
    this.showHeader = false,
    this.canDelete = false,
    this.onDelete,
    this.onEdit,
    this.onShowOnMap,
    this.docs = const [],
    this.linkedStay,
    this.onOpenStay,
  });

  final Spot spot;
  final VoteType? myVote;
  final ValueChanged<VoteType?>? onVote;
  final bool showHeader;
  final bool canDelete;
  final VoidCallback? onDelete;
  final ValueChanged<Spot>? onEdit;
  final VoidCallback? onShowOnMap;
  final List<TripDocument> docs;
  final Accommodation? linkedStay;
  final VoidCallback? onOpenStay;

  @override
  ConsumerState<SpotDetailContent> createState() => _SpotDetailContentState();
}

class _SpotDetailContentState extends ConsumerState<SpotDetailContent> {
  late VoteType? _myVote;
  final _commentCtrl = TextEditingController();
  final List<SpotComment> _extraComments = [];
  bool _commentLoading = false;

  @override
  void initState() {
    super.initState();
    _myVote = widget.myVote;
  }

  @override
  void didUpdateWidget(SpotDetailContent old) {
    super.didUpdateWidget(old);
    if (old.spot.id != widget.spot.id) {
      _myVote = widget.myVote;
      _extraComments.clear();
    } else {
      // Remove optimistic comments that the server reload now includes.
      final serverIds = widget.spot.comments.map((c) => c.id).toSet();
      _extraComments.removeWhere((c) => serverIds.contains(c.id));
    }
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _handleVote(VoteType? type) {
    setState(() => _myVote = type);
    widget.onVote?.call(type);
  }

  Future<void> _setStatus(SpotStatus status) async {
    try {
      final updated = await SpotService.updateStatus(widget.spot.id, status);
      if (mounted) widget.onEdit?.call(updated);
    } catch (e) {
      if (mounted) showWabwaySnack(context, 'Could not update the spot.', error: true);
    }
  }


  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty || _commentLoading) return;
    final authorId = supabase.auth.currentUser?.id;
    if (authorId == null) return;

    setState(() => _commentLoading = true);
    try {
      final comment = await SpotService.addComment(
        spotId: widget.spot.id,
        authorId: authorId,
        body: text,
        vote: _myVote,
      );
      if (mounted) {
        setState(() {
          _extraComments.add(comment);
          _commentCtrl.clear();
          _commentLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _commentLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allComments = [...widget.spot.comments, ..._extraComments];
    final myName = ref.watch(profileProvider)?.displayName ?? 'You';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PhotoHeader(category: widget.spot.category, imageUrl: widget.spot.imageUrl),
        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title + badge + optional delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(widget.spot.name, style: kStyleHeadingSm),
                  ),
                  const SizedBox(width: kSpace2),
                  WabwayBadge(
                    label: widget.spot.status.label,
                    tone: widget.spot.status.tone,
                  ),
                  if (widget.onEdit != null && widget.canDelete) ...[
                    const SizedBox(width: kSpace2),
                    GestureDetector(
                      onTap: () async {
                        final tripId = ref.read(activeTripIdProvider);
                        final userId = supabase.auth.currentUser?.id ?? '';
                        final updated = await showEditSpotSheet(
                          context,
                          tripId: tripId,
                          userId: userId,
                          spot: widget.spot,
                        );
                        if (updated != null) widget.onEdit!(updated);
                      },
                      child: const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: kColorInkSoft,
                      ),
                    ),
                  ],
                  if (widget.canDelete && widget.onDelete != null) ...[
                    const SizedBox(width: kSpace2),
                    GestureDetector(
                      onTap: () => _confirmDelete(context, widget.spot.name, widget.onDelete!),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: kColorDanger,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: kSpace2),

              // ── City / area / category
              Row(
                children: [
                  const Icon(Icons.place_rounded,
                      size: 14, color: kColorInkSoft),
                  const SizedBox(width: 4),
                  Text(
                    joinNonEmpty([widget.spot.city, widget.spot.area], ', '),
                    style: kStyleCaptionMedium,
                  ),
                  const SizedBox(width: kSpace2),
                  WabwayTag(label: widget.spot.category.label),
                  if (widget.spot.isMapReady) ...[
                    const SizedBox(width: kSpace2),
                    const Icon(Icons.my_location_rounded,
                        size: 13, color: kColorSuccess),
                  ],
                ],
              ),

              // ── Address line (if from dataset) — tap to copy
              if (widget.spot.address != null) ...[
                const SizedBox(height: kSpace1),
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: widget.spot.address!));
                    if (context.mounted) {
                      showWabwaySnack(context, 'Address copied', duration: Duration(seconds: 2));
                    }
                  },
                  child: Row(
                    children: [
                      const SizedBox(width: 18),
                      Expanded(
                        child: Text(
                          widget.spot.address!,
                          style: kStyleCaption.copyWith(color: kColorInkSoft),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: kSpace2),
                      const Icon(Icons.copy_rounded, size: 12, color: kColorInkSoft),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: kSpace4),
              const Divider(height: 1),
              const SizedBox(height: kSpace4),

              // ── Links
              if ((widget.spot.mapsUrl?.isNotEmpty ?? false) ||
                  (widget.spot.sourceUrl?.isNotEmpty ?? false) ||
                  (widget.onShowOnMap != null && widget.spot.isMapReady)) ...[
                Text('Links',
                    style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                const SizedBox(height: kSpace2),
                Wrap(
                  spacing: kSpace2,
                  runSpacing: kSpace2,
                  children: [
                    if (widget.onShowOnMap != null && widget.spot.isMapReady)
                      WabwayButton(
                        label: 'Show on map',
                        icon: Icons.location_on_rounded,
                        variant: WabwayButtonVariant.ghost,
                        size: WabwayButtonSize.sm,
                        onPressed: widget.onShowOnMap,
                      ),
                    if (widget.spot.mapsUrl?.isNotEmpty ?? false)
                      WabwayButton(
                        label: 'Open in Maps app',
                        icon: Icons.map_rounded,
                        variant: WabwayButtonVariant.ghost,
                        size: WabwayButtonSize.sm,
                        onPressed: () =>
                            _openLink(context, widget.spot.mapsUrl!),
                      ),
                    if (widget.spot.sourceUrl?.isNotEmpty ?? false)
                      WabwayButton(
                        label: 'View source',
                        icon: Icons.link_rounded,
                        variant: WabwayButtonVariant.ghost,
                        size: WabwayButtonSize.sm,
                        onPressed: () =>
                            _openLink(context, widget.spot.sourceUrl!),
                      ),
                  ],
                ),
                const SizedBox(height: kSpace4),
                const Divider(height: 1),
                const SizedBox(height: kSpace4),
              ],

              // ── Linked stay
              if (widget.linkedStay != null) ...[
                _LinkedStayCard(
                  stay: widget.linkedStay!,
                  onTap: widget.onOpenStay,
                ),
                const SizedBox(height: kSpace4),
                const Divider(height: 1),
                const SizedBox(height: kSpace4),
              ],

              // ── Linked documents
              Builder(builder: (context) {
                final linked = widget.docs.where((d) => d.links.any(
                    (l) => l.type == DocLinkedType.spot && l.linkedId == widget.spot.id)).toList();
                if (linked.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Documents', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                    const SizedBox(height: kSpace2),
                    ...linked.map((doc) => Padding(
                      padding: const EdgeInsets.only(bottom: kSpace2),
                      child: _LinkedDocTile(doc: doc),
                    )),
                    const SizedBox(height: kSpace4),
                    const Divider(height: 1),
                    const SizedBox(height: kSpace4),
                  ],
                );
              }),

              // ── Notes
              if (widget.spot.notes != null) ...[
                Text('Notes',
                    style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                const SizedBox(height: kSpace2),
                Text(widget.spot.notes!, style: kStyleBody),
                const SizedBox(height: kSpace4),
                const Divider(height: 1),
                const SizedBox(height: kSpace4),
              ],

              // ── Vote
              Text('Your vote',
                  style: kStyleCaptionMedium.copyWith(color: kColorInk)),
              const SizedBox(height: kSpace2),
              SpotVoteChipGroup(
                selected: _myVote,
                onChanged: _handleVote,
              ),

              if (widget.spot.votes.total > 0) ...[
                const SizedBox(height: kSpace4),
                Text(
                  'Group votes',
                  style: kStyleCaptionMedium.copyWith(color: kColorInk),
                ),
                const SizedBox(height: kSpace3),
                _GroupVotesSummary(votes: widget.spot.votes),
              ],

              // ── Add to Plan
              const SizedBox(height: kSpace4),
              const Divider(height: 1),
              const SizedBox(height: kSpace4),
              _AddToPlanButton(
                spot: widget.spot,
                // Planning a spot moves it to Planned (never backwards).
                onPlanned: widget.onEdit == null ||
                        widget.spot.status.stage == SpotStage.planned ||
                        widget.spot.status.stage == SpotStage.visited
                    ? null
                    : () => _setStatus(SpotStatus.planned),
              ),

              // ── Lifecycle: Idea → Confirmed → Planned → Visited
              if (widget.onEdit != null) ...[
                const SizedBox(height: kSpace4),
                const Divider(height: 1),
                const SizedBox(height: kSpace4),
                _SpotLifecycle(
                  status: widget.spot.status,
                  onSetStatus: _setStatus,
                ),
              ],

              const SizedBox(height: kSpace4),
              const Divider(height: 1),
              const SizedBox(height: kSpace4),

              // ── Connections
              ConnectionsSection(
                entityType: EntityType.spot,
                entityId:   widget.spot.id,
                tripId:     ref.watch(activeTripIdProvider),
              ),

              const SizedBox(height: kSpace4),
              const Divider(height: 1),
              const SizedBox(height: kSpace4),

              // ── Comments
              Row(
                children: [
                  Text(
                    'Comments',
                    style: kStyleCaptionMedium.copyWith(color: kColorInk),
                  ),
                  if (allComments.isNotEmpty) ...[
                    const SizedBox(width: kSpace2),
                    WabwayBadge(
                      label: '${allComments.length}',
                      tone: WabwayBadgeTone.neutral,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: kSpace3),

              if (allComments.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: kSpace4),
                  child: Text(
                    'No comments yet. Be the first.',
                    style: kStyleCaption,
                  ),
                ),

              ...allComments.map((c) => _CommentRow(comment: c)),

              const SizedBox(height: kSpace3),
              _CommentInput(
                controller: _commentCtrl,
                myName: myName,
                loading: _commentLoading,
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

// ─── Add to Plan button ────────────────────────────────────────────────────────

class _AddToPlanButton extends ConsumerStatefulWidget {
  const _AddToPlanButton({required this.spot, this.onPlanned});
  final Spot spot;
  final VoidCallback? onPlanned;

  @override
  ConsumerState<_AddToPlanButton> createState() => _AddToPlanButtonState();
}

class _AddToPlanButtonState extends ConsumerState<_AddToPlanButton> {
  bool _loading = false;

  /// The day this spot is already planned on (via linkedSpotId), if any.
  TripDay? _plannedDay;

  ItineraryItemType get _itemType => switch (widget.spot.category) {
    SpotCategory.food      => ItineraryItemType.food,
    SpotCategory.nightlife => ItineraryItemType.activity,
    _                      => ItineraryItemType.spot,
  };

  @override
  void initState() {
    super.initState();
    _checkPlanned();
  }

  @override
  void didUpdateWidget(covariant _AddToPlanButton old) {
    super.didUpdateWidget(old);
    if (old.spot.id != widget.spot.id) {
      _plannedDay = null;
      _checkPlanned();
    }
  }

  TripDay? _dayWithSpot(List<TripDay> days) => days
      .where((d) => d.items.any((i) => i.linkedSpotId == widget.spot.id))
      .firstOrNull;

  Future<void> _checkPlanned() async {
    final tripId = ref.read(activeTripIdProvider);
    if (tripId.isEmpty) return;
    try {
      final days = await PlanService.loadAll(tripId);
      if (mounted) setState(() => _plannedDay = _dayWithSpot(days));
    } catch (_) {}
  }

  /// Loads the plan; if the trip has dates but no days yet, creates them
  /// (same routine as Plan → "Add all trip days") instead of dead-ending.
  Future<List<TripDay>> _loadOrCreateDays(String tripId, String userId) async {
    final days = await PlanService.loadAll(tripId);
    if (days.isNotEmpty) return days;
    final trip = ref.read(activeTripProvider);
    final created = await PlanService.ensureTripDays(
      tripId: tripId, start: trip?.startDate, end: trip?.endDate,
      createdBy: userId, city: trip?.destination,
    );
    return created;
  }

  Future<void> _tap() async {
    if (_loading) return;
    final tripId = ref.read(activeTripIdProvider);
    final userId = supabase.auth.currentUser?.id ?? '';

    setState(() => _loading = true);
    List<TripDay> days;
    try {
      days = await _loadOrCreateDays(tripId, userId);
    } catch (_) {
      days = [];
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;

    if (days.isEmpty) {
      showWabwaySnack(context, 'Set your trip dates in Trip settings to start planning days.');
      return;
    }

    final result = await showDayPickerSheet(context, days: days);
    if (result == null || !mounted) return;

    final (dayId, timeOfDay) = result;
    final day = days.where((d) => d.id == dayId).firstOrNull;
    if (day == null) return;

    final timeStr = timeOfDay != null ? fmtTimeOfDay(timeOfDay.hour, timeOfDay.minute) : null;

    setState(() => _loading = true);
    try {
      await PlanService.createItem(
        tripId:       tripId,
        dayId:        dayId,
        title:        widget.spot.name,
        type:         _itemType,
        createdBy:    userId,
        time:         timeStr,
        city:         widget.spot.city.isNotEmpty ? widget.spot.city : widget.spot.area,
        location:     widget.spot.address?.isNotEmpty == true
                          ? widget.spot.address
                          : widget.spot.name,
        mapsUrl:      widget.spot.mapsUrl,
        linkedSpotId: widget.spot.id,
        sortOrder:    day.items.length,
      );
      if (!mounted) return;
      setState(() => _plannedDay = day);
      widget.onPlanned?.call();
      showWabwaySnack(context,
          'Added to Day ${day.dayNumber}${day.city.isEmpty ? '' : ' · ${day.city}'}');
    } catch (e) {
      if (!mounted) return;
      showWabwaySnack(context, 'Could not add to plan. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planned = _plannedDay;
    return WabwayButton(
      label: planned == null
          ? 'Add to Plan'
          : 'In plan · Day ${planned.dayNumber} — add to another day',
      icon: planned == null ? Icons.event_note_rounded : Icons.event_available_rounded,
      variant: WabwayButtonVariant.ghost,
      fullWidth: true,
      loading: _loading,
      onPressed: _loading ? null : _tap,
    );
  }
}

// ─── Lifecycle (Idea → Confirmed → Planned → Visited) ─────────────────────────

/// One spot lifecycle, shown as a stepper with the single next action.
/// Votes stay the group-opinion layer; this is where the spot is in the trip.
class _SpotLifecycle extends StatelessWidget {
  const _SpotLifecycle({
    required this.status,
    required this.onSetStatus,
  });

  final SpotStatus status;
  final ValueChanged<SpotStatus> onSetStatus;

  static const _steps = [
    SpotStage.idea,
    SpotStage.confirmed,
    SpotStage.planned,
    SpotStage.visited,
  ];

  @override
  Widget build(BuildContext context) {
    final stage = status.stage;
    final reached = stage == SpotStage.skipped ? -1 : _steps.indexOf(stage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < _steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Container(
                    height: 2,
                    color: i <= reached ? kColorPrimary : kColorBorder,
                  ),
                ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= reached ? kColorPrimary : kColorPaper,
                      border: Border.all(color: i <= reached ? kColorPrimary : kColorBorder, width: 2),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _steps[i].label,
                    style: kStyleCaption.copyWith(
                      color: i == reached ? kColorInk : kColorInkSoft,
                      fontWeight: i == reached ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: kSpace3),
        if (stage == SpotStage.visited || stage == SpotStage.skipped)
          WabwayButton(
            label: stage == SpotStage.skipped ? 'Skipped — undo' : 'Visited — undo',
            icon: Icons.undo_rounded,
            variant: WabwayButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => onSetStatus(SpotStatus.confirmed),
          )
        else
          Row(
            children: [
              Expanded(
                flex: 3,
                child: stage == SpotStage.idea
                    ? WabwayButton(
                        label: 'Confirm — we\'re doing this',
                        icon: Icons.check_rounded,
                        fullWidth: true,
                        onPressed: () => onSetStatus(SpotStatus.confirmed),
                      )
                    : WabwayButton(
                        label: 'Mark as visited',
                        icon: Icons.check_circle_outline_rounded,
                        fullWidth: true,
                        onPressed: () => onSetStatus(SpotStatus.visited),
                      ),
              ),
              const SizedBox(width: kSpace2),
              Expanded(
                flex: 2,
                child: WabwayButton(
                  label: 'Skip',
                  icon: Icons.cancel_outlined,
                  variant: WabwayButtonVariant.ghost,
                  fullWidth: true,
                  onPressed: () => onSetStatus(SpotStatus.skipped),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ─── Delete confirmation ───────────────────────────────────────────────────────

Future<void> _confirmDelete(
    BuildContext context, String name, VoidCallback onConfirmed) async {
  if (await showWabwayDeleteConfirm(context, entity: 'spot', name: name,
      detail: 'for everyone in the trip')) {
    onConfirmed();
  }
}

// ─── Link launcher ─────────────────────────────────────────────────────────────

Future<void> _openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      showWabwaySnack(context, 'Link copied', duration: const Duration(seconds: 2));
    }
  }
}

// ─── Linked doc tile ──────────────────────────────────────────────────────────

class _LinkedDocTile extends StatefulWidget {
  const _LinkedDocTile({required this.doc});
  final TripDocument doc;

  @override
  State<_LinkedDocTile> createState() => _LinkedDocTileState();
}

class _LinkedDocTileState extends State<_LinkedDocTile> {
  bool _loading = false;

  Future<void> _open() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      String? url;
      if (widget.doc.ext == 'url') {
        url = widget.doc.notes;
      } else if (widget.doc.storagePath != null) {
        url = await DocService.getSignedUrl(widget.doc.storagePath!);
      }
      if (!mounted) return;
      if (url != null) {
        final uri = Uri.tryParse(url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      hoverable: true,
      onTap: _open,
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: widget.doc.type.softColor,
              borderRadius: kRadiusMd,
            ),
            child: Icon(widget.doc.type.icon, size: 16, color: widget.doc.type.color),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.doc.title, style: kStyleBodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(widget.doc.type.label, style: kStyleCaption.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: kSpace2),
          if (_loading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(kColorPrimary)))
          else
            const Icon(Icons.open_in_new_rounded, size: 16, color: kColorInkSoft),
        ],
      ),
    );
  }
}

// ─── Linked stay card ─────────────────────────────────────────────────────────

class _LinkedStayCard extends StatelessWidget {
  const _LinkedStayCard({required this.stay, this.onTap});

  final Accommodation stay;
  final VoidCallback? onTap;

  static String _fmtDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final nights = stay.nights;
    String? dateRange;
    if (stay.checkIn != null && stay.checkOut != null) {
      dateRange = '${_fmtDate(stay.checkIn!)} – ${_fmtDate(stay.checkOut!)}';
      if (nights != null) dateRange += ' · $nights ${nights == 1 ? 'night' : 'nights'}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Linked stay', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        WabwayCard(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(kSpace3),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: stay.status.color.withValues(alpha: 0.12),
                    borderRadius: kRadiusSm,
                  ),
                  child: Icon(Icons.hotel_rounded,
                      size: 18, color: stay.status.color),
                ),
                const SizedBox(width: kSpace3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stay.name,
                          style: kStyleBodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      if (dateRange != null)
                        Text(dateRange,
                            style: kStyleCaption.copyWith(color: kColorInkSoft),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: kSpace2),
                WabwayBadge(
                  label: stay.status.label,
                  tone: stay.status.tone,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.category, this.imageUrl});
  final SpotCategory category;
  final String?      imageUrl;

  @override
  Widget build(BuildContext context) {
    final height = imageUrl != null ? 200.0 : 96.0;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background gradient (always present as fallback)
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kColorPrimarySoft, kColorAccentSoft],
              ),
            ),
          ),
          if (imageUrl != null)
            CachedNetworkImage(
              imageUrl: imageUrl!,
              cacheManager: WabwayImageCache.instance,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              placeholder: (_, __) => const SizedBox.shrink(),
            )
          else
            Center(
              child: Icon(
                category.icon,
                size: 40,
                color: kColorPrimaryDark.withValues(alpha: 0.22),
              ),
            ),
          // Subtle scrim at bottom so text below stays readable
          if (imageUrl != null)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                height: 60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0x55000000)],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupVotesSummary extends ConsumerWidget {
  const _GroupVotesSummary({required this.votes});
  final SpotVotes votes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = <Widget>[];

    for (final type in VoteType.values) {
      final ids = votes.voters(type);
      if (ids.isEmpty) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace2),
          child: Row(
            children: [
              ...ids.take(3).map(
                    (id) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: WabwayAvatar(
                        name: ref.memberName(id),
                        size: WabwayAvatarSize.xs,
                      ),
                    ),
                  ),
              if (ids.length > 3)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '+${ids.length - 3}',
                    style: kStyleOverline.copyWith(color: kColorInkSoft),
                  ),
                ),
              const SizedBox(width: 4),
              SpotVoteChip(type: type, selected: true, compact: true),
            ],
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }
}

class _CommentRow extends ConsumerWidget {
  const _CommentRow({required this.comment});
  final SpotComment comment;

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
                    if (comment.vote != null) ...[
                      const SizedBox(width: kSpace2),
                      SpotVoteChip(
                        type: comment.vote!,
                        selected: true,
                        compact: true,
                      ),
                    ],
                    const Spacer(),
                    Text(fmtCommentTime(comment.createdAt),
                        style: kStyleOverline),
                  ],
                ),
                const SizedBox(height: kSpace1),
                Text(comment.text, style: kStyleBody),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentInput extends StatelessWidget {
  const _CommentInput({
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
              hintText: 'Add a comment…',
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
            onSubmitted: (_) => onSubmit(),
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
