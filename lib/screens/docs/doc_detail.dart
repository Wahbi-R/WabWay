import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'doc_card.dart';
import '../money/add_receipt_sheet.dart';

// ─── Mobile screen ────────────────────────────────────────────────────────────

class DocDetailScreen extends StatelessWidget {
  const DocDetailScreen({super.key, required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text(doc.title, style: kStyleTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            color: kColorInkSoft,
            onPressed: () => _showActionsSheet(context, doc),
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        child: DocDetailContent(doc: doc),
      ),
    );
  }
}

// ─── Shared content ───────────────────────────────────────────────────────────

class DocDetailContent extends StatelessWidget {
  const DocDetailContent({super.key, required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DocHeader(doc: doc),
        Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FileMetaCard(doc: doc),
              if (doc.links.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                _LinkedSection(links: doc.links),
              ],
              if (doc.notes != null && doc.notes!.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                _NotesSection(notes: doc.notes!),
              ],
              const SizedBox(height: kSpace4),
              _ActionsSection(doc: doc),
              const SizedBox(height: kSpace8),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Header band ──────────────────────────────────────────────────────────────

class _DocHeader extends StatelessWidget {
  const _DocHeader({required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(kSpace4, kSpace6, kSpace4, kSpace5),
      decoration: BoxDecoration(color: doc.type.softColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: doc.type.color.withValues(alpha: 0.12),
                  borderRadius: kRadiusLg,
                ),
                child: Icon(doc.type.icon, size: 28, color: doc.type.color),
              ),
              const SizedBox(width: kSpace3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TypeBadge(type: doc.type),
                  const SizedBox(height: kSpace1),
                  DocExtBadge(doc: doc),
                ],
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          Text(
            doc.title,
            style: kStyleTitle.copyWith(fontSize: 20, height: 1.25),
          ),
        ],
      ),
    );
  }
}

// ─── File metadata card ───────────────────────────────────────────────────────

class _FileMetaCard extends StatelessWidget {
  const _FileMetaCard({required this.doc});
  final TripDocument doc;

  @override
  Widget build(BuildContext context) {
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
          _MetaRow(
            icon: Icons.person_outline_rounded,
            label: 'Uploaded by',
            value: doc.uploadedBy,
          ),
          _divider(),
          _MetaRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: _fmtDateFull(doc.uploadedAt),
          ),
          _divider(),
          _MetaRow(
            icon: Icons.storage_rounded,
            label: 'File size',
            value: doc.formattedSize,
          ),
          if (doc.amount != null) ...[
            _divider(),
            _MetaRow(
              icon: Icons.attach_money_rounded,
              label: 'Amount',
              value: fmtAmount(doc.amount!, doc.currency ?? 'JPY'),
              valueStyle: GoogleFonts.ibmPlexMono(
                fontSize: kTextBase,
                fontWeight: FontWeight.w600,
                color: kColorInk,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: kSpace4, thickness: 1, color: kColorBorder);
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: kColorInkSoft),
        const SizedBox(width: kSpace2),
        Text(label, style: kStyleCaption),
        const Spacer(),
        Text(
          value,
          style: valueStyle ?? kStyleBodyMedium,
        ),
      ],
    );
  }
}

// ─── Linked section ───────────────────────────────────────────────────────────

class _LinkedSection extends StatelessWidget {
  const _LinkedSection({required this.links});
  final List<DocumentLink> links;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Linked to', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        ...links.map((link) => _LinkedRow(link: link)),
      ],
    );
  }
}

class _LinkedRow extends StatelessWidget {
  const _LinkedRow({required this.link});
  final DocumentLink link;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: WabwayCard(
        hoverable: true,
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
              'Navigate to ${link.type.label}: ${link.label}',
              style: kStyleBody.copyWith(color: Colors.white),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ));
        },
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: kColorSurfaceSunken,
                borderRadius: kRadiusMd,
              ),
              child: Icon(link.type.icon, size: 16, color: kColorInkSoft),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    link.label,
                    style: kStyleBodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    link.type.label,
                    style: kStyleCaption.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: kColorInkSoft),
          ],
        ),
      ),
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
          decoration: BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
          ),
          child: Text(notes, style: kStyleBody),
        ),
      ],
    );
  }
}

// ─── Actions section ──────────────────────────────────────────────────────────

class _ActionsSection extends StatelessWidget {
  const _ActionsSection({required this.doc});
  final TripDocument doc;

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
            WabwayButton(
              label: 'Open',
              icon: Icons.open_in_new_rounded,
              size: WabwayButtonSize.sm,
              onPressed: () => _mock(context, 'Opening ${doc.title}…'),
            ),
            WabwayButton(
              label: 'Download',
              icon: Icons.download_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _mock(context, 'Downloading ${doc.title}…'),
            ),
            WabwayButton(
              label: 'Rename',
              icon: Icons.edit_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _showRenameDialog(context),
            ),
            WabwayButton(
              label: 'Create Receipt',
              icon: Icons.receipt_long_rounded,
              variant: WabwayButtonVariant.secondary,
              size: WabwayButtonSize.sm,
              onPressed: () async {
                final r = await showAddReceiptSheet(context);
                if (r != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                      'Receipt "${r.title}" created',
                      style: kStyleBody.copyWith(color: Colors.white),
                    ),
                    backgroundColor: kColorSuccess,
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ));
                }
              },
            ),
            WabwayButton(
              label: 'Attach to Itinerary',
              icon: Icons.event_note_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: () => _mock(context, 'Select itinerary item to attach to'),
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

  void _mock(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: kStyleBody.copyWith(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showRenameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: doc.title);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Rename document', style: kStyleBodySemibold),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Document title',
            hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
          ),
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
              _mock(context, 'Renamed to "${ctrl.text}"');
            },
            child: Text('Rename', style: kStyleBodyMedium.copyWith(color: kColorPrimary)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Delete document?', style: kStyleBodySemibold),
        content: Text(
          'This will permanently remove "${doc.title}" from your trip.',
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
              if (context.mounted) Navigator.maybePop(context);
            },
            child: Text('Delete', style: kStyleBodyMedium.copyWith(color: kColorDanger)),
          ),
        ],
      ),
    );
  }
}

// ─── Mobile actions bottom sheet ──────────────────────────────────────────────

void _showActionsSheet(BuildContext context, TripDocument doc) {
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
              decoration: const BoxDecoration(color: kColorBorder, borderRadius: kRadiusPill),
            ),
          ),
          _ActionTile(
            icon: Icons.open_in_new_rounded,
            label: 'Open',
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Opening ${doc.title}…',
                    style: kStyleBody.copyWith(color: Colors.white)),
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
          _ActionTile(
            icon: Icons.download_rounded,
            label: 'Download',
            onTap: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Downloading…',
                    style: kStyleBody.copyWith(color: Colors.white)),
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
          _ActionTile(
            icon: Icons.edit_rounded,
            label: 'Rename',
            onTap: () {
              Navigator.pop(ctx);
            },
          ),
          _ActionTile(
            icon: Icons.receipt_long_rounded,
            label: 'Create Receipt from document',
            onTap: () async {
              Navigator.pop(ctx);
              await showAddReceiptSheet(context);
            },
          ),
          _ActionTile(
            icon: Icons.event_note_rounded,
            label: 'Attach to Itinerary',
            onTap: () => Navigator.pop(ctx),
          ),
          _ActionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: kColorDanger,
            onTap: () {
              Navigator.pop(ctx);
              Navigator.maybePop(context);
            },
          ),
          const SizedBox(height: kSpace4),
        ],
      ),
    ),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
  final DocType type;

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
          Icon(type.icon, size: 13, color: type.color),
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDateFull(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
