import 'package:flutter/material.dart';
import '../../data/share_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';

class ContentPreviewCard extends StatelessWidget {
  const ContentPreviewCard({
    super.key,
    required this.share,
  });

  final IncomingShare share;

  @override
  Widget build(BuildContext context) {
    final type = share.contentType;
    return Container(
      decoration: kCardDecoration(),
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SourceBadge(type: type),
              const Spacer(),
              Text(
                type.label,
                style: kStyleCaption.copyWith(color: kColorInkSoft),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Text(
            share.detectedTitle,
            style: kStyleBodySemibold,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (share.detectedDescription != null) ...[
            const SizedBox(height: kSpace1),
            Text(
              share.detectedDescription!,
              style: kStyleCaption,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: kSpace3),
          _RawContentChip(rawContent: share.rawContent),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.type});

  final ShareContentType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: type.softColor,
        borderRadius: kRadiusPill,
        border: Border.all(color: type.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(type.icon, size: 12, color: type.color),
          const SizedBox(width: 5),
          Text(
            type.sourceName,
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

class _RawContentChip extends StatelessWidget {
  const _RawContentChip({required this.rawContent});

  final String rawContent;

  bool get _isFile =>
      rawContent.endsWith('.pdf') ||
      rawContent.endsWith('.jpg') ||
      rawContent.endsWith('.jpeg') ||
      rawContent.endsWith('.png');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: 6),
      decoration: BoxDecoration(
        color: kColorSurfaceSunken,
        borderRadius: kRadiusSm,
        border: Border.all(color: kColorBorder),
      ),
      child: Row(
        children: [
          Icon(
            _isFile ? Icons.insert_drive_file_rounded : Icons.link_rounded,
            size: 14,
            color: kColorInkSoft,
          ),
          const SizedBox(width: kSpace2),
          Expanded(
            child: Text(
              rawContent,
              style: kStyleCaptionMedium.copyWith(color: kColorInkSoft),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
