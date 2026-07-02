import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/profile_state.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/trip/trip_state.dart';
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'doc_card.dart';
import '../money/add_receipt_sheet.dart';

// ── Member name helper ────────────────────────────────────────────────────────

String _uploaderName(BuildContext context, String userId) {
  final myId =
      supabase.auth.currentUser?.id ?? ProfileState.maybeOf(context)?.id;
  if (myId != null && userId == myId) return 'You';
  final members = TripState.membersOf(context);
  final match = members.where((m) => m.userId == userId).firstOrNull;
  if (match != null) return match.profile.displayName;
  return userId.length >= 8 ? userId.substring(0, 8) : userId;
}

// ── Linked label helper ───────────────────────────────────────────────────────

String _linkedLabel(DocumentLink link, List<Spot> spots, String tripName) {
  switch (link.type) {
    case DocLinkedType.spot:
      return spots.where((s) => s.id == link.linkedId).firstOrNull?.name ??
          'Spot';
    case DocLinkedType.trip:
      return tripName;
    default:
      return link.type.label;
  }
}

// ── Link key helper ───────────────────────────────────────────────────────────

String _linkKey(DocumentLink link) => '${link.type.name}_${link.linkedId}';

// ── Mobile screen ─────────────────────────────────────────────────────────────

class DocDetailScreen extends StatelessWidget {
  const DocDetailScreen({
    super.key,
    required this.doc,
    required this.tripId,
    required this.tripName,
    this.availableSpots = const [],
    this.onDelete,
  });

  final TripDocument doc;
  final String tripId;
  final String tripName;
  final List<Spot> availableSpots;
  final VoidCallback? onDelete;

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
            onPressed: () => _showActionsSheet(
              context,
              doc: doc,
              onDelete: onDelete,
            ),
          ),
          const SizedBox(width: kSpace2),
        ],
      ),
      body: SingleChildScrollView(
        child: DocDetailContent(
          doc: doc,
          tripId: tripId,
          tripName: tripName,
          availableSpots: availableSpots,
          onDelete: onDelete,
        ),
      ),
    );
  }
}

// ── Shared content ────────────────────────────────────────────────────────────

class DocDetailContent extends StatefulWidget {
  const DocDetailContent({
    super.key,
    required this.doc,
    required this.tripId,
    required this.tripName,
    this.availableSpots = const [],
    this.onDelete,
  });

  final TripDocument doc;
  final String tripId;
  final String tripName;
  final List<Spot> availableSpots;
  final VoidCallback? onDelete;

  @override
  State<DocDetailContent> createState() => _DocDetailContentState();
}

class _DocDetailContentState extends State<DocDetailContent> {
  late List<DocumentLink> _links;
  bool _linkLoading = false;
  final Set<String> _unlinkingKeys = {};

  @override
  void initState() {
    super.initState();
    _links = List.from(widget.doc.links);
  }

  @override
  void didUpdateWidget(DocDetailContent old) {
    super.didUpdateWidget(old);
    if (widget.doc.id != old.doc.id) {
      // Different doc selected on desktop — reset everything.
      _links = List.from(widget.doc.links);
      _unlinkingKeys.clear();
    } else if (!_linkLoading && _unlinkingKeys.isEmpty) {
      // Same doc, no operation in flight — accept server state so Realtime
      // updates from other accounts are reflected immediately.
      _links = List.from(widget.doc.links);
    }
  }

  Future<void> _addLink(DocLinkedType type, String linkedId) async {
    if (_links.any((l) => l.type == type && l.linkedId == linkedId)) return;
    // Capture context-dependent values before the async gap.
    final userId =
        supabase.auth.currentUser?.id ?? ProfileState.of(context).id;
    setState(() => _linkLoading = true);
    try {
      await DocService.addLink(
        documentId: widget.doc.id,
        linkedType: type,
        linkedId: linkedId,
        createdBy: userId,
      );
      if (!mounted) return;
      setState(() {
        _links = [..._links, DocumentLink(type: type, linkedId: linkedId)];
        _linkLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _linkLoading = false);
      _snack('Could not add link. Please try again.');
    }
  }

  Future<void> _removeLink(DocumentLink link) async {
    final key = _linkKey(link);
    setState(() => _unlinkingKeys.add(key));
    try {
      await DocService.deleteLink(
        documentId: widget.doc.id,
        linkedType: link.type,
        linkedId: link.linkedId,
      );
      if (!mounted) return;
      setState(() {
        _links = _links.where((l) => _linkKey(l) != key).toList();
        _unlinkingKeys.remove(key);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _unlinkingKeys.remove(key));
      _snack('Could not remove link. Please try again.');
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: kStyleBody.copyWith(color: Colors.white)),
      backgroundColor: kColorDanger,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showLinkPicker() {
    final alreadyTripIds = _links
        .where((l) => l.type == DocLinkedType.trip)
        .map((l) => l.linkedId)
        .toSet();
    final alreadySpotIds = _links
        .where((l) => l.type == DocLinkedType.spot)
        .map((l) => l.linkedId)
        .toSet();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
      builder: (ctx) => _LinkPickerSheet(
        tripId: widget.tripId,
        tripName: widget.tripName,
        availableSpots: widget.availableSpots,
        alreadyLinkedTripIds: alreadyTripIds,
        alreadyLinkedSpotIds: alreadySpotIds,
        onPick: (type, linkedId) {
          Navigator.pop(ctx);
          _addLink(type, linkedId);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DocHeader(doc: widget.doc),
        Padding(
          padding: const EdgeInsets.all(kSpace4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FileMetaCard(doc: widget.doc),
              const SizedBox(height: kSpace4),
              _LinkedSection(
                links: _links,
                availableSpots: widget.availableSpots,
                tripName: widget.tripName,
                linkLoading: _linkLoading,
                unlinkingKeys: _unlinkingKeys,
                onAddLink: _showLinkPicker,
                onRemoveLink: _removeLink,
              ),
              if (widget.doc.notes != null &&
                  widget.doc.notes!.isNotEmpty) ...[
                const SizedBox(height: kSpace4),
                WabwayNotesSection(notes: widget.doc.notes!),
              ],
              const SizedBox(height: kSpace4),
              _ActionsSection(doc: widget.doc, onDelete: widget.onDelete),
              const SizedBox(height: kSpace8),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Header band ───────────────────────────────────────────────────────────────

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
                  WabwayEntityBadge(
                    icon: doc.type.icon,
                    label: doc.type.label,
                    color: doc.type.color,
                  ),
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

// ── File metadata card ────────────────────────────────────────────────────────

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
          WabwayMetaRow(
            icon: Icons.person_outline_rounded,
            label: 'Uploaded by',
            value: _uploaderName(context, doc.uploadedById),
          ),
          _divider(),
          WabwayMetaRow(
            icon: Icons.calendar_today_rounded,
            label: 'Date',
            value: _fmtDateFull(doc.uploadedAt),
          ),
          _divider(),
          WabwayMetaRow(
            icon: Icons.storage_rounded,
            label: 'File size',
            value: doc.formattedSize,
          ),
          if (doc.amount != null) ...[
            _divider(),
            WabwayMetaRow(
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

// ── Linked section ────────────────────────────────────────────────────────────

class _LinkedSection extends StatelessWidget {
  const _LinkedSection({
    required this.links,
    required this.availableSpots,
    required this.tripName,
    required this.linkLoading,
    required this.unlinkingKeys,
    required this.onAddLink,
    required this.onRemoveLink,
  });

  final List<DocumentLink> links;
  final List<Spot> availableSpots;
  final String tripName;
  final bool linkLoading;
  final Set<String> unlinkingKeys;
  final VoidCallback onAddLink;
  final ValueChanged<DocumentLink> onRemoveLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Linked to',
                style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const Spacer(),
            if (linkLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kColorPrimary),
                ),
              )
            else
              GestureDetector(
                onTap: onAddLink,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: kSpace1, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 15, color: kColorPrimary),
                      const SizedBox(width: 3),
                      Text(
                        'Add link',
                        style: kStyleCaptionMedium.copyWith(
                            color: kColorPrimary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: kSpace2),
        if (links.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: kSpace1, bottom: kSpace1),
            child: Text(
              'Not linked to anything yet.',
              style: kStyleCaption.copyWith(color: kColorInkSoft),
            ),
          )
        else
          ...links.map((link) => _LinkedRow(
                link: link,
                availableSpots: availableSpots,
                tripName: tripName,
                isUnlinking: unlinkingKeys.contains(_linkKey(link)),
                onRemove: () => onRemoveLink(link),
              )),
      ],
    );
  }
}

class _LinkedRow extends StatelessWidget {
  const _LinkedRow({
    required this.link,
    required this.availableSpots,
    required this.tripName,
    required this.isUnlinking,
    required this.onRemove,
  });

  final DocumentLink link;
  final List<Spot> availableSpots;
  final String tripName;
  final bool isUnlinking;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final label = _linkedLabel(link, availableSpots, tripName);
    return Padding(
      padding: const EdgeInsets.only(bottom: kSpace2),
      child: WabwayCard(
        padding: const EdgeInsets.symmetric(
            horizontal: kSpace3, vertical: kSpace3),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
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
                    label,
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
            const SizedBox(width: kSpace2),
            if (isUnlinking)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(kColorInkSoft),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.link_off_rounded, size: 18),
                color: kColorInkSoft,
                tooltip: 'Remove link',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Link picker sheet ─────────────────────────────────────────────────────────

class _LinkPickerSheet extends StatelessWidget {
  const _LinkPickerSheet({
    required this.tripId,
    required this.tripName,
    required this.availableSpots,
    required this.alreadyLinkedTripIds,
    required this.alreadyLinkedSpotIds,
    required this.onPick,
  });

  final String tripId;
  final String tripName;
  final List<Spot> availableSpots;
  final Set<String> alreadyLinkedTripIds;
  final Set<String> alreadyLinkedSpotIds;
  final void Function(DocLinkedType type, String linkedId) onPick;

  bool get _tripAvailable => !alreadyLinkedTripIds.contains(tripId);

  List<Spot> get _pickableSpots =>
      availableSpots.where((s) => !alreadyLinkedSpotIds.contains(s.id)).toList();

  bool get _hasOptions => _tripAvailable || _pickableSpots.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const WabwayDragHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace3),
            child: Text('Add link', style: kStyleTitle),
          ),
          if (!_hasOptions)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace4),
              child: Text(
                'All available links have been added.',
                style: kStyleBody.copyWith(color: kColorInkSoft),
              ),
            )
          else ...[
            if (_tripAvailable) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    kSpace4, 0, kSpace4, kSpace2),
                child: Text('Trip',
                    style: kStyleCaptionMedium.copyWith(
                        color: kColorInkSoft)),
              ),
              WabwayActionTile(
                icon: DocLinkedType.trip.icon,
                label: tripName,
                onTap: () => onPick(DocLinkedType.trip, tripId),
              ),
            ],
            if (_pickableSpots.isNotEmpty) ...[
              if (_tripAvailable)
                const Divider(
                    height: kSpace4, thickness: 1, color: kColorBorder),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    kSpace4, 0, kSpace4, kSpace2),
                child: Text('Spots',
                    style: kStyleCaptionMedium.copyWith(
                        color: kColorInkSoft)),
              ),
              ..._pickableSpots.map(
                (spot) => WabwayActionTile(
                  icon: DocLinkedType.spot.icon,
                  label: spot.name,
                  onTap: () => onPick(DocLinkedType.spot, spot.id),
                ),
              ),
            ],
          ],
          const SizedBox(height: kSpace4),
        ],
      ),
    );
  }
}

// ── Actions section ───────────────────────────────────────────────────────────

class _ActionsSection extends StatefulWidget {
  const _ActionsSection({required this.doc, this.onDelete});
  final TripDocument doc;
  final VoidCallback? onDelete;

  @override
  State<_ActionsSection> createState() => _ActionsSectionState();
}

class _ActionsSectionState extends State<_ActionsSection> {
  bool _openLoading = false;

  Future<void> _openFile() async {
    if (widget.doc.storagePath == null) return;
    setState(() => _openLoading = true);
    try {
      final url = await DocService.getSignedUrl(widget.doc.storagePath!);
      if (!mounted) return;
      if (url == null) {
        _snack('Could not generate link for this file.');
        return;
      }
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _snack('Could not open file.');
      }
    } catch (_) {
      if (mounted) _snack('Could not open file.');
    } finally {
      if (mounted) setState(() => _openLoading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: kStyleBody.copyWith(color: Colors.white)),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  void _showRenameDialog() {
    final ctrl = TextEditingController(text: widget.doc.title);
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
            child: Text('Cancel',
                style: kStyleBody.copyWith(color: kColorInkSoft)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _snack('Rename coming soon.');
            },
            child: Text('Rename',
                style: kStyleBodyMedium.copyWith(color: kColorPrimary)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kColorPaper,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusLg),
        title: Text('Delete document?', style: kStyleBodySemibold),
        content: Text(
          'This will permanently remove "${widget.doc.title}" from your trip.',
          style: kStyleBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: kStyleBody.copyWith(color: kColorInkSoft)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onDelete?.call();
              if (context.mounted) Navigator.maybePop(context);
            },
            child: Text('Delete',
                style: kStyleBodyMedium.copyWith(color: kColorDanger)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.doc.storagePath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace3),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: [
            WabwayButton(
              label: _openLoading ? 'Opening…' : 'Open',
              icon: Icons.open_in_new_rounded,
              size: WabwayButtonSize.sm,
              loading: _openLoading,
              onPressed: hasFile ? _openFile : null,
            ),
            WabwayButton(
              label: 'Download',
              icon: Icons.download_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: hasFile ? _openFile : null,
            ),
            WabwayButton(
              label: 'Rename',
              icon: Icons.edit_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: _showRenameDialog,
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
              label: 'Delete',
              icon: Icons.delete_outline_rounded,
              variant: WabwayButtonVariant.danger,
              size: WabwayButtonSize.sm,
              onPressed: _confirmDelete,
            ),
          ],
        ),
      ],
    );
  }
}

// ── Mobile actions bottom sheet ───────────────────────────────────────────────

void _showActionsSheet(
  BuildContext context, {
  required TripDocument doc,
  VoidCallback? onDelete,
}) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: kColorPaper,
    shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
    builder: (ctx) => _ActionsSheetContent(
      context: context,
      doc: doc,
      onDelete: onDelete,
    ),
  );
}

class _ActionsSheetContent extends StatefulWidget {
  const _ActionsSheetContent({
    required this.context,
    required this.doc,
    this.onDelete,
  });

  final BuildContext context;
  final TripDocument doc;
  final VoidCallback? onDelete;

  @override
  State<_ActionsSheetContent> createState() => _ActionsSheetContentState();
}

class _ActionsSheetContentState extends State<_ActionsSheetContent> {
  bool _openLoading = false;

  Future<void> _openFile() async {
    if (widget.doc.storagePath == null) return;
    setState(() => _openLoading = true);
    Navigator.pop(context);
    try {
      final url = await DocService.getSignedUrl(widget.doc.storagePath!);
      if (url == null) return;
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    if (mounted) setState(() => _openLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final hasFile = widget.doc.storagePath != null;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const WabwayDragHandle(),
          if (hasFile)
            WabwayActionTile(
              icon: Icons.open_in_new_rounded,
              label: _openLoading ? 'Opening…' : 'Open',
              onTap: _openFile,
            ),
          if (hasFile)
            WabwayActionTile(
              icon: Icons.download_rounded,
              label: 'Download',
              onTap: _openFile,
            ),
          WabwayActionTile(
            icon: Icons.edit_rounded,
            label: 'Rename',
            onTap: () => Navigator.pop(context),
          ),
          WabwayActionTile(
            icon: Icons.receipt_long_rounded,
            label: 'Create Receipt from document',
            onTap: () async {
              Navigator.pop(context);
              await showAddReceiptSheet(widget.context);
            },
          ),
          WabwayActionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: kColorDanger,
            onTap: () {
              Navigator.pop(context);
              widget.onDelete?.call();
              Navigator.maybePop(widget.context);
            },
          ),
          const SizedBox(height: kSpace4),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

String _fmtDateFull(DateTime d) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}
