import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../core/share/file_type_registry.dart';
import '../../core/supabase/doc_service.dart';
import '../../data/connection_data.dart';
import '../../data/docs_data.dart';
import '../../data/spot_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import '../../data/share_data.dart';

Future<TripDocument?> showAddDocSheet(
  BuildContext context, {
  required String tripId,
  required String tripName,
  required String userId,
  required List<Spot> availableSpots,
  ImportPrefill? prefill,
  DocType? initialType,
  String? attachingTo,
}) {
  return showWabwayFormSheet<TripDocument>(
    context,
    desktopHeightFactor: 0.90,
    initialChildSize: 0.92,
    minChildSize: 0.5,
    maxChildSize: 0.97,
    builder: (ctx, scroll, handle, close) => _AddDocContent(
      tripId: tripId,
      tripName: tripName,
      userId: userId,
      availableSpots: availableSpots,
      prefill: prefill,
      initialType: initialType,
      attachingTo: attachingTo,
      scrollController: scroll,
      showDragHandle: handle,
      onSubmit: close,
    ),
  );
}

class _AddDocContent extends StatefulWidget {
  const _AddDocContent({
    required this.tripId,
    required this.tripName,
    required this.userId,
    required this.availableSpots,
    required this.onSubmit,
    this.prefill,
    this.initialType,
    this.attachingTo,
    this.scrollController,
    this.showDragHandle = false,
  });

  final String tripId;
  final String tripName;
  final String userId;
  final List<Spot> availableSpots;
  final ValueChanged<TripDocument> onSubmit;
  final ImportPrefill? prefill;
  final DocType? initialType;

  /// Name of the item this document will be attached to (set by
  /// AttachedDocsSection, which does the attaching) — replaces "Link to".
  final String? attachingTo;
  final ScrollController? scrollController;
  final bool showDragHandle;

  @override
  State<_AddDocContent> createState() => _AddDocContentState();
}

class _AddDocContentState extends State<_AddDocContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  DocType _type = DocType.other;
  DocLinkedType? _linkType;
  String? _linkedId;

  Uint8List? _fileBytes;
  String? _fileName;
  String? _fileExt;
  int? _fileSizeKb;

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialType != null) _type = widget.initialType!;
    final pre = widget.prefill;
    if (pre != null) {
      _titleCtrl.text = pre.title ?? '';
      _notesCtrl.text = pre.notes ?? '';
      _urlCtrl.text = pre.url ?? '';
      if (pre.fileBytes != null) {
        _fileBytes  = pre.fileBytes;
        _fileName   = pre.fileName;
        _fileExt    = pre.fileExt?.toLowerCase();
        _fileSizeKb = (pre.fileBytes!.length / 1024).round();
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: FileTypeRegistry.docExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    setState(() {
      _fileBytes = file.bytes;
      _fileName = file.name;
      _fileExt = file.extension?.toLowerCase();
      _fileSizeKb = (file.size / 1024).round();
      // Auto-fill title from filename if still empty
      if (_titleCtrl.text.isEmpty && file.name.isNotEmpty) {
        _titleCtrl.text = file.name.replaceAll(RegExp(r'\.[^.]+$'), '');
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final ext = (_fileExt ?? 'pdf').toLowerCase();
      final TripDocument doc;

      if (_fileBytes != null) {
        // Safe ordered flow: UUID generated → file uploaded → row inserted.
        // If row insert fails, the service cleans up the orphaned storage file.
        doc = await DocService.uploadAndCreate(
          tripId:     widget.tripId,
          userId:     widget.userId,
          title:      _titleCtrl.text.trim(),
          type:       _type,
          ext:        ext,
          bytes:      _fileBytes!,
          fileSizeKb: _fileSizeKb,
          notes:      _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          url:        _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
        );
      } else {
        doc = await DocService.createDocument(
          tripId: widget.tripId,
          userId: widget.userId,
          title:  _titleCtrl.text.trim(),
          type:   _type,
          ext:    ext,
          notes:  _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          url:    _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
        );
      }

      if (_linkType == DocLinkedType.spot && _linkedId != null) {
        await DocService.attach(
          tripId:     widget.tripId,
          userId:     widget.userId,
          docIds:     [doc.id],
          entityType: EntityType.spot,
          entityId:   _linkedId!,
        );
      }

      if (mounted) widget.onSubmit(doc);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not save document. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPad = MediaQuery.viewInsetsOf(context).bottom;
    final navBarPad = MediaQuery.paddingOf(context).bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showDragHandle) const WabwayDragHandle(),

        Padding(
          padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, 0),
          child: Row(
            children: [
              Text('Add document', style: kStyleTitle),
              const Spacer(),
              WabwayIconButton(
                icon: Icons.close_rounded,
                label: 'Cancel',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: kSpace5),

        Flexible(
          child: SingleChildScrollView(
            controller: widget.scrollController,
            padding: EdgeInsets.fromLTRB(kSpace4, 0, kSpace4, kSpace4 + keyboardPad),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  WabwayTextField(
                    label: 'Title',
                    hint: 'e.g. Flight confirmation',
                    controller: _titleCtrl,
                    textInputAction: TextInputAction.next,
                    validator: (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Title is required'
                            : null,
                  ),
                  const SizedBox(height: kSpace4),

                  WabwaySelectField<DocType>(
                    label: 'Document type',
                    value: _type,
                    onChanged: (v) =>
                        setState(() => _type = v ?? DocType.other),
                    items: DocType.values
                        .map((t) => WabwaySelectItem(value: t, label: t.label))
                        .toList(),
                  ),
                  const SizedBox(height: kSpace4),

                  _FileUploadZone(
                    fileName: _fileName,
                    fileSizeKb: _fileSizeKb,
                    onTap: _pickFile,
                  ),
                  const SizedBox(height: kSpace4),

                  if (widget.attachingTo != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(kSpace3),
                      decoration: const BoxDecoration(
                        color: kColorSurfaceSunken,
                        borderRadius: kRadiusMd,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.attach_file_rounded,
                              size: 16, color: kColorInkSoft),
                          const SizedBox(width: kSpace2),
                          Expanded(
                            child: Text('Attaching to ${widget.attachingTo}',
                                style: kStyleBodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    )
                  else
                  _LinkSection(
                    linkType: _linkType,
                    linkedId: _linkedId,
                    availableSpots: widget.availableSpots,
                    tripName: widget.tripName,
                    onLinkTypeChanged: (t) => setState(() {
                      _linkType = t;
                      _linkedId = null;
                    }),
                    onLinkItemChanged: (id) => setState(() => _linkedId = id),
                  ),
                  const SizedBox(height: kSpace4),

                  WabwayTextField(
                    label: 'Link (optional)',
                    hint: 'Booking or confirmation page',
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: kSpace4),
                  WabwayTextField(
                    label: 'Notes (optional)',
                    hint: 'Optional notes…',
                    controller: _notesCtrl,
                    maxLines: 3,
                    textInputAction: TextInputAction.newline,
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: kSpace3),
                    Text(_error!,
                        style: kStyleCaption.copyWith(color: kColorDanger)),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Sticky footer — always visible above nav bar
        Padding(
          padding: EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace4 + navBarPad),
          child: WabwayButton(
            label: 'Add document',
            icon: Icons.insert_drive_file_rounded,
            fullWidth: true,
            size: WabwayButtonSize.lg,
            loading: _loading,
            onPressed: _loading ? null : _submit,
          ),
        ),
      ],
    );
  }
}

// ── File upload zone ──────────────────────────────────────────────────────────

class _FileUploadZone extends StatelessWidget {
  const _FileUploadZone({
    required this.fileName,
    required this.fileSizeKb,
    required this.onTap,
  });

  final String? fileName;
  final int? fileSizeKb;
  final VoidCallback onTap;

  String get _sizeLabel {
    if (fileSizeKb == null) return '';
    if (fileSizeKb! < 1024) return '$fileSizeKb KB';
    return '${(fileSizeKb! / 1024).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final selected = fileName != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('File', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),
        GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: kSpace5),
            decoration: BoxDecoration(
              color: selected ? kColorPrimarySoft : kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border: Border.all(
                color: selected ? kColorPrimary : kColorBorder,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  size: 32,
                  color: selected ? kColorPrimary : kColorInkSoft,
                ),
                const SizedBox(height: kSpace2),
                Text(
                  selected ? fileName! : 'Tap to choose a file',
                  style: kStyleBodyMedium.copyWith(
                    color: selected ? kColorPrimary : kColorInkSoft,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (selected && fileSizeKb != null)
                  Padding(
                    padding: const EdgeInsets.only(top: kSpace1),
                    child: Text(
                      _sizeLabel,
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                    ),
                  )
                else if (!selected)
                  Padding(
                    padding: const EdgeInsets.only(top: kSpace1),
                    child: Text(
                      'PDF, JPG, PNG, DOCX…',
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                    ),
                  ),
                if (selected)
                  Padding(
                    padding: const EdgeInsets.only(top: kSpace2),
                    child: Text(
                      'Tap to change',
                      style: kStyleCaption.copyWith(color: kColorPrimary),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Link section ──────────────────────────────────────────────────────────────

class _LinkSection extends StatelessWidget {
  const _LinkSection({
    required this.linkType,
    required this.linkedId,
    required this.availableSpots,
    required this.tripName,
    required this.onLinkTypeChanged,
    required this.onLinkItemChanged,
  });

  final DocLinkedType? linkType;
  final String? linkedId;
  final List<Spot> availableSpots;
  final String tripName;
  final ValueChanged<DocLinkedType?> onLinkTypeChanged;
  final ValueChanged<String> onLinkItemChanged;

  // Only offer link types that are currently connectable
  // Every document already belongs to the trip, so only spots are offered
  // here; anything else is attached from that item's Documents section.
  static const _supportedLinkTypes = [
    DocLinkedType.spot,
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Link to (optional)',
            style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace2),

        WabwaySelectField<DocLinkedType?>(
          label: 'Link to (optional)',
          value: linkType,
          onChanged: onLinkTypeChanged,
          items: [
            const WabwaySelectItem(value: null, label: 'None'),
            ..._supportedLinkTypes.map(
              (t) => WabwaySelectItem(value: t, label: t.label),
            ),
          ],
        ),

        if (linkType != null) ...[
          const SizedBox(height: kSpace3),
          _buildItemSelector(),
        ],
      ],
    );
  }

  Widget _buildItemSelector() {
    switch (linkType!) {
      case DocLinkedType.trip:
        return Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: const BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
          ),
          child: Row(
            children: [
              const Icon(Icons.luggage_rounded, size: 16, color: kColorInkSoft),
              const SizedBox(width: kSpace2),
              Text(tripName, style: kStyleBodyMedium),
            ],
          ),
        );

      case DocLinkedType.spot:
        if (availableSpots.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(kSpace3),
            decoration: const BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusMd,
            ),
            child: Text('No spots yet — add spots first.',
                style: kStyleCaption),
          );
        }
        return WabwaySelectField<String?>(
          label: 'Spot',
          value: linkedId,
          onChanged: (id) { if (id != null) onLinkItemChanged(id); },
          items: availableSpots
              .map((s) => WabwaySelectItem(value: s.id, label: s.name))
              .toList(),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
