import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'spot_vote_chip.dart';

// ─── Full-screen route for mobile ─────────────────────────────────────────────

class SpotDetailScreen extends StatelessWidget {
  const SpotDetailScreen({
    super.key,
    required this.spot,
    this.myVote,
    this.onVote,
  });

  final Spot spot;
  final VoteType? myVote;
  final ValueChanged<VoteType?>? onVote;

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
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: kSpace12),
        child: SpotDetailContent(
          spot: spot,
          myVote: myVote,
          onVote: onVote,
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
  });

  final Spot spot;
  final VoteType? myVote;
  final ValueChanged<VoteType?>? onVote;
  final bool showHeader;

  @override
  State<SpotDetailContent> createState() => _SpotDetailContentState();
}

class _SpotDetailContentState extends State<SpotDetailContent> {
  late VoteType? _myVote;
  final _commentCtrl = TextEditingController();
  final List<SpotComment> _extraComments = [];

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

  void _submitComment() {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _extraComments.add(SpotComment(
        author: 'You',
        vote: _myVote,
        text: text,
        time: 'just now',
      ));
      _commentCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final allComments = [...widget.spot.comments, ..._extraComments];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Photo placeholder
        _PhotoHeader(category: widget.spot.category),

        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace4, kSpace4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title + badge
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
                ],
              ),
              const SizedBox(height: kSpace2),

              // ── City / area / category
              Row(
                children: [
                  const Icon(Icons.place_rounded, size: 14, color: kColorInkSoft),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.spot.city}, ${widget.spot.area}',
                    style: kStyleCaptionMedium,
                  ),
                  const SizedBox(width: kSpace2),
                  WabwayTag(label: widget.spot.category.label),
                ],
              ),
              const SizedBox(height: kSpace4),
              const Divider(height: 1),
              const SizedBox(height: kSpace4),

              // ── Links
              if (widget.spot.mapsUrl != null || widget.spot.sourceUrl != null) ...[
                Text('Links', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
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
                        onPressed: () => _openLink(context, widget.spot.mapsUrl!),
                      ),
                    if (widget.spot.sourceUrl != null)
                      WabwayButton(
                        label: 'View source',
                        icon: Icons.link_rounded,
                        variant: WabwayButtonVariant.ghost,
                        size: WabwayButtonSize.sm,
                        onPressed: () => _openLink(context, widget.spot.sourceUrl!),
                      ),
                  ],
                ),
                const SizedBox(height: kSpace4),
                const Divider(height: 1),
                const SizedBox(height: kSpace4),
              ],

              // ── Notes
              if (widget.spot.notes != null) ...[
                Text('Notes', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
                const SizedBox(height: kSpace2),
                Text(widget.spot.notes!, style: kStyleBody),
                const SizedBox(height: kSpace4),
                const Divider(height: 1),
                const SizedBox(height: kSpace4),
              ],

              // ── Vote
              Text('Your vote', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
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

Future<void> _openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Link copied', style: kStyleBody.copyWith(color: Colors.white)),
          backgroundColor: kColorInk,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _PhotoHeader extends StatelessWidget {
  const _PhotoHeader({required this.category});
  final SpotCategory category;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kColorPrimarySoft, kColorAccentSoft],
          ),
        ),
        child: Center(
          child: Icon(
            category.icon,
            size: 40,
            color: kColorPrimaryDark.withValues(alpha: 0.22),
          ),
        ),
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
      final names = votes.voters(type);
      if (names.isEmpty) continue;
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: kSpace2),
          child: Row(
            children: [
              ...names.take(3).map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: WabwayAvatar(
                        name: name,
                        size: WabwayAvatarSize.xs,
                      ),
                    ),
                  ),
              if (names.length > 3)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '+${names.length - 3}',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WabwayAvatar(name: comment.author, size: WabwayAvatarSize.sm),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.author,
                      style: kStyleBodySemibold,
                    ),
                    if (comment.vote != null) ...[
                      const SizedBox(width: kSpace2),
                      SpotVoteChip(
                        type: comment.vote!,
                        selected: true,
                        compact: true,
                      ),
                    ],
                    const Spacer(),
                    Text(comment.time, style: kStyleOverline),
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
  const _CommentInput({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const WabwayAvatar(name: 'You', size: WabwayAvatarSize.sm),
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
          icon: Icons.send_rounded,
          label: 'Send',
          variant: WabwayIconButtonVariant.solid,
          size: WabwayIconButtonSize.sm,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}
