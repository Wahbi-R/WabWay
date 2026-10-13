import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ocr/gemini_parser.dart';
import '../../core/ocr/itinerary_scanner.dart';
import '../../core/places/google_maps_parser.dart';
import '../../core/places/social_place_extractor.dart';
import '../../core/platform/platform_file.dart';
import '../../core/share/file_type_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/profile_provider.dart';
import '../../core/providers/trip_provider.dart';
import '../../core/supabase/doc_service.dart';
import '../../data/docs_data.dart';
import '../../data/share_data.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'content_preview_card.dart';
import 'destination_selector.dart';
import 'extracted_spots_screen.dart';
import 'maps_import_screen.dart';
import 'parsed_itinerary_screen.dart';
import 'dart:typed_data';
import '../../core/places/url_metadata_service.dart';
import 'open_add_sheet.dart';

// ─── Entry point for import mode ─────────────────────────────────────────────

void showImportScreen(BuildContext context, WidgetRef ref) {
  final tripId = ref.read(activeTripIdProvider);
  final userId = ref.read(profileProvider)!.id;
  final homeCurrency = ref.read(activeTripProvider)?.homeCurrency ?? 'CAD';
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => IncomingShareScreen(
      share: null,
      tripId: tripId,
      userId: userId,
      homeCurrency: homeCurrency,
      onDone: () => Navigator.of(context).pop(),
    ),
  ));
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class IncomingShareScreen extends ConsumerStatefulWidget {
  const IncomingShareScreen({
    super.key,
    required this.share,
    required this.tripId,
    required this.userId,
    this.homeCurrency = 'CAD',
    this.onDone,
  });

  final IncomingShare? share;
  final String tripId;
  final String userId;
  final String homeCurrency;
  final VoidCallback? onDone;

  @override
  ConsumerState<IncomingShareScreen> createState() => _IncomingShareScreenState();
}

class _IncomingShareScreenState extends ConsumerState<IncomingShareScreen> {
  IncomingShare? _activeShare;
  ShareDestination? _destination;

  bool _scanningAi     = false;
  bool _scanningOcr    = false;
  bool _scanningPlaces = false;
  bool _scanningAudio  = false;
  bool _scanningMaps   = false;

  final _urlCtrl = TextEditingController();
  Uint8List? _fileBytes;
  String? _fileName;
  String? _fileExt;

  UrlMetadata? _meta;
  bool _fetchingMeta = false;
  bool _saving = false;

  final _captionCtrl    = TextEditingController();
  bool _scanningPasted  = false;

  bool get _inImportMode => widget.share == null;
  bool get _showSourceStep => _inImportMode && _activeShare == null;

  bool get _anyScan =>
      _scanningAi || _scanningOcr || _scanningPlaces || _scanningAudio || _scanningMaps || _scanningPasted;

  bool get _canParseItinerary =>
      !kIsWeb &&
      _destination == ShareDestination.travelItem &&
      (_activeShare?.filePath != null || _fileBytes != null) &&
      (_activeShare?.contentType == ShareContentType.screenshot ||
          _activeShare?.contentType == ShareContentType.pdfFile ||
          _activeShare?.contentType == ShareContentType.receiptPhoto);

  bool get _canFindPlaces =>
      _activeShare?.contentType == ShareContentType.tiktokLink ||
      _activeShare?.contentType == ShareContentType.instagramLink;

  bool get _canImportMaps =>
      _activeShare?.contentType == ShareContentType.googleMapsLink;

  @override
  void initState() {
    super.initState();
    _activeShare = widget.share;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  void _selectDestination(ShareDestination dest) {
    setState(() => _destination = dest);
  }

  // ─── Source picking (import mode) ─────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: FileTypeRegistry.shareExtensions,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    final bytes = f.bytes!;
    final ext = f.extension?.toLowerCase() ?? 'jpg';

    // CSV → go straight to the Takeout import screen
    if (ext == 'csv') {
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => MapsImportScreen(
            result: const MapsParseResult(places: [], isList: false),
            initialBytes: bytes,
            initialExt: 'csv',
            tripId: widget.tripId,
            userId: widget.userId,
            onDone: widget.onDone,
          ),
        ),
      );
      return;
    }

    final nameWithoutExt = f.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _fileBytes = bytes;
      _fileName = f.name;
      _fileExt = ext;
      _activeShare = IncomingShare(
        id: id,
        contentType: _contentTypeFromFile(ext),
        rawContent: f.name,
        detectedTitle: nameWithoutExt,
      );
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    final ext = picked.path.split('.').last.toLowerCase();
    final finalExt = ext.isEmpty ? 'jpg' : ext;
    final nameWithoutExt = picked.name.replaceAll(RegExp(r'\.[^.]+$'), '');
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _fileBytes = bytes;
      _fileName = picked.name;
      _fileExt = finalExt;
      _activeShare = IncomingShare(
        id: id,
        contentType: _contentTypeFromFile(finalExt),
        rawContent: picked.name,
        detectedTitle: nameWithoutExt,
      );
    });
  }

  void _applyUrl() {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final title = _titleFromUrl(url);
    setState(() {
      _activeShare = IncomingShare(
        id: id,
        contentType: detectContentType(url),
        rawContent: url,
        detectedTitle: title,
      );
    });
    _fetchMeta(url);
  }

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

  // ─── Scanning actions ──────────────────────────────────────────────────────

  Future<void> _findPlaces() async {
    if (_anyScan) return;
    setState(() => _scanningPlaces = true);
    try {
      final result = await SocialPlaceExtractor.extract(_activeShare!.rawContent);
      if (!mounted) return;
      if (result == null) {
        showWabwaySnack(context, 'Could not load the post — it may be private', duration: Duration(seconds: 4));
        return;
      }
      if (result.places.isEmpty) {
        showWabwaySnack(context, result.caption.isEmpty ? 'No caption found in this post' : 'No recognisable places found in caption', duration: const Duration(seconds: 4));
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ExtractedSpotsScreen(
            places: result.places,
            caption: result.caption,
            sourceUrl: _activeShare!.rawContent,
            tripId: widget.tripId,
            userId: widget.userId,
            onDone: () {
              Navigator.pop(context);
              widget.onDone?.call();
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningPlaces = false);
    }
  }

  Future<void> _transcribeAudio() async {
    if (_anyScan) return;
    setState(() => _scanningAudio = true);
    try {
      final result = await SocialPlaceExtractor.extractFromAudio(_activeShare!.rawContent);
      if (!mounted) return;
      if (result == null) {
        showWabwaySnack(context, 'Could not transcribe audio — check server or try the caption method', duration: Duration(seconds: 5));
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ExtractedSpotsScreen(
            places: result.places,
            caption: result.caption,
            sourceUrl: _activeShare!.rawContent,
            tripId: widget.tripId,
            userId: widget.userId,
            onDone: () {
              Navigator.pop(context);
              widget.onDone?.call();
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningAudio = false);
    }
  }

  Future<void> _findPlacesInPastedText() async {
    final text = _captionCtrl.text.trim();
    if (text.isEmpty || _anyScan) return;
    setState(() => _scanningPasted = true);
    try {
      final result = await SocialPlaceExtractor.extractFromText(text);
      if (!mounted) return;
      if (result.places.isEmpty) {
        showWabwaySnack(context, text.isEmpty ? 'Paste some caption text first' : 'No recognisable places found in the text', duration: const Duration(seconds: 4));
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => ExtractedSpotsScreen(
            places: result.places,
            caption: result.caption,
            sourceUrl: _activeShare?.rawContent ?? '',
            tripId: widget.tripId,
            userId: widget.userId,
            onDone: () {
              Navigator.pop(context);
              widget.onDone?.call();
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningPasted = false);
    }
  }

  Future<void> _importFromMaps() async {
    if (_anyScan) return;
    setState(() => _scanningMaps = true);
    try {
      final result = await GoogleMapsParser.parse(_activeShare!.rawContent);
      if (!mounted) return;
      if (result == null) {
        showWabwaySnack(context, 'Could not reach Google Maps — check your connection', duration: Duration(seconds: 4));
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => MapsImportScreen(
            result: result,
            tripId: widget.tripId,
            userId: widget.userId,
            onDone: () {
              Navigator.pop(context);
              widget.onDone?.call();
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _scanningMaps = false);
    }
  }

  bool get _isCsvShare =>
      _activeShare?.contentType == ShareContentType.csvFile;

  Future<void> _importFromCsv() async {
    final filePath = _activeShare?.filePath;
    final inMemBytes = _fileBytes;
    final bytes = inMemBytes ??
        (filePath != null ? await readFileAsBytes(filePath) : null);
    if (bytes == null || !mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MapsImportScreen(
          result: const MapsParseResult(places: [], isList: false),
          initialBytes: bytes,
          initialExt: 'csv',
          tripId: widget.tripId,
          userId: widget.userId,
          onDone: () {
            Navigator.pop(context);
            widget.onDone?.call();
          },
        ),
      ),
    );
  }

  Future<void> _parseWithAi() async {
    final filePath = _activeShare?.filePath;
    final inMemBytes = _fileBytes;
    if ((filePath == null && inMemBytes == null) || _anyScan) return;
    setState(() => _scanningAi = true);
    try {
      final bytes = inMemBytes ?? await readFileAsBytes(filePath!);
      final ext = filePath != null
          ? _extFromShare(filePath, _activeShare!.contentType)
          : (_fileExt ?? 'jpg');
      final result = await ItineraryScanner.scanWithAi(bytes, ext);
      if (!mounted) return;
      if (result.bookings.isEmpty) {
        final aiStatus = GeminiParser.lastHttpStatus;
        final msg = switch (aiStatus) {
          429 => 'AI quota exceeded — try OCR instead',
          0 => 'No AI key configured',
          200 => 'AI read the file but found no bookings — try OCR',
          _ => 'AI failed (HTTP $aiStatus) — try OCR instead',
        };
        showWabwaySnack(context, msg, duration: const Duration(seconds: 5));
        return;
      }
      await _pushResults(result, bytes, ext, filePath ?? _fileName);
    } finally {
      if (mounted) setState(() => _scanningAi = false);
    }
  }

  Future<void> _parseWithOcr() async {
    final filePath = _activeShare?.filePath;
    final inMemBytes = _fileBytes;
    if ((filePath == null && inMemBytes == null) || _anyScan) return;
    setState(() => _scanningOcr = true);
    try {
      final bytes = inMemBytes ?? await readFileAsBytes(filePath!);
      final ext = filePath != null
          ? _extFromShare(filePath, _activeShare!.contentType)
          : (_fileExt ?? 'jpg');
      final result = await ItineraryScanner.scanWithOcr(bytes, ext);
      if (!mounted) return;
      if (result.bookings.isEmpty) {
        showWabwaySnack(context, 'No booking patterns found — fill in manually', duration: Duration(seconds: 4));
        return;
      }
      await _pushResults(result, bytes, ext, filePath ?? _fileName);
    } finally {
      if (mounted) setState(() => _scanningOcr = false);
    }
  }

  Future<void> _pushResults(
    ScanResult result,
    Uint8List bytes,
    String ext,
    String? filePath,
  ) async {
    final fileName = filePath?.split('/').last;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ParsedItineraryScreen(
          bookings: result.bookings,
          tripId: widget.tripId,
          userId: widget.userId,
          sourceBytes: bytes,
          sourceExt: ext,
          sourceFileName: fileName,
          onDone: () {
            Navigator.pop(context);
            widget.onDone?.call();
          },
        ),
      ),
    );
  }

  // ─── Continue → the entity's ONE Add sheet, pre-filled ────────────────────
  //
  // Import never re-implements an entity form. It works out what it can from
  // the shared content (link metadata, file, Maps URL) and hands that to the
  // same Add sheet the rest of the app uses.

  Future<void> _fetchMeta(String url) async {
    setState(() { _fetchingMeta = true; _meta = null; });
    final meta = await UrlMetadataService.fetch(url);
    if (!mounted || _activeShare?.rawContent != url) return;
    setState(() {
      _fetchingMeta = false;
      _meta = meta;
      if (meta?.isLodging == true && _destination == null) {
        _destination = ShareDestination.stay;
      }
    });
  }

  String? get _sourceUrl {
    final raw = _activeShare?.rawContent.trim() ?? '';
    return raw.startsWith('http://') || raw.startsWith('https://') ? raw : null;
  }

  Future<(Uint8List, String, String)?> _fileForShare() async {
    final filePath = _activeShare?.filePath;
    final bytes = _fileBytes ?? (filePath != null ? await readFileAsBytes(filePath) : null);
    if (bytes == null) return null;
    final ext = _fileExt ??
        (filePath != null ? _extFromShare(filePath, _activeShare!.contentType) : 'bin');
    final name = _fileName ?? filePath?.split('/').last ?? 'file.$ext';
    return (bytes, name, ext);
  }

  ImportPrefill _prefill({
    Uint8List? bytes,
    String? fileName,
    String? fileExt,
    List<String> docIds = const [],
  }) {
    final share = _activeShare!;
    final meta = _meta;
    final url = _sourceUrl;
    final isMaps = share.contentType == ShareContentType.googleMapsLink;
    return ImportPrefill(
      title: meta?.title ?? share.detectedTitle,
      notes: meta?.description,
      url: isMaps ? null : url,
      mapsUrl: isMaps ? url : null,
      location: meta?.locality ?? meta?.address,
      date: meta?.startDate,
      endDate: meta?.endDate,
      confirmationNumber: meta?.confirmationNumber,
      amount: meta?.price,
      currency: meta?.currency,
      fileBytes: bytes,
      fileName: fileName,
      fileExt: fileExt,
      linkedDocIds: docIds,
    );
  }

  /// Travel and plan items attach files as documents. Upload first so the
  /// sheet's doc picker shows it pre-selected; removed again if cancelled.
  Future<TripDocument?> _uploadShareFile() async {
    final f = await _fileForShare();
    if (f == null) return null;
    return DocService.uploadAndCreate(
      tripId: widget.tripId,
      userId: widget.userId,
      title: _prefill().title ?? f.$2,
      type: DocType.other,
      ext: f.$3,
      bytes: f.$1,
      fileSizeKb: (f.$1.length / 1024).round(),
    );
  }

  Future<void> _continue() async {
    final dest = _destination;
    if (dest == null || _saving) return;
    setState(() => _saving = true);
    try {
      final saved = await _openSheetFor(dest);
      if (!mounted) return;
      if (saved) {
        showWabwaySnack(context, 'Saved as ${dest.label.toLowerCase()}');
        widget.onDone?.call();
      }
    } catch (_) {
      if (mounted) showWabwaySnack(context, 'Could not save — please try again.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _openSheetFor(ShareDestination dest) async {
    // Documents and receipts take the file in their own form; travel and plan
    // items attach it as an uploaded document instead.
    final carriesFile = dest == ShareDestination.document || dest == ShareDestination.receipt;
    final f = carriesFile ? await _fileForShare() : null;
    if (!mounted) return false;
    return openAddSheet(
      context,
      ref,
      dest,
      prefill: _prefill(bytes: f?.$1, fileName: f?.$2, fileExt: f?.$3),
      sourceUrl: _sourceUrl,
      uploadFile: _uploadShareFile,
    );
  }

  void _handleDiscard() {
    widget.onDone?.call();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _extFromShare(String filePath, ShareContentType contentType) {
    if (contentType == ShareContentType.pdfFile) return 'pdf';
    final filename = filePath.split('/').last;
    final dotIdx = filename.lastIndexOf('.');
    if (dotIdx >= 0 && dotIdx < filename.length - 1) {
      return filename.substring(dotIdx + 1).toLowerCase();
    }
    return contentType == ShareContentType.screenshot ? 'png' : '';
  }

  static ShareContentType _contentTypeFromFile(String? ext) =>
      FileTypeRegistry.contentTypeFromExt(ext);

  static String _titleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceAll('www.', '');
      return host.isNotEmpty ? host : url;
    } catch (_) {
      return url.length > 40 ? url.substring(0, 40) : url;
    }
  }

  Widget _buildContinue() {
    final dest = _destination!;
    final metaTitle = _meta?.title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_fetchingMeta)
          Row(
            children: [
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: kSpace2),
              Text('Reading the link…', style: kStyleCaption),
            ],
          )
        else if (metaTitle != null)
          Text('Found: $metaTitle', style: kStyleCaption, maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: kSpace3),
        WabwayButton(
          label: 'Continue — add ${dest.label.toLowerCase()} details',
          icon: dest.icon,
          fullWidth: true,
          size: WabwayButtonSize.lg,
          loading: _saving,
          onPressed: (_saving || _anyScan) ? null : _continue,
        ),
        const SizedBox(height: kSpace2),
        WabwayButton(
          label: 'Discard',
          variant: WabwayButtonVariant.ghost,
          fullWidth: true,
          onPressed: _saving ? null : _handleDiscard,
        ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text(_inImportMode ? 'Import' : 'Add to trip', style: kStyleTitle),
        leading: _inImportMode && !_showSourceStep
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => setState(() {
                  _activeShare = null;
                  _destination = null;
                  _fileBytes = null;
                  _fileName = null;
                  _fileExt = null;
                  _urlCtrl.clear();
                }),
                tooltip: 'Back',
              )
            : IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: _handleDiscard,
                tooltip: 'Discard',
              ),
      ),
      body: _showSourceStep
          ? _buildSourceStep()
          : isDesktop
              ? _buildDesktop()
              : _buildMobile(),
    );
  }

  // ─── Source step (import mode) ────────────────────────────────────────────

  Widget _buildSourceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What are you importing?', style: kStyleBodyMedium.copyWith(color: kColorInkSoft)),
          const SizedBox(height: kSpace4),
          _SourceTile(
            icon: Icons.upload_file_rounded,
            label: 'Pick a file',
            sub: 'PDF, image or document',
            onTap: _pickFile,
          ),
          const SizedBox(height: kSpace2),
          if (!kIsWeb)
            _SourceTile(
              icon: Icons.add_photo_alternate_rounded,
              label: 'Add a photo',
              sub: 'Camera or gallery',
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
            hint: 'https://…',
            controller: _urlCtrl,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyUrl(),
          ),
          const SizedBox(height: kSpace3),
          WabwayButton(
            label: 'Continue with link',
            variant: WabwayButtonVariant.secondary,
            fullWidth: true,
            onPressed: _applyUrl,
          ),
        ],
      ),
    );
  }

  // ─── Plan item form ───────────────────────────────────────────────────────

  /// Smart extractors offered for the shared content (both layouts).
  List<Widget> _buildActions() => [
            if (_canParseItinerary) ...[
              if (GeminiParser.isAvailable)
                _ParseItineraryBanner(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Parse with AI',
                  subtitle: 'Reads flights, hotels & trains via Gemini',
                  scanning: _scanningAi,
                  disabled: _anyScan,
                  onTap: _parseWithAi,
                ),
              if (GeminiParser.isAvailable) const SizedBox(height: kSpace2),
              _ParseItineraryBanner(
                icon: Icons.document_scanner_rounded,
                label: 'Read text / PDF',
                subtitle: 'On-device OCR · no AI required',
                scanning: _scanningOcr,
                disabled: _anyScan,
                onTap: _parseWithOcr,
              ),
              const SizedBox(height: kSpace4),
            ],
            if (_isCsvShare) ...[
              _ParseItineraryBanner(
                icon: Icons.table_chart_rounded,
                label: 'Import spots from CSV',
                subtitle: 'Import saved places from Google Takeout',
                scanning: false,
                disabled: _anyScan,
                onTap: _importFromCsv,
              ),
              const SizedBox(height: kSpace4),
            ],
            if (_canImportMaps) ...[
              _ParseItineraryBanner(
                icon: Icons.pin_drop_rounded,
                label: 'Import from Google Maps',
                subtitle: 'Add all pins as spots · works with lists & My Maps',
                scanning: _scanningMaps,
                disabled: _anyScan,
                onTap: _importFromMaps,
              ),
              const SizedBox(height: kSpace4),
            ],
            if (_canFindPlaces) ...[
              _ParseItineraryBanner(
                icon: Icons.place_rounded,
                label: 'Find places',
                subtitle: 'Extract locations from caption · no AI',
                scanning: _scanningPlaces,
                disabled: _anyScan,
                onTap: _findPlaces,
              ),
              const SizedBox(height: kSpace2),
              if (SocialPlaceExtractor.audioServerAvailable) ...[
                _ParseItineraryBanner(
                  icon: Icons.graphic_eq_rounded,
                  label: 'Extract from audio',
                  subtitle: 'Transcribes spoken place names from the video',
                  scanning: _scanningAudio,
                  disabled: _anyScan,
                  onTap: _transcribeAudio,
                ),
                const SizedBox(height: kSpace2),
              ],
              _PasteCaptionCard(
                controller: _captionCtrl,
                scanning: _scanningPasted,
                disabled: _anyScan,
                onFind: _findPlacesInPastedText,
              ),
              const SizedBox(height: kSpace4),
            ],
      ];

  // ─── Desktop ──────────────────────────────────────────────────────────────

  Widget _buildDesktop() {
    final share = _activeShare!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 380,
          child: Container(
            color: kColorBgRaised,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(kSpace5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detected content',
                    style: kStyleCaptionMedium.copyWith(color: kColorInkSoft),
                  ),
                  const SizedBox(height: kSpace2),
                  ContentPreviewCard(share: share),
                  const SizedBox(height: kSpace5),
                  _ContentTypeInfoCard(contentType: share.contentType),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: kColorBorder),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kSpace5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DestinationSelector(
                  contentType: share.contentType,
                  selected: _destination,
                  onSelect: _selectDestination,
                ),
                if (_destination != null) ...[
                  const SizedBox(height: kSpace5),
                  const Divider(color: kColorBorder),
                  const SizedBox(height: kSpace4),
                  ..._buildActions(),
                  _buildContinue(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Mobile ───────────────────────────────────────────────────────────────

  Widget _buildMobile() {
    final share = _activeShare!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentPreviewCard(share: share),
          const SizedBox(height: kSpace5),
          DestinationSelector(
            contentType: share.contentType,
            selected: _destination,
            onSelect: _selectDestination,
          ),
          if (_destination != null) ...[
            const SizedBox(height: kSpace5),
            Container(width: double.infinity, height: 1, color: kColorBorder),
            const SizedBox(height: kSpace4),
            ..._buildActions(),
            _buildContinue(),
            const SizedBox(height: kSpace12),
          ],
        ],
      ),
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
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: kRadiusMd,
      child: Container(
        padding: const EdgeInsets.all(kSpace4),
        decoration: BoxDecoration(
          color: kColorSurfaceSunken,
          borderRadius: kRadiusMd,
          border: Border.all(color: kColorBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(kSpace2),
              decoration: const BoxDecoration(
                color: kColorPrimarySoft,
                borderRadius: kRadiusMd,
              ),
              child: Icon(icon, size: 20, color: kColorPrimary),
            ),
            const SizedBox(width: kSpace3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: kStyleBodyMedium),
                Text(sub, style: kStyleCaption),
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

// ─── Paste caption card ──────────────────────────────────────────────────────

class _PasteCaptionCard extends StatelessWidget {
  const _PasteCaptionCard({
    required this.controller,
    required this.scanning,
    required this.disabled,
    required this.onFind,
  });

  final TextEditingController controller;
  final bool scanning;
  final bool disabled;
  final VoidCallback onFind;

  static const _blue = Color(0xFF4A7AB5);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF6),
        borderRadius: kRadiusMd,
        border: Border.all(color: _blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.15),
                  borderRadius: kRadiusSm,
                ),
                child: scanning
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2, color: _blue),
                      )
                    : const Icon(Icons.content_paste_rounded, size: 18, color: _blue),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scanning ? 'Scanning…' : 'Paste caption',
                      style: kStyleBodyMedium.copyWith(color: _blue),
                    ),
                    Text(
                      'Copy & paste the post caption to extract places',
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: kSpace3),
          TextField(
            controller: controller,
            enabled: !disabled,
            maxLines: 4,
            minLines: 2,
            style: kStyleBodyMedium,
            decoration: InputDecoration(
              hintText: 'Paste caption here…',
              hintStyle: kStyleCaption.copyWith(color: kColorInkSoft),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.6),
              contentPadding: const EdgeInsets.all(kSpace3),
              border: OutlineInputBorder(
                borderRadius: kRadiusMd,
                borderSide: BorderSide(color: _blue.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: kRadiusMd,
                borderSide: BorderSide(color: _blue.withValues(alpha: 0.3)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: kRadiusMd,
                borderSide: BorderSide(color: _blue),
              ),
            ),
          ),
          const SizedBox(height: kSpace2),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: disabled ? null : onFind,
              icon: const Icon(Icons.search_rounded, size: 16, color: _blue),
              label: Text('Find places', style: kStyleBodyMedium.copyWith(color: _blue)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Parse itinerary banner ───────────────────────────────────────────────────

class _ParseItineraryBanner extends StatelessWidget {
  const _ParseItineraryBanner({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.scanning,
    required this.disabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool scanning;
  final bool disabled;
  final VoidCallback onTap;

  static const _blue = Color(0xFF4A7AB5);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: disabled && !scanning ? 0.45 : 1.0,
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
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: 0.15),
                  borderRadius: kRadiusSm,
                ),
                child: scanning
                    ? const Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _blue,
                        ),
                      )
                    : Icon(icon, size: 18, color: _blue),
              ),
              const SizedBox(width: kSpace3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      scanning ? 'Scanning…' : label,
                      style: kStyleBodyMedium.copyWith(color: _blue),
                    ),
                    Text(
                      subtitle,
                      style: kStyleCaption.copyWith(color: kColorInkSoft),
                    ),
                  ],
                ),
              ),
              if (!scanning)
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _blue),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Demo launcher ────────────────────────────────────────────────────────────

class IncomingShareDemoLauncher extends ConsumerStatefulWidget {
  const IncomingShareDemoLauncher({super.key});

  @override
  ConsumerState<IncomingShareDemoLauncher> createState() =>
      _IncomingShareDemoLauncherState();
}

class _IncomingShareDemoLauncherState extends ConsumerState<IncomingShareDemoLauncher> {
  int _shareIndex = 0;

  IncomingShare get _currentShare =>
      kMockIncomingShares[_shareIndex % kMockIncomingShares.length];

  void _launch() {
    final tripId = ref.read(activeTripIdProvider);
    final userId = ref.read(profileProvider)!.id;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingShareScreen(
          share: _currentShare,
          tripId: tripId,
          userId: userId,
          onDone: () => Navigator.pop(context),
        ),
      ),
    ).then((_) => setState(() => _shareIndex++));
  }

  @override
  Widget build(BuildContext context) {
    final share = _currentShare;
    return WabwayCard(
      hoverable: true,
      onTap: _launch,
      child: Padding(
        padding: const EdgeInsets.all(kSpace4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: share.contentType.softColor,
                borderRadius: kRadiusMd,
              ),
              child: Icon(
                share.contentType.icon,
                size: 20,
                color: share.contentType.color,
              ),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Try incoming share', style: kStyleBodySemibold),
                  Text(
                    share.detectedTitle,
                    style: kStyleCaption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: kColorTextTertiary(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Content type info card ───────────────────────────────────────────────────

class _ContentTypeInfoCard extends StatelessWidget {
  const _ContentTypeInfoCard({required this.contentType});

  final ShareContentType contentType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(kSpace3),
      decoration: BoxDecoration(
        color: contentType.softColor,
        borderRadius: kRadiusMd,
        border: Border.all(color: contentType.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(contentType.icon, size: 16, color: contentType.color),
              const SizedBox(width: kSpace2),
              Text(
                contentType.label,
                style: kStyleCaptionMedium.copyWith(color: contentType.color),
              ),
            ],
          ),
          const SizedBox(height: kSpace2),
          Text(_infoText(contentType), style: kStyleCaption),
        ],
      ),
    );
  }

  String _infoText(ShareContentType type) => switch (type) {
        ShareContentType.googleMapsLink =>
          'Google Maps links work best as spots — the location name and address are pulled directly.',
        ShareContentType.instagramLink =>
          'Instagram posts can be saved as spots (places you\'ve seen) or links (for later).',
        ShareContentType.tiktokLink =>
          'TikTok videos are usually best as links, but you can also create a spot from a place shown.',
        ShareContentType.youtubeLink =>
          'YouTube videos are usually travel guides or reviews — save as a link for the group.',
        ShareContentType.restaurantWebsite =>
          'Restaurant websites work well as spots — add the address and category to find them later.',
        ShareContentType.blogArticle =>
          'Travel articles are easiest to save as links so the whole group can read them.',
        ShareContentType.pdfFile =>
          'PDFs are usually booking confirmations or travel documents — save under the right category.',
        ShareContentType.receiptPhoto =>
          'Receipt photos can be logged as group expenses so you can settle up later.',
        ShareContentType.screenshot =>
          'Screenshots are usually confirmations or reference images — save as a document.',
        ShareContentType.accommodationLink =>
          'Accommodation links can be saved as stays — tap "Save as stay" to parse the listing details automatically.',
        ShareContentType.csvFile =>
          'CSV files from Google Takeout contain your saved places — tap "Import spots from CSV" to add them all.',
      };
}
