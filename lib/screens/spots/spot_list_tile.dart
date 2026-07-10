import 'package:flutter/material.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'spot_vote_chip.dart';

class SpotListTile extends StatelessWidget {
  const SpotListTile({
    super.key,
    required this.spot,
    this.selected = false,
    this.myVote,
    this.onTap,
  });

  final Spot spot;
  final bool selected;
  final VoteType? myVote;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isVisited = spot.status == SpotStatus.visited;
    final isSkipped = spot.status == SpotStatus.skipped;
    final isDone    = isVisited || isSkipped;

    Widget card = WabwayCard(
      hoverable: true,
      selected: selected,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PhotoSlot(
              category: spot.category,
              imageUrl: spot.imageUrl,
              overlayIcon:  isVisited ? Icons.check_circle_rounded
                          : isSkipped ? Icons.cancel_rounded
                          : null,
              overlayColor: isVisited ? kColorSuccess : kColorInkSoft,
            ),
            const SizedBox(width: kSpace4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          spot.name,
                          style: kStyleBodyBold,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: kSpace2),
                      WabwayBadge(
                        label: spot.status.label,
                        tone: spot.status.tone,
                      ),
                    ],
                  ),
                  const SizedBox(height: kSpace1),
                  Row(
                    children: [
                      Icon(
                        Icons.place_rounded,
                        size: 12,
                        color: kColorTextTertiary(),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          '${spot.city} · ${spot.area} · ${spot.category.label}',
                          style: kStyleCaption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (spot.notes != null && spot.notes!.isNotEmpty) ...[
                    const SizedBox(height: kSpace2),
                    Text(
                      spot.notes!,
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (spot.votes.total > 0 || spot.comments.isNotEmpty) ...[
                    const SizedBox(height: kSpace2),
                    Row(
                      children: [
                        if (spot.votes.total > 0) SpotVoteSummary(votes: spot.votes),
                        if (spot.votes.total > 0 && spot.comments.isNotEmpty)
                          const SizedBox(width: kSpace3),
                        if (spot.comments.isNotEmpty) ...[
                          Icon(Icons.chat_bubble_outline_rounded, size: 12, color: kColorInkSoft),
                          const SizedBox(width: 3),
                          Text(
                            '${spot.comments.length}',
                            style: kStyleCaption,
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (myVote != null) ...[
                    const SizedBox(height: kSpace2),
                    Row(
                      children: [
                        Icon(Icons.how_to_vote_rounded, size: 12, color: myVote!.color),
                        const SizedBox(width: 4),
                        Text(
                          'You voted: ${myVote!.label}',
                          style: kStyleOverline.copyWith(color: myVote!.color),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (isDone) {
      card = Opacity(
        opacity: isVisited ? 0.65 : 0.45,
        child: card,
      );
    }

    return card;
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.category,
    this.imageUrl,
    this.overlayIcon,
    this.overlayColor,
  });
  final SpotCategory category;
  final String?      imageUrl;
  final IconData?    overlayIcon;
  final Color?       overlayColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: kRadiusMd,
      child: Stack(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kColorPrimarySoft, kColorAccentSoft],
              ),
              border: Border.all(color: kColorBorder),
            ),
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    width: 76,
                    height: 76,
                    cacheWidth: 152,
                    errorBuilder: (_, __, ___) => _icon,
                    loadingBuilder: (_, child, progress) =>
                        progress == null ? child : _icon,
                  )
                : _icon,
          ),
          if (overlayIcon != null)
            Positioned(
              bottom: 4,
              right: 4,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: kColorPaper,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  overlayIcon,
                  size: 16,
                  color: overlayColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget get _icon => Center(
        child: Icon(
          category.icon,
          size: 28,
          color: kColorPrimaryDark.withValues(alpha: 0.35),
        ),
      );
}
