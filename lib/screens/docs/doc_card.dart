import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/profile_state.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/trip/trip_state.dart';
import '../../data/date_utils.dart';
import '../../data/docs_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';

String _uploaderName(BuildContext context, String userId) {
  final myId = supabase.auth.currentUser?.id ?? ProfileState.maybeOf(context)?.id;
  if (myId != null && userId == myId) return 'You';
  final members = TripState.membersOf(context);
  final match = members.where((m) => m.userId == userId).firstOrNull;
  if (match != null) return match.profile.displayName;
  return userId.length >= 8 ? userId.substring(0, 8) : userId;
}

// â”€â”€â”€ Grid card (mobile 2-col) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class DocGridCard extends StatelessWidget {
  const DocGridCard({
    super.key,
    required this.doc,
    this.selected = false,
    required this.onTap,
  });

  final TripDocument doc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      hoverable: true,
      selected: selected,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Icon / thumbnail area
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: SizedBox(
              height: 80,
              child: doc.isImage && doc.storagePath != null
                  ? FutureBuilder<String?>(
                      future: DocService.getThumbnailUrl(doc.storagePath!, doc.ext),
                      builder: (context, snap) {
                        if (snap.hasData && snap.data != null) {
                          return Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                snap.data!,
                                fit: BoxFit.cover,
                                frameBuilder: (ctx, child, frame, _) => AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 200),
                                  child: child,
                                ),
                                errorBuilder: (_, __, ___) => _IconArea(doc: doc),
                              ),
                              Positioned(
                                top: kSpace2,
                                right: kSpace2,
                                child: _ExtBadge(ext: doc.ext, color: doc.extColor, softColor: doc.extSoftColor),
                              ),
                            ],
                          );
                        }
                        return _IconArea(doc: doc, showBadge: true);
                      },
                    )
                  : _IconArea(doc: doc, showBadge: true),
            ),
          ),

          // Metadata area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(kSpace3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.title,
                    style: kStyleBodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: kSpace1),
                  Text(
                    doc.type.label,
                    style: kStyleCaption.copyWith(color: doc.type.color),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 11, color: kColorInkSoft),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          _uploaderName(context, doc.uploadedById),
                          style: kStyleCaption.copyWith(fontSize: 11),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    fmtDate(doc.uploadedAt),
                    style: kStyleCaption.copyWith(fontSize: 11, color: kColorInkSoft),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ List row (desktop left panel) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class DocListRow extends StatelessWidget {
  const DocListRow({
    super.key,
    required this.doc,
    this.selected = false,
    required this.onTap,
  });

  final TripDocument doc;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WabwayCard(
      hoverable: true,
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
      child: Row(
        children: [
          // Type icon / thumbnail box
          ClipRRect(
            borderRadius: kRadiusMd,
            child: SizedBox(
              width: 44,
              height: 44,
              child: doc.isImage && doc.storagePath != null
                  ? FutureBuilder<String?>(
                      future: DocService.getThumbnailUrl(doc.storagePath!, doc.ext),
                      builder: (context, snap) {
                        if (snap.hasData && snap.data != null) {
                          return Image.network(
                            snap.data!,
                            fit: BoxFit.cover,
                            frameBuilder: (ctx, child, frame, _) => AnimatedOpacity(
                              opacity: frame == null ? 0 : 1,
                              duration: const Duration(milliseconds: 200),
                              child: child,
                            ),
                            errorBuilder: (_, __, ___) => _SmallIconBox(doc: doc),
                          );
                        }
                        return _SmallIconBox(doc: doc);
                      },
                    )
                  : _SmallIconBox(doc: doc),
            ),
          ),
          const SizedBox(width: kSpace3),

          // Middle â€” title + meta
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  style: kStyleBodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      doc.type.label,
                      style: kStyleCaption.copyWith(color: doc.type.color, fontSize: 12),
                    ),
                    if (doc.links.isNotEmpty) ...[
                      Text(
                        ' Â· ',
                        style: kStyleCaption.copyWith(color: kColorInkSoft, fontSize: 12),
                      ),
                      const Icon(Icons.link_rounded, size: 11, color: kColorInkSoft),
                      const SizedBox(width: 2),
                      Text(
                        '${doc.links.length}',
                        style: kStyleCaption.copyWith(color: kColorInkSoft, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: kSpace2),

          // Right â€” ext + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ExtBadge(ext: doc.ext, color: doc.extColor, softColor: doc.extSoftColor),
              const SizedBox(height: kSpace1),
              Text(
                fmtDate(doc.uploadedAt),
                style: kStyleCaption.copyWith(fontSize: 11, color: kColorInkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Icon area helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _IconArea extends StatelessWidget {
  const _IconArea({required this.doc, this.showBadge = false});
  final TripDocument doc;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: doc.type.softColor,
      child: Stack(
        children: [
          Center(
            child: Icon(
              doc.type.icon,
              size: 44,
              color: doc.type.color.withValues(alpha: 0.75),
            ),
          ),
          if (showBadge)
            Positioned(
              top: kSpace2,
              right: kSpace2,
              child: _ExtBadge(ext: doc.ext, color: doc.extColor, softColor: doc.extSoftColor),
            ),
        ],
      ),
    );
  }
}

class _SmallIconBox extends StatelessWidget {
  const _SmallIconBox({required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: doc.type.softColor,
      child: Icon(doc.type.icon, size: 22, color: doc.type.color),
    );
  }
}

// â”€â”€â”€ Extension badge â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ExtBadge extends StatelessWidget {
  const _ExtBadge({
    required this.ext,
    required this.color,
    required this.softColor,
  });

  final String ext;
  final Color color;
  final Color softColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: softColor,
        borderRadius: kRadiusPill,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        ext.toUpperCase(),
        style: GoogleFonts.ibmPlexMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// â”€â”€â”€ Shared ext badge widget (exported) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class DocExtBadge extends StatelessWidget {
  const DocExtBadge({super.key, required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
    return _ExtBadge(
      ext: doc.ext,
      color: doc.extColor,
      softColor: doc.extSoftColor,
    );
  }
}

