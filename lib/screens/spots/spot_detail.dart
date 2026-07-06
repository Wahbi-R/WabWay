import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/profile_state.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../core/trip/trip_state.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'add_spot_sheet.dart';
import 'spot_vote_chip.dart';

// ─── Member name helper ────────────────────────────────────────────────────────

String _memberName(BuildContext context, String userId) {
  final me = ProfileState.maybeOf(context);
  if (me?.id == userId) return 'You';
  final members = TripState.membersOf(context);
  final match = members.where((m) => m.userId == userId).firstOrNull;
  if (match != null) return match.profile.displayName;
  return userId.length >= 8 ? userId.substring(0, 8) : userId;
}

// ─── Full-screen route for mobile ─────────────────────────────────────────────

class SpotDetailScreen extends StatelessWidget {
  const SpotDetailScreen({
    super.key,
    required this.spot,
    this.myVote,
    this.onVote,
    this.canDelete = false,
    this.onDelete,
    this.onEdit,
    this.docs = const [],
  });

  final Spot spot;
  final VoteType? myVote;
  final ValueChanged<VoteType?>? onVote;
  final bool canDelete;
  final VoidCallback? onDelete;
  final ValueChanged<Spot>? onEdit;
  final List<TripDocument> docs;

  @override
  Widget build(BuildContext context) {
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
          if (onEdit != null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              color: kColorInkSoft,
              onPressed: () async {
                final tripId = TripState.tripOf(context).id;
                final userId = supabase.auth.currentUser?.id ?? '';
                final updated = await showEditSpotSheet(
                  context,
                  tripId: tripId,
                  userId: userId,
                  spot: spot,
                );
                if (updated != null) onEdit!(updated);
              },
            ),
          if (canDelete && onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              color: kColorDanger,
              onPressed: () => _confirmDelete(context, onDelete!),
            ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.only(bottom: kSpace12 + MediaQuery.paddingOf(context).bottom),
        child: SpotDetailContent(
          spot: spot,
          myVote: myVote,
          onVote: onVote,
          docs: docs,
        ),
      ),
    );
  }
}

// ─── Shared detail content (mobile screen + desktop panel) ────────────────────

class SpotDetailContent extends StatefulWidget {
  const SpotDetailContent({
    super.key,
    required this.spot,
    this.myVote,
    this.onVote,
    this.showHeader = false,
    this.canDelete = false,
    this.onDelete,
    this.onEdit,
    this.docs = const [],
  });

  final Spot spot;
  final VoteType? myVote;
  final ValueChanged<VoteType?>? onVote;
  final bool showHeader;
  final bool canDelete;
  final VoidCallback? onDelete;
  final ValueChanged<Spot>? onEdit;
  final List<TripDocument> docs;

  @override
  State<SpotDetailContent> createState() => _SpotDetailContentState();
}

class _SpotDetailContentState extends State<SpotDetailContent> {
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
    final myName = ProfileState.maybeOf(context)?.displayName ?? 'You';

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
                  if (widget.onEdit != null) ...[
                    const SizedBox(width: kSpace2),
                    GestureDetector(
                      onTap: () async {
                        final tripId = TripState.tripOf(context).id;
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
                      onTap: () => _confirmDelete(context, widget.onDelete!),
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
                    '${widget.spot.city}, ${widget.spot.area}',
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

              // ── Address line (if from dataset)
              if (widget.spot.address != null) ...[
                const SizedBox(height: kSpace1),
                Row(
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
                  ],
                ),
              ],
              const SizedBox(height: kSpace4),
              const Divider(height: 1),
              const SizedBox(height: kSpace4),

              // ── Links
              if (widget.spot.mapsUrl != null ||
                  widget.spot.sourceUrl != null) ...[
                Text('Links',
                    style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                const SizedBox(height: kSpace2),
                Wrap(
                  spacing: kSpace2,
                  runSpacing: kSpace2,
                  children: [
                    if (widget.spot.mapsUrl != null)
                      WabwayButton(
                        label: 'Open in Maps',
                        icon: Icons.map_rounded,
                        variant: WabwayButtonVariant.ghost,
                        size: WabwayButtonSize.sm,
                        onPressed: () =>
                            _openLink(context, widget.spot.mapsUrl!),
                      ),
                    if (widget.spot.sourceUrl != null)
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

// ─── Delete confirmation ───────────────────────────────────────────────────────

Future<void> _confirmDelete(
    BuildContext context, VoidCallback onConfirmed) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete spot?'),
      content:
          const Text('This will remove the spot for everyone in the trip.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete', style: TextStyle(color: kColorDanger)),
        ),
      ],
    ),
  );
  if (confirmed == true) onConfirmed();
}

// ─── Link launcher ─────────────────────────────────────────────────────────────

Future<void> _openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link copied',
              style: kStyleBody.copyWith(color: Colors.white)),
          backgroundColor: kColorInk,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
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
            Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              cacheWidth: 800,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : const SizedBox.shrink(),
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

class _GroupVotesSummary extends StatelessWidget {
  const _GroupVotesSummary({required this.votes});
  final SpotVotes votes;

  @override
  Widget build(BuildContext context) {
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
                        name: _memberName(context, id),
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

class _CommentRow extends StatelessWidget {
  const _CommentRow({required this.comment});
  final SpotComment comment;

  @override
  Widget build(BuildContext context) {
    final name = _memberName(context, comment.authorId);
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
