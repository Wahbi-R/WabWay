import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/auth/profile_state.dart';
import '../../core/supabase/client.dart';
import '../../core/trip/trip_state.dart';
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

// ─── Grid card (mobile 2-col) ─────────────────────────────────────────────────

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
          // Icon area
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: doc.type.softColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Icon(
                    doc.type.icon,
                    size: 44,
                    color: doc.type.color.withValues(alpha: 0.75),
                  ),
                ),
                Positioned(
                  top: kSpace2,
                  right: kSpace2,
                  child: _ExtBadge(ext: doc.ext, color: doc.extColor, softColor: doc.extSoftColor),
                ),
              ],
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
                    _fmtDate(doc.uploadedAt),
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

// ─── List row (desktop left panel) ────────────────────────────────────────────

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
          // Type icon box
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: doc.type.softColor,
              borderRadius: kRadiusMd,
            ),
            child: Icon(doc.type.icon, size: 22, color: doc.type.color),
          ),
          const SizedBox(width: kSpace3),

          // Middle — title + meta
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
                        ' · ',
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

          // Right — ext + date
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _ExtBadge(ext: doc.ext, color: doc.extColor, softColor: doc.extSoftColor),
              const SizedBox(height: kSpace1),
              Text(
                _fmtDate(doc.uploadedAt),
                style: kStyleCaption.copyWith(fontSize: 11, color: kColorInkSoft),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Extension badge ──────────────────────────────────────────────────────────

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

// ─── Shared ext badge widget (exported) ──────────────────────────────────────

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

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}';
}
