import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ocr/gemini_parser.dart';
import '../../core/ocr/itinerary_scanner.dart';
import '../../core/supabase/client.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/money_service.dart';
import '../../core/supabase/plan_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../core/supabase/travel_service.dart';
import '../../core/trip/trip_state.dart';
import '../../data/docs_data.dart';
import '../../data/money_data.dart';
import '../../data/plan_data.dart';
import '../../data/spot_data.dart';
import '../../data/travel_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import '../share/parsed_itinerary_screen.dart';

// ─── Entry point ──────────────────────────────────────────────────────────────

Future<void> showImportSheet(BuildContext context) {
  final tripId = TripState.tripOf(context).id;
  final userId = supabase.auth.currentUser?.id ?? '';

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ImportSheet(tripId: tripId, userId: userId),
  );
}

// ─── Destination types ────────────────────────────────────────────────────────

enum _Dest { document, spot, travel, plan, receipt }

extension _DestLabel on _Dest {
  String get label => switch (this) {
        _Dest.document => 'Document',
        _Dest.spot     => 'Spot',
        _Dest.travel   => 'Travel',
        _Dest.plan     => 'Plan item',
        _Dest.receipt  => 'Receipt',
      };
  IconData get icon => switch (this) {
        _Dest.document => Icons.insert_drive_file_rounded,
        _Dest.spot     => Icons.place_rounded,
        _Dest.travel   => Icons.flight_rounded,
        _Dest.plan     => Icons.event_note_rounded,
        _Dest.receipt  => Icons.receipt_long_rounded,
      };
}

// ─── Sheet shell ──────────────────────────────────────────────────────────────

class _ImportSheet extends StatelessWidget {
  const _ImportSheet({required this.tripId, required this.userId});
  final String tripId;
  final String userId;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, ctrl) => DecoratedBox(
        decoration: const BoxDecoration(
          color: kColorPaper,
          borderRadius: kRadiusSheet,
        ),
        child: _ImportContent(
          tripId:     tripId,
          userId:     userId,
          scrollCtrl: ctrl,
        ),
      ),
    );
  }
}

// ─── Main content (2-step) ────────────────────────────────────────────────────

class _ImportContent extends StatefulWidget {
  const _ImportContent({
    required this.tripId,
    required this.userId,
    required this.scrollCtrl,
  });
  final String tripId;
  final String userId;
  final ScrollController scrollCtrl;

  @override
  State<_ImportContent> createState() => _ImportContentState();
}

class _ImportContentState extends State<_ImportContent> {
  // ── Steps ──────────────────────────────────────────────────────────────────
  bool _onDetailsStep = false;

  // ── Source ────────────────────────────────────────────────────────────────
  Uint8List? _fileBytes;
  String?    _fileName;
  String?    _fileExt;
  int?       _fileSizeKb;
  bool       _sourceIsLink = false;
  final _linkCtrl = TextEditingController();

  // ── Shared fields ─────────────────────────────────────────────────────────
  final _titleCtrl  = TextEditingController();
  final _notesCtrl  = TextEditingController();

  // ── Destination ───────────────────────────────────────────────────────────
  _Dest _dest = _Dest.document;

  // ── Document fields ───────────────────────────────────────────────────────
  DocType _docType = DocType.other;

  // ── Spot fields ───────────────────────────────────────────────────────────
  final _cityCtrl    = TextEditingController();
  final _mapsUrlCtrl = TextEditingController();
  SpotCategory _spotCat    = SpotCategory.landmark;
  SpotStatus   _spotStatus = SpotStatus.wantToGo;

  // ── Travel fields ─────────────────────────────────────────────────────────
  TravelItemType _travelType = TravelItemType.flight;

  // ── Plan fields ───────────────────────────────────────────────────────────
  ItineraryItemType _planType   = ItineraryItemType.activity;
  List<TripDay>     _days       = [];
  TripDay?          _selectedDay;
  bool              _daysLoading = false;

  // ── Receipt fields ────────────────────────────────────────────────────────
  final _amountCtrl   = TextEditingController();
  final _currencyCtrl = TextEditingController(text: 'USD');
  ReceiptCategory _receiptCat = ReceiptCategory.other;

  // ── OCR / itinerary parsing ───────────────────────────────────────────────
  bool _scanningAi  = false;
  bool _scanningOcr = false;

  bool get _anyScan => _scanningAi || _scanningOcr;

  // ── Submit ────────────────────────────────────────────────────────────────
  bool    _submitting = false;
  String? _error;

  @override
  void dispose() {
    _linkCtrl.dispose();
    _titleCtrl.dispose();
    _notesCtrl.dispose();
    _cityCtrl.dispose();
    _mapsUrlCtrl.dispose();
    _amountCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  // ── Source picking ────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx', 'xlsx', 'webp', 'heic'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    _applyFileSource(
      bytes:   f.bytes!,
      name:    f.name,
      ext:     f.extension?.toLowerCase(),
      sizeKb:  (f.size / 1024).round(),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final ext   = picked.path.split('.').last.toLowerCase();
    _applyFileSource(
      bytes:  bytes,
      name:   picked.name,
      ext:    ext.isEmpty ? 'jpg' : ext,
      sizeKb: (bytes.lengthInBytes / 1024).round(),
    );
  }

  void _applyFileSource({
    required Uint8List bytes,
    required String name,
    String? ext,
    int? sizeKb,
  }) {
    final nameWithoutExt = name.replaceAll(RegExp(r'\.[^.]+$'), '');
    setState(() {
      _fileBytes    = bytes;
      _fileName     = name;
      _fileExt      = ext;
      _fileSizeKb   = sizeKb;
      _sourceIsLink = false;
      if (_titleCtrl.text.isEmpty) _titleCtrl.text = nameWithoutExt;
      _docType = _docTypeFromExt(ext);
      _onDetailsStep = true;
    });

  }

  static bool _isScannable(String? ext) {
    const exts = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'bmp', 'pdf'};
    return exts.contains(ext?.toLowerCase());
  }

  Future<void> _parseWithAi() async {
    final bytes = _fileBytes;
    final ext   = _fileExt ?? 'jpg';
    if (bytes == null || _anyScan) return;
    setState(() => _scanningAi = true);
    try {
      final result = await ItineraryScanner.scanWithAi(bytes, ext);
      if (!mounted) return;
      if (result.bookings.isEmpty) {
        final aiStatus = GeminiParser.lastHttpStatus;
        final msg = switch (aiStatus) {
          429  => 'AI quota exceeded — try "Read text / PDF" instead',
          0    => 'No AI key configured',
          200  => 'AI read the file but found no bookings — try OCR',
          _    => 'AI failed (HTTP $aiStatus) — try OCR instead',
        };
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
        return;
      }
      await _pushResults(result);
    } finally {
      if (mounted) setState(() => _scanningAi = false);
    }
  }

  Future<void> _parseWithOcr() async {
    final bytes = _fileBytes;
    final ext   = _fileExt ?? 'jpg';
    if (bytes == null || _anyScan) return;
    setState(() => _scanningOcr = true);
    try {
      final result = await ItineraryScanner.scanWithOcr(bytes, ext);
      if (!mounted) return;
      if (result.bookings.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No booking patterns found — fill in manually'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ));
        return;
      }
      await _pushResults(result);
    } finally {
      if (mounted) setState(() => _scanningOcr = false);
    }
  }

  Future<void> _pushResults(ScanResult result) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => ParsedItineraryScreen(
          bookings:       result.bookings,
          tripId:         widget.tripId,
          userId:         widget.userId,
          sourceBytes:    _fileBytes,
          sourceExt:      _fileExt,
          sourceFileName: _fileName,
          onDone:   () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _applyLinkSource() {
    final url = _linkCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _sourceIsLink = true;
      if (_titleCtrl.text.isEmpty) _titleCtrl.text = _titleFromUrl(url);
      // Auto-suggest spot if Maps link
      if (_isMapsUrl(url)) {
        _dest = _Dest.spot;
        _mapsUrlCtrl.text = url;
      }
      _onDetailsStep = true;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static bool _isMapsUrl(String url) =>
      url.contains('google.com/maps') ||
      url.contains('maps.app.goo.gl') ||
      url.contains('goo.gl/maps');

  static String _titleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceAll('www.', '');
      return host.isNotEmpty ? host : url;
    } catch (_) {
      return url.length > 40 ? url.substring(0, 40) : url;
    }
  }

  static DocType _docTypeFromExt(String? ext) => switch (ext) {
        'pdf'                         => DocType.other,
        'jpg' || 'jpeg' || 'png' ||
        'heic' || 'webp'              => DocType.screenshot,
        _                             => DocType.other,
      };

  // ── Load plan days ────────────────────────────────────────────────────────

  Future<void> _loadDays() async {
    if (_days.isNotEmpty || _daysLoading) return;
    setState(() => _daysLoading = true);
    try {
      final days = await PlanService.loadAll(widget.tripId);
      if (!mounted) return;
      setState(() {
        _days        = days;
        _selectedDay = days.isNotEmpty ? days.first : null;
        _daysLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _daysLoading = false);
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a title.');
      return;
    }
    if (_dest == _Dest.receipt) {
      final amt = double.tryParse(_amountCtrl.text.trim());
      if (amt == null || amt <= 0) {
        setState(() => _error = 'Enter a valid amount.');
        return;
      }
    }
    if (_dest == _Dest.plan && _selectedDay == null) {
      setState(() => _error = 'Select an itinerary day.');
      return;
    }

    setState(() { _submitting = true; _error = null; });

    try {
      // 1. Upload file/image if present
      TripDocument? doc;
      if (_fileBytes != null) {
        doc = await DocService.uploadAndCreate(
          tripId:     widget.tripId,
          userId:     widget.userId,
          title:      title,
          type:       _dest == _Dest.document ? _docType : DocType.receipt,
          ext:        _fileExt ?? 'jpg',
          bytes:      _fileBytes!,
          fileSizeKb: _fileSizeKb ?? 0,
        );
      }

      // 2. Create entity + link
      switch (_dest) {
        case _Dest.document:
          // Already uploaded above. If link-only, create a no-file doc record.
          if (doc == null && _sourceIsLink) {
            await _createLinkDoc(title);
          }

        case _Dest.spot:
          final spot = await SpotService.createSpot(
            tripId:   widget.tripId,
            name:     title,
            city:     _cityCtrl.text.trim().isEmpty ? 'Unknown' : _cityCtrl.text.trim(),
            area:     '',
            category: _spotCat,
            status:   _spotStatus,
            addedBy:  widget.userId,
            mapsUrl:  _mapsUrlCtrl.text.trim().isEmpty ? null : _mapsUrlCtrl.text.trim(),
            sourceUrl: _sourceIsLink ? _linkCtrl.text.trim() : null,
            notes:    _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
          if (doc != null) {
            await DocService.addLink(
              documentId: doc.id,
              linkedType: DocLinkedType.spot,
              linkedId:   spot.id,
              createdBy:  widget.userId,
            );
          }

        case _Dest.travel:
          await TravelService.createItem(
            tripId:      widget.tripId,
            title:       title,
            type:        _travelType,
            createdBy:   widget.userId,
            notes:       _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            linkedDocIds: doc != null ? [doc.id] : [],
          );

        case _Dest.plan:
          await PlanService.createItem(
            tripId:      widget.tripId,
            dayId:       _selectedDay!.id,
            title:       title,
            type:        _planType,
            createdBy:   widget.userId,
            notes:       _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
            linkedDocIds: doc != null ? [doc.id] : [],
          );

        case _Dest.receipt:
          final amount   = double.parse(_amountCtrl.text.trim());
          final currency = _currencyCtrl.text.trim().toUpperCase();
          final receipt  = await MoneyService.createReceipt(
            tripId:   widget.tripId,
            paidBy:   widget.userId,
            title:    title,
            amount:   amount,
            currency: currency.isEmpty ? 'USD' : currency,
            category: _receiptCat,
            date:     DateTime.now(),
            splits:   [ReceiptSplit(memberId: widget.userId, amount: amount, isSettled: false)],
            notes:    _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
          if (doc != null) {
            await DocService.addLink(
              documentId: doc.id,
              linkedType: DocLinkedType.receipt,
              linkedId:   receipt.id,
              createdBy:  widget.userId,
            );
          }
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Imported "$title"',
            style: kStyleBody.copyWith(color: Colors.white)),
        backgroundColor: kColorSuccess,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  Future<void> _createLinkDoc(String title) async {
    // For link-only imports going to Document: save as a no-file document
    // (title + source URL in notes). No upload needed.
    await supabase.from('documents').insert({
      'trip_id':    widget.tripId,
      'created_by': widget.userId,
      'title':      title,
      'type':       'other',
      'notes':      _linkCtrl.text.trim(),
    });
  }

  // ── Image source sheet ────────────────────────────────────────────────────

  void _showImageSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: kColorPaper,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusSheet),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(kSpace4, kSpace3, kSpace4, kSpace6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const WabwayDragHandle(),
            const SizedBox(height: kSpace3),
            Text('Add photo', style: kStyleTitle),
            const SizedBox(height: kSpace4),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: kColorInkSoft),
              title: Text('Take photo', style: kStyleBodyMedium),
              onTap: () => _pickImage(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: kColorInkSoft),
              title: Text('Choose from gallery', style: kStyleBodyMedium),
              onTap: () => _pickImage(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final keyboardPad = MediaQuery.viewInsetsOf(context).bottom;
    final navBarPad   = MediaQuery.paddingOf(context).bottom;

    return Column(
      children: [
        // ── Scrollable body ──────────────────────────────────────────────
        Expanded(
          child: CustomScrollView(
            controller: widget.scrollCtrl,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                      kSpace4, kSpace3, kSpace4, keyboardPad > 0 ? keyboardPad : kSpace2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const WabwayDragHandle(),
                      const SizedBox(height: kSpace3),
                      Row(
                        children: [
                          if (_onDetailsStep)
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded),
                              color: kColorInkSoft,
                              onPressed: () => setState(() {
                                _onDetailsStep = false;
                                _fileBytes = null;
                                _fileName  = null;
                                _fileExt   = null;
                                _sourceIsLink = false;
                                _error = null;
                              }),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            )
                          else
                            const SizedBox(width: 4),
                          const SizedBox(width: kSpace2),
                          Text(
                            _onDetailsStep ? 'Import details' : 'Import',
                            style: kStyleTitle,
                          ),
                          const Spacer(),
                          WabwayIconButton(
                            icon: Icons.close_rounded,
                            label: 'Close',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: kSpace5),
                      if (!_onDetailsStep) _buildSourceStep(),
                      if (_onDetailsStep)  _buildDetailsStep(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── Sticky footer ─────────────────────────────────────────────────
        if (_onDetailsStep)
          Padding(
            padding: EdgeInsets.fromLTRB(
                kSpace4, kSpace3, kSpace4, kSpace4 + navBarPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  Text(_error!, style: kStyleCaption.copyWith(color: kColorDanger)),
                  const SizedBox(height: kSpace2),
                ],
                WabwayButton(
                  label: 'Import',
                  icon: Icons.download_rounded,
                  fullWidth: true,
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ── Step 1: Source ────────────────────────────────────────────────────────

  Widget _buildSourceStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What are you importing?', style: kStyleBodyMedium.copyWith(color: kColorInkSoft)),
        const SizedBox(height: kSpace4),

        // File / photo options
        _SourceTile(
          icon:  Icons.upload_file_rounded,
          label: 'Pick a file',
          sub:   'PDF, image, or document',
          onTap: _pickFile,
        ),
        const SizedBox(height: kSpace2),
        _SourceTile(
          icon:  Icons.add_photo_alternate_rounded,
          label: 'Add a photo',
          sub:   'Camera or gallery',
          onTap: _showImageSourceSheet,
        ),

        const SizedBox(height: kSpace5),
        const Row(children: [
          Expanded(child: Divider()),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: kSpace3),
            child: Text('or paste a link', style: TextStyle(fontSize: 12, color: kColorInkSoft)),
          ),
          Expanded(child: Divider()),
        ]),
        const SizedBox(height: kSpace4),

        WabwayTextField(
          label: 'URL or link',
          hint:  'https://…',
          controller: _linkCtrl,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _applyLinkSource(),
        ),
        const SizedBox(height: kSpace3),
        WabwayButton(
          label: 'Continue with link',
          variant: WabwayButtonVariant.secondary,
          fullWidth: true,
          onPressed: _applyLinkSource,
        ),
      ],
    );
  }

  // ── Step 2: Details ───────────────────────────────────────────────────────

  Widget _buildDetailsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Source preview
        _SourcePreview(
          fileName:   _fileName,
          fileExt:    _fileExt,
          fileSizeKb: _fileSizeKb,
          link:       _sourceIsLink ? _linkCtrl.text.trim() : null,
        ),
        const SizedBox(height: kSpace3),

        // Itinerary parse buttons (only for scannable files)
        if (!kIsWeb && _isScannable(_fileExt)) ...[
          if (GeminiParser.isAvailable)
            _OcrBanner(
              icon:     Icons.auto_awesome_rounded,
              label:    'Parse with AI',
              subtitle: 'Reads flights, hotels & trains via Gemini',
              loading:  _scanningAi,
              disabled: _anyScan,
              onTap:    _parseWithAi,
            ),
          if (GeminiParser.isAvailable) const SizedBox(height: kSpace2),
          _OcrBanner(
            icon:     Icons.document_scanner_rounded,
            label:    'Read text / PDF',
            subtitle: 'On-device OCR · no AI required',
            loading:  _scanningOcr,
            disabled: _anyScan,
            onTap:    _parseWithOcr,
          ),
          const SizedBox(height: kSpace4),
        ],

        // Destination type
        Text('Save as', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace3),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _Dest.values.map((d) => Padding(
              padding: const EdgeInsets.only(right: kSpace2),
              child: _DestChip(
                dest:     d,
                selected: _dest == d,
                onTap: () {
                  setState(() => _dest = d);
                  if (d == _Dest.plan) _loadDays();
                },
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: kSpace5),

        // Shared title
        WabwayTextField(
          label: 'Title',
          hint:  'Name this import',
          controller: _titleCtrl,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: kSpace4),

        // Type-specific fields
        ..._buildSubForm(),

        // Notes (shared)
        const SizedBox(height: kSpace4),
        WabwayTextField(
          label:      'Notes (optional)',
          hint:       'Any extra details',
          controller: _notesCtrl,
          maxLines:   3,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: kSpace8),
      ],
    );
  }

  List<Widget> _buildSubForm() {
    return switch (_dest) {
      _Dest.document => _docSubForm(),
      _Dest.spot     => _spotSubForm(),
      _Dest.travel   => _travelSubForm(),
      _Dest.plan     => _planSubForm(),
      _Dest.receipt  => _receiptSubForm(),
    };
  }

  List<Widget> _docSubForm() => [
    Text('Document type', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
    const SizedBox(height: kSpace3),
    _chipGrid(
      values:   DocType.values,
      selected: _docType,
      label:    (t) => t.label,
      onTap:    (t) => setState(() => _docType = t),
    ),
  ];

  List<Widget> _spotSubForm() => [
    WabwayTextField(
      label: 'City (optional)',
      hint:  'e.g. Tokyo',
      controller: _cityCtrl,
      textInputAction: TextInputAction.next,
    ),
    const SizedBox(height: kSpace4),
    if (_isMapsUrl(_mapsUrlCtrl.text) || _mapsUrlCtrl.text.isNotEmpty) ...[
      WabwayTextField(
        label: 'Google Maps URL',
        hint:  'https://maps.google.com/…',
        controller: _mapsUrlCtrl,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: kSpace4),
    ] else if (_sourceIsLink) ...[
      WabwayTextField(
        label: 'Google Maps URL (optional)',
        hint:  'https://maps.google.com/…',
        controller: _mapsUrlCtrl,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: kSpace4),
    ],
    Text('Category', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
    const SizedBox(height: kSpace3),
    _chipGrid(
      values:   SpotCategory.values,
      selected: _spotCat,
      label:    (c) => c.label,
      onTap:    (c) => setState(() => _spotCat = c),
    ),
    const SizedBox(height: kSpace4),
    Text('Status', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
    const SizedBox(height: kSpace3),
    _chipGrid(
      values:   SpotStatus.values,
      selected: _spotStatus,
      label:    (s) => s.label,
      onTap:    (s) => setState(() => _spotStatus = s),
    ),
  ];

  List<Widget> _travelSubForm() => [
    Text('Type', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
    const SizedBox(height: kSpace3),
    _chipGrid(
      values:   TravelItemType.values,
      selected: _travelType,
      label:    (t) => t.label,
      onTap:    (t) => setState(() => _travelType = t),
    ),
  ];

  List<Widget> _planSubForm() {
    if (_daysLoading) {
      return [
        const Center(child: Padding(
          padding: EdgeInsets.symmetric(vertical: kSpace4),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(kColorPrimary),
          ),
        )),
      ];
    }
    if (_days.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.all(kSpace4),
          decoration: BoxDecoration(
            color: kColorSurfaceSunken,
            borderRadius: kRadiusMd,
            border: Border.all(color: kColorBorder),
          ),
          child: Text(
            'No itinerary days yet. Add a day in the Plan tab first.',
            style: kStyleCaption,
          ),
        ),
      ];
    }
    return [
      Text('Itinerary day', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
      const SizedBox(height: kSpace3),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3),
        decoration: BoxDecoration(
          color:        kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border:       Border.all(color: kColorBorder),
        ),
        child: DropdownButton<TripDay>(
          value:        _selectedDay,
          isExpanded:   true,
          underline:    const SizedBox.shrink(),
          style:        kStyleBodyMedium,
          items: _days.map((d) => DropdownMenuItem(
            value: d,
            child: Text('Day ${d.dayNumber} – ${d.city}', style: kStyleBodyMedium),
          )).toList(),
          onChanged: (d) => setState(() => _selectedDay = d),
        ),
      ),
      const SizedBox(height: kSpace4),
      Text('Type', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
      const SizedBox(height: kSpace3),
      _chipGrid(
        values:   ItineraryItemType.values,
        selected: _planType,
        label:    (t) => t.label,
        onTap:    (t) => setState(() => _planType = t),
      ),
    ];
  }

  List<Widget> _receiptSubForm() => [
    Row(
      children: [
        Expanded(
          flex: 3,
          child: WabwayTextField(
            label: 'Amount',
            hint:  '0.00',
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
          ),
        ),
        const SizedBox(width: kSpace3),
        Expanded(
          flex: 2,
          child: WabwayTextField(
            label: 'Currency',
            hint:  'USD',
            controller: _currencyCtrl,
            textInputAction: TextInputAction.next,
          ),
        ),
      ],
    ),
    const SizedBox(height: kSpace4),
    Text('Category', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
    const SizedBox(height: kSpace3),
    _chipGrid(
      values:   ReceiptCategory.values,
      selected: _receiptCat,
      label:    (c) => c.label,
      onTap:    (c) => setState(() => _receiptCat = c),
    ),
  ];

  // ── Generic chip grid helper ──────────────────────────────────────────────

  Widget _chipGrid<T>({
    required List<T> values,
    required T selected,
    required String Function(T) label,
    required void Function(T) onTap,
  }) {
    return Wrap(
      spacing: kSpace2,
      runSpacing: kSpace2,
      children: values.map((v) {
        final isSelected = v == selected;
        return GestureDetector(
          onTap: () => onTap(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
            decoration: BoxDecoration(
              color:        isSelected ? kColorPrimary : kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border:       Border.all(
                color: isSelected ? kColorPrimary : kColorBorder,
              ),
            ),
            child: Text(
              label(v),
              style: kStyleBodyMedium.copyWith(
                color:      isSelected ? kColorTextOnPrimary : kColorInk,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Source tile ──────────────────────────────────────────────────────────────

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String   label;
  final String   sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: kRadiusMd,
      child: Container(
        padding: const EdgeInsets.all(kSpace4),
        decoration: BoxDecoration(
          color:        kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border:       Border.all(color: kColorBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(kSpace2),
              decoration: const BoxDecoration(
                color:        kColorPrimarySoft,
                borderRadius: kRadiusMd,
              ),
              child: Icon(icon, size: 20, color: kColorPrimary),
            ),
            const SizedBox(width: kSpace3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: kStyleBodyMedium),
                Text(sub,   style: kStyleCaption),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, color: kColorInkSoft),
          ],
        ),
      ),
    );
  }
}

// ─── Source preview ───────────────────────────────────────────────────────────

class _SourcePreview extends StatelessWidget {
  const _SourcePreview({this.fileName, this.fileExt, this.fileSizeKb, this.link});
  final String? fileName;
  final String? fileExt;
  final int?    fileSizeKb;
  final String? link;

  @override
  Widget build(BuildContext context) {
    final isFile = fileName != null;
    final label  = isFile ? fileName! : (link ?? '');
    final sub    = isFile
        ? '${fileExt?.toUpperCase() ?? 'File'}  ·  ${fileSizeKb != null ? '${fileSizeKb}KB' : ''}'
        : 'Link';

    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color:        kColorSurfaceSunken,
        borderRadius: kRadiusMd,
        border:       Border.all(color: kColorBorder),
      ),
      child: Row(
        children: [
          Icon(
            isFile ? Icons.insert_drive_file_rounded : Icons.link_rounded,
            size: 20,
            color: kColorInkSoft,
          ),
          const SizedBox(width: kSpace3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: kStyleBodyMedium,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(sub, style: kStyleCaption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── OCR banner ───────────────────────────────────────────────────────────────

class _OcrBanner extends StatelessWidget {
  const _OcrBanner({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.loading,
    required this.disabled,
    required this.onTap,
  });

  final IconData     icon;
  final String       label;
  final String       subtitle;
  final bool         loading;
  final bool         disabled;
  final VoidCallback onTap;

  static const _blue = Color(0xFF4A7AB5);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled && !loading ? 0.45 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(kSpace3),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EEF6),
            borderRadius: kRadiusMd,
            border: Border.all(color: _blue.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.15),
                  borderRadius: kRadiusSm,
                ),
                child: loading
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
                      )
                    : Icon(icon, size: 18, color: _blue),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loading ? 'Scanning…' : label,
                      style: kStyleBodyMedium.copyWith(color: _blue),
                    ),
                    Text(subtitle,
                        style: kStyleCaption.copyWith(color: kColorInkSoft)),
                  ],
                ),
              ),
              if (!loading)
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _blue),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Destination chip ─────────────────────────────────────────────────────────

class _DestChip extends StatelessWidget {
  const _DestChip({required this.dest, required this.selected, required this.onTap});
  final _Dest dest;
  final bool  selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
        decoration: BoxDecoration(
          color:        selected ? kColorPrimary : kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border:       Border.all(
            color: selected ? kColorPrimary : kColorBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(dest.icon, size: 14,
                color: selected ? kColorTextOnPrimary : kColorInkSoft),
            const SizedBox(width: kSpace1),
            Text(
              dest.label,
              style: kStyleBodyMedium.copyWith(
                color:      selected ? kColorTextOnPrimary : kColorInk,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
