import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/async_screen_mixin.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/doc_service.dart';
import '../../data/connection_data.dart';
import '../../data/docs_data.dart';
import '../../data/share_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import '../docs/add_doc_sheet.dart';
import '../docs/doc_detail.dart';
import '../links/add_link_sheet.dart';

// ─── Attached documents ───────────────────────────────────────────────────────
//
// THE way to attach documents (confirmation PDFs, tickets, ATM slips, booking
// pages…) to anything: travel, stays, plan items, spots, receipts, cash.
// Drop it into a detail screen; it loads, attaches and detaches by itself.
//
//   Attach → Take photo        (phones: camera → the Add document form)
//          → Upload file      (the Add document form, prefilled, then attached)
//          → Choose from Library
//          → Paste link        (the Add link form, saved as a link document)
//   Tap a row → the document's detail page.   × → detach (document is kept).
//
// Storage: trip_connections (doc ↔ entity). See DocService.attach / detach.

class AttachedDocsSection extends ConsumerStatefulWidget {
  const AttachedDocsSection({
    super.key,
    required this.entityType,
    required this.entityId,
    required this.tripId,
    required this.entityName,
    this.title = 'Documents',
    this.uploadType = DocType.other,
    this.emptyText,
    this.onChanged,
  });

  final EntityType entityType;
  final String entityId;
  final String tripId;

  /// Shown in the upload form ("Attaching to …") and used for its default title.
  final String entityName;

  /// Section heading, e.g. 'Documents' or 'ATM slip'.
  final String title;

  /// Document type preselected in the upload form.
  final DocType uploadType;
  final String? emptyText;

  /// Called with the attached document ids after every change (list badges).
  final ValueChanged<List<String>>? onChanged;

  @override
  ConsumerState<AttachedDocsSection> createState() =>
      _AttachedDocsSectionState();
}

class _AttachedDocsSectionState extends ConsumerState<AttachedDocsSection>
    with AsyncScreenMixin {
  List<TripDocument> _docs = [];

  String get _userId => ref.read(profileProvider)?.id ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(AttachedDocsSection old) {
    super.didUpdateWidget(old);
    if (old.entityId != widget.entityId) _load();
  }

  Future<void> _load({bool silent = false}) async {
    final gen = beginLoad(silent: silent);
    try {
      final docs = await DocService.loadAttached(widget.entityId);
      commitLoad(gen, () => _docs = docs);
    } catch (_) {
      failLoad(gen, silent: silent);
    }
  }

  Future<void> _afterChange() async {
    await _load(silent: true);
    widget.onChanged?.call(_docs.map((d) => d.id).toList());
  }

  Future<void> _attach(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    await DocService.attach(
      tripId:     widget.tripId,
      userId:     _userId,
      docIds:     ids,
      entityType: widget.entityType,
      entityId:   widget.entityId,
    );
  }

  // ── Attach menu ─────────────────────────────────────────────────────────────

  Future<void> _showAttachMenu() async {
    final choice = await showWabwayAutoSheet<int>(
      context,
      builder: (ctx, handle) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (handle) const WabwayDragHandle(),
            if (!kIsWeb)
              WabwayActionTile(
                icon: Icons.photo_camera_rounded,
                label: 'Take photo',
                subtitle: 'Snap a slip, ticket or receipt',
                onTap: () => Navigator.pop(ctx, 3),
              ),
            WabwayActionTile(
              icon: Icons.upload_file_rounded,
              label: 'Upload file',
              subtitle: 'PDF, photo or screenshot',
              onTap: () => Navigator.pop(ctx, 0),
            ),
            WabwayActionTile(
              icon: Icons.folder_open_rounded,
              label: 'Choose from Library',
              subtitle: 'A document already in this trip',
              onTap: () => Navigator.pop(ctx, 1),
            ),
            WabwayActionTile(
              icon: Icons.link_rounded,
              label: 'Paste link',
              subtitle: 'Booking or confirmation page',
              onTap: () => Navigator.pop(ctx, 2),
            ),
            const SizedBox(height: kSpace2),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    try {
      switch (choice) {
        case 0: await _upload();
        case 1: await _chooseExisting();
        case 2: await _pasteLink();
        case 3: await _takePhoto();
      }
    } catch (_) {
      if (mounted) {
        showWabwaySnack(context, 'Could not attach. Please try again.', error: true);
      }
    }
  }

  Future<void> _takePhoto() async {
    final shot = await ImagePicker()
        .pickImage(source: ImageSource.camera, imageQuality: 85);
    if (shot == null || !mounted) return;
    final bytes = await shot.readAsBytes();
    final ext = shot.name.contains('.')
        ? shot.name.split('.').last.toLowerCase()
        : 'jpg';
    if (!mounted) return;
    await _upload(ImportPrefill(
      title:     widget.entityName,
      fileBytes: bytes,
      fileName:  shot.name,
      fileExt:   ext,
    ));
  }

  Future<void> _upload([ImportPrefill? prefill]) async {
    final trip = ref.read(activeTripProvider);
    final doc = await showAddDocSheet(
      context,
      tripId:         widget.tripId,
      tripName:       trip?.name ?? '',
      userId:         _userId,
      availableSpots: const [],
      prefill:        prefill ?? ImportPrefill(title: widget.entityName),
      initialType:    widget.uploadType,
      attachingTo:    widget.entityName,
    );
    if (doc == null || !mounted) return;
    await _attach([doc.id]);
    await _afterChange();
    if (mounted) showWabwaySnack(context, 'Attached "${doc.title}".');
  }

  Future<void> _chooseExisting() async {
    final all = await DocService.loadDocuments(widget.tripId);
    if (!mounted) return;
    if (all.isEmpty) {
      showWabwaySnack(context, 'No documents in this trip yet — upload one instead.');
      return;
    }
    final current = _docs.map((d) => d.id).toSet();
    final picked = await showDocAttachSheet(
      context,
      docs: all,
      initialSelectedIds: current,
    );
    if (picked == null || !mounted) return;
    final next = picked.toSet();
    await _attach(next.difference(current));
    await Future.wait(current.difference(next).map(
        (id) => DocService.detach(docId: id, entityId: widget.entityId)));
    await _afterChange();
  }

  Future<void> _pasteLink() async {
    final link = await showAddLinkSheet(
      context,
      tripId:       widget.tripId,
      userId:       _userId,
      prefillTitle: widget.entityName,
    );
    if (link == null || !mounted) return;
    // New links are document rows (build 417), so they attach like any doc.
    if (!link.isDocument) return;
    await _attach([link.id]);
    await _afterChange();
    if (mounted) showWabwaySnack(context, 'Attached "${link.title}".');
  }

  // ── Row actions ─────────────────────────────────────────────────────────────

  Future<void> _detach(TripDocument doc) async {
    final before = _docs;
    setState(() => _docs = _docs.where((d) => d.id != doc.id).toList());
    try {
      await DocService.detach(docId: doc.id, entityId: widget.entityId);
      widget.onChanged?.call(_docs.map((d) => d.id).toList());
      if (mounted) showWabwaySnack(context, 'Removed "${doc.title}" from this item.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _docs = before);
      showWabwaySnack(context, 'Could not remove. Please try again.', error: true);
    }
  }

  Future<void> _deleteDoc(TripDocument doc) async {
    try {
      await DocService.deleteDocument(doc.id);
      if (doc.storagePath != null) {
        try {
          await DocService.deleteStorageFile(doc.storagePath!);
        } catch (_) {}
      }
    } catch (_) {
      if (mounted) showWabwaySnack(context, 'Could not delete document.', error: true);
    }
  }

  Future<void> _open(TripDocument doc) async {
    final trip = ref.read(activeTripProvider);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocDetailScreen(
          doc:      doc,
          tripId:   widget.tripId,
          tripName: trip?.name ?? '',
          onDelete: () => _deleteDoc(doc),
        ),
      ),
    );
    if (mounted) await _afterChange();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(widget.title, style: kStyleCaptionMedium.copyWith(color: kColorInk)),
            const Spacer(),
            WabwayButton(
              label: 'Attach',
              icon: Icons.attach_file_rounded,
              variant: WabwayButtonVariant.ghost,
              size: WabwayButtonSize.sm,
              onPressed: loading ? null : _showAttachMenu,
            ),
          ],
        ),
        const SizedBox(height: kSpace2),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: kSpace3),
            child: Center(
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          )
        else if (offline)
          GestureDetector(
            onTap: _load,
            child: Text('Could not load documents · Tap to retry',
                style: kStyleCaption.copyWith(color: kColorPrimary)),
          )
        else if (_docs.isEmpty)
          Text(
            widget.emptyText ??
                'Nothing attached yet. Attach a confirmation, ticket or booking page.',
            style: kStyleCaption.copyWith(color: kColorInkSoft),
          )
        else
          for (final doc in _docs)
            Padding(
              padding: const EdgeInsets.only(bottom: kSpace2),
              child: _AttachedDocRow(
                doc: doc,
                onTap: () => _open(doc),
                onRemove: () => _detach(doc),
              ),
            ),
      ],
    );
  }
}

class _AttachedDocRow extends StatelessWidget {
  const _AttachedDocRow({
    required this.doc,
    required this.onTap,
    required this.onRemove,
  });
  final TripDocument doc;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isLink = doc.storagePath == null && doc.url != null;
    final subtitle = isLink
        ? (Uri.tryParse(doc.url!)?.host ?? 'Link')
        : '${doc.type.label} · ${doc.ext.toUpperCase()}';
    return WabwayCard(
      hoverable: true,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(kSpace3, kSpace2, kSpace1, kSpace2),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: doc.type.softColor,
              borderRadius: kRadiusMd,
            ),
            child: Icon(isLink ? Icons.link_rounded : doc.type.icon,
                size: 16, color: doc.type.color),
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.title,
                    style: kStyleBodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(subtitle,
                    style: kStyleCaption.copyWith(color: kColorInkSoft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          WabwayIconButton(
            icon: Icons.close_rounded,
            label: 'Remove from this item',
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
