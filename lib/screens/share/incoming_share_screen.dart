import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/ocr/gemini_parser.dart';
import '../../core/ocr/itinerary_scanner.dart';
import '../../core/places/google_maps_parser.dart';
import '../../core/places/listing_parser.dart';
import '../../core/places/social_place_extractor.dart';
import '../../core/platform/platform_file.dart';
import '../../core/auth/profile_state.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/links_service.dart';
import '../../core/supabase/money_service.dart';
import '../../core/supabase/plan_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../core/supabase/travel_service.dart';
import '../../core/trip/trip_state.dart';
import '../../data/docs_data.dart';
import '../../data/links_data.dart';
import '../../data/money_data.dart';
import '../../data/plan_data.dart';
import '../../data/share_data.dart';
import '../../data/spot_data.dart';
import '../../data/travel_data.dart';
import '../../screens/accommodations/add_accommodation_sheet.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';
import '../../theme/app_text_theme.dart';
import '../../widgets/widgets.dart';
import 'content_preview_card.dart';
import 'destination_selector.dart';
import 'extracted_spots_screen.dart';
import 'maps_import_screen.dart';
import 'parsed_itinerary_screen.dart';
import 'share_form.dart';

// ─── Entry point for import mode ─────────────────────────────────────────────

void showImportScreen(BuildContext context) {
  final tripId = TripState.tripOf(context).id;
  final userId = ProfileState.of(context).id;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => IncomingShareScreen(
      share: null,
      tripId: tripId,
      userId: userId,
      onDone: () => Navigator.of(context).pop(),
    ),
  ));
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class IncomingShareScreen extends StatefulWidget {
  const IncomingShareScreen({
    super.key,
    required this.share,
    required this.tripId,
    required this.userId,
    this.onDone,
  });

  final IncomingShare? share;
  final String tripId;
  final String userId;
  final VoidCallback? onDone;

  @override
  State<IncomingShareScreen> createState() => _IncomingShareScreenState();
}

class _IncomingShareScreenState extends State<IncomingShareScreen> {
  IncomingShare? _activeShare;
  ShareDestination? _destination;

  bool _scanningAi     = false;
  bool _scanningOcr    = false;
  bool _scanningPlaces = false;
  bool _scanningAudio  = false;
  bool _scanningStay   = false;
  bool _scanningMaps   = false;

  final _urlCtrl = TextEditingController();
  Uint8List? _fileBytes;
  String? _fileName;
  String? _fileExt;

  List<TripDay> _days = [];
  TripDay? _selectedDay;
  bool _daysLoading = false;
  ItineraryItemType _planItemType = ItineraryItemType.activity;

  final _planTitleCtrl  = TextEditingController();
  final _planNotesCtrl  = TextEditingController();
  final _captionCtrl    = TextEditingController();
  bool _scanningPasted  = false;

  bool get _inImportMode => widget.share == null;
  bool get _showSourceStep => _inImportMode && _activeShare == null;

  bool get _anyScan =>
      _scanningAi || _scanningOcr || _scanningPlaces || _scanningAudio || _scanningStay || _scanningMaps || _scanningPasted;

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

  bool get _canSaveAsStay =>
      _activeShare?.contentType == ShareContentType.accommodationLink;

  @override
  void initState() {
    super.initState();
    _activeShare = widget.share;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _planTitleCtrl.dispose();
    _planNotesCtrl.dispose();
    _captionCtrl.dispose();
    super.dispose();
  }

  void _selectDestination(ShareDestination dest) {
    setState(() => _destination = dest);
    if (dest == ShareDestination.planItem) _loadDays();
  }

  // ─── Source picking (import mode) ─────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'docx', 'xlsx', 'webp', 'heic'],
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.first;
    if (f.bytes == null) return;
    final bytes = f.bytes!;
    final ext = f.extension?.toLowerCase() ?? 'jpg';
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
      _planTitleCtrl.text = nameWithoutExt;
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
      _planTitleCtrl.text = nameWithoutExt;
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
      _planTitleCtrl.text = title;
    });
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

  // ─── Plan item ────────────────────────────────────────────────────────────

  Future<void> _loadDays() async {
    if (_days.isNotEmpty || _daysLoading) return;
    setState(() => _daysLoading = true);
    try {
      final days = await PlanService.loadAll(widget.tripId);
      if (!mounted) return;
      setState(() {
        _days = days;
        _selectedDay = days.isNotEmpty ? days.first : null;
        _daysLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _daysLoading = false);
    }
  }

  Future<void> _savePlanItem() async {
    final title = _planTitleCtrl.text.trim();
    if (title.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter a title'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_selectedDay == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Select an itinerary day'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    TripDocument? doc;
    final filePath = _activeShare?.filePath;
    final planBytes = _fileBytes ?? (filePath != null ? await readFileAsBytes(filePath) : null);
    if (planBytes != null) {
      final ext = _fileExt ?? filePath?.split('.').last.toLowerCase() ?? 'bin';
      doc = await DocService.uploadAndCreate(
        tripId: widget.tripId,
        userId: widget.userId,
        title: title,
        type: DocType.other,
        ext: ext,
        bytes: planBytes,
        fileSizeKb: (planBytes.length / 1024).round(),
      );
    }
    await PlanService.createItem(
      tripId: widget.tripId,
      dayId: _selectedDay!.id,
      title: title,
      type: _planItemType,
      createdBy: widget.userId,
      notes: _planNotesCtrl.text.trim().isEmpty ? null : _planNotesCtrl.text.trim(),
      linkedDocIds: doc != null ? [doc.id] : [],
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Saved as plan item',
        style: kStyleBodyMedium.copyWith(color: kColorTextOnPrimary),
      ),
      backgroundColor: kColorPrimary,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
      margin: const EdgeInsets.all(kSpace4),
      duration: const Duration(seconds: 2),
    ));
    widget.onDone?.call();
  }

  // ─── Scanning actions ──────────────────────────────────────────────────────

  Future<void> _saveAsStay() async {
    if (_anyScan) return;
    setState(() => _scanningStay = true);
    try {
      final url = _activeShare!.rawContent;
      final result = await ListingParser.parse(url);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddAccommodationSheet(
          tripId: widget.tripId,
          userId: widget.userId,
          prefilled: result,
          initialUrl: url,
        ),
      );
      if (mounted) widget.onDone?.call();
    } finally {
      if (mounted) setState(() => _scanningStay = false);
    }
  }

  Future<void> _findPlaces() async {
    if (_anyScan) return;
    setState(() => _scanningPlaces = true);
    try {
      final result = await SocialPlaceExtractor.extract(_activeShare!.rawContent);
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not load the post — it may be private'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ));
        return;
      }
      if (result.places.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            result.caption.isEmpty
                ? 'No caption found in this post'
                : 'No recognisable places found in caption',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not transcribe audio — check server or try the caption method'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            text.isEmpty
                ? 'Paste some caption text first'
                : 'No recognisable places found in the text',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not reach Google Maps — check your connection'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No booking patterns found — fill in manually'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ));
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

  // ─── Save ──────────────────────────────────────────────────────────────────

  Future<void> _handleSave(ShareSaveData data) async {
    final dest = _destination;
    if (dest == null) return;

    final tripId = widget.tripId;
    final userId = widget.userId;

    switch (dest) {
      case ShareDestination.spot:
        final isMaps = _activeShare!.contentType == ShareContentType.googleMapsLink;
        await SpotService.createSpot(
          tripId: tripId,
          name: data.title,
          city: data.location ?? 'Unknown',
          area: '',
          category: _spotCategory(data.category),
          status: SpotStatus.idea,
          addedBy: userId,
          sourceUrl: isMaps ? null : _activeShare!.rawContent,
          mapsUrl: data.mapsUrl,
          notes: data.notes.isEmpty ? null : data.notes,
          country: data.country,
          latitude: data.latitude,
          longitude: data.longitude,
          placeSource: data.placeSource,
        );

      case ShareDestination.document:
        final filePath = _activeShare?.filePath;
        final docBytes = _fileBytes ?? (filePath != null ? await readFileAsBytes(filePath) : null);
        if (docBytes != null) {
          final ext = _fileExt ?? filePath?.split('.').last.toLowerCase() ?? 'bin';
          await DocService.uploadAndCreate(
            tripId: tripId,
            userId: userId,
            title: data.title,
            type: _docType(data.docType),
            ext: ext,
            bytes: docBytes,
            fileSizeKb: (docBytes.length / 1024).round(),
            notes: data.notes.isEmpty ? null : data.notes,
          );
        } else {
          await DocService.createDocument(
            tripId: tripId,
            userId: userId,
            title: data.title,
            type: _docType(data.docType),
            ext: 'url',
            notes: data.notes.isEmpty ? null : data.notes,
          );
        }

      case ShareDestination.travelItem:
        TripDocument? travelDoc;
        final travelFilePath = _activeShare?.filePath;
        final travelBytes = _fileBytes ?? (travelFilePath != null ? await readFileAsBytes(travelFilePath) : null);
        if (travelBytes != null) {
          final ext = _fileExt ?? travelFilePath?.split('.').last.toLowerCase() ?? 'bin';
          travelDoc = await DocService.uploadAndCreate(
            tripId: tripId,
            userId: userId,
            title: data.title,
            type: _docType(data.docType),
            ext: ext,
            bytes: travelBytes,
            fileSizeKb: (travelBytes.length / 1024).round(),
            notes: data.notes.isEmpty ? null : data.notes,
          );
        }
        final travelItem = await TravelService.createItem(
          tripId: tripId,
          title: data.title,
          type: _travelItemType(data.travelType),
          createdBy: userId,
          date: data.date,
          notes: data.notes.isEmpty ? null : data.notes,
        );
        if (travelDoc != null) {
          await DocService.addLink(
            documentId: travelDoc.id,
            linkedType: DocLinkedType.travelItem,
            linkedId: travelItem.id,
            createdBy: userId,
          );
        }

      case ShareDestination.receipt:
        TripDocument? receiptDoc;
        final receiptFilePath = _activeShare?.filePath;
        final receiptBytes = _fileBytes ?? (receiptFilePath != null ? await readFileAsBytes(receiptFilePath) : null);
        if (receiptBytes != null) {
          final ext = _fileExt ?? receiptFilePath?.split('.').last.toLowerCase() ?? 'jpg';
          receiptDoc = await DocService.uploadAndCreate(
            tripId: tripId,
            userId: userId,
            title: data.title,
            type: DocType.receipt,
            ext: ext,
            bytes: receiptBytes,
            fileSizeKb: (receiptBytes.length / 1024).round(),
          );
        }
        final amount = data.amount ?? 0.0;
        final receipt = await MoneyService.createReceipt(
          tripId:            tripId,
          paidBy:            userId,
          title:             data.title,
          amount:            amount,
          currency:          'JPY',
          homeAmount:        amount,
          exchangeRate:      1.0,
          transactionFeePct: 0.0,
          category:          _receiptCategory(data.category),
          date:              data.date ?? DateTime.now(),
          notes:             data.notes.isEmpty ? null : data.notes,
          splits:            [ReceiptSplit(memberId: userId, amount: amount)],
        );
        if (receiptDoc != null) {
          await DocService.addLink(
            documentId: receiptDoc.id,
            linkedType: DocLinkedType.receipt,
            linkedId: receipt.id,
            createdBy: userId,
          );
        }

      case ShareDestination.link:
        final url = _activeShare?.rawContent ?? '';
        if (url.isEmpty) return;
        await LinksService.createLink(
          tripId: tripId,
          addedBy: userId,
          title: data.title,
          url: url,
          category: _linkCategory(_activeShare!.contentType),
          notes: data.notes.isEmpty ? null : data.notes,
        );

      case ShareDestination.planItem:
        await _savePlanItem();
        return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Saved as ${dest.label.toLowerCase()}',
        style: kStyleBodyMedium.copyWith(color: kColorTextOnPrimary),
      ),
      backgroundColor: kColorPrimary,
      behavior: SnackBarBehavior.floating,
      shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
      margin: const EdgeInsets.all(kSpace4),
      duration: const Duration(seconds: 2),
    ));
    widget.onDone?.call();
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

  static ShareContentType _contentTypeFromFile(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'pdf':
        return ShareContentType.pdfFile;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'heic':
      case 'bmp':
        return ShareContentType.screenshot;
      default:
        return ShareContentType.blogArticle;
    }
  }

  static String _titleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final host = uri.host.replaceAll('www.', '');
      return host.isNotEmpty ? host : url;
    } catch (_) {
      return url.length > 40 ? url.substring(0, 40) : url;
    }
  }

  static SpotCategory _spotCategory(String? raw) => switch (raw) {
        'food' => SpotCategory.food,
        'shopping' => SpotCategory.shopping,
        'accommodation' => SpotCategory.experience,
        'attraction' => SpotCategory.landmark,
        _ => SpotCategory.landmark,
      };

  static DocType _docType(String? raw) => switch (raw) {
        'flight' => DocType.flight,
        'hotel' => DocType.hotel,
        'ticket' => DocType.ticket,
        'insurance' => DocType.insurance,
        'screenshot' => DocType.screenshot,
        _ => DocType.other,
      };

  static TravelItemType _travelItemType(String? raw) => switch (raw) {
        'flight' => TravelItemType.flight,
        'hotel' => TravelItemType.hotel,
        'train' => TravelItemType.train,
        'ticket' => TravelItemType.ticket,
        'reservation' => TravelItemType.reservation,
        _ => TravelItemType.other,
      };

  static ReceiptCategory _receiptCategory(String? raw) => switch (raw) {
        'food' => ReceiptCategory.food,
        'transport' => ReceiptCategory.transport,
        'accommodation' => ReceiptCategory.accommodation,
        'activity' => ReceiptCategory.activity,
        'shopping' => ReceiptCategory.shopping,
        _ => ReceiptCategory.other,
      };

  static LinkCategory _linkCategory(ShareContentType contentType) =>
      switch (contentType) {
        ShareContentType.instagramLink => LinkCategory.social,
        ShareContentType.tiktokLink => LinkCategory.social,
        ShareContentType.youtubeLink => LinkCategory.article,
        ShareContentType.blogArticle => LinkCategory.article,
        _ => LinkCategory.general,
      };

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

  Widget _buildPlanItemForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WabwayTextField(
          label: 'Title',
          controller: _planTitleCtrl,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: kSpace4),
        if (_daysLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: kSpace4),
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(kColorPrimary),
              ),
            ),
          )
        else if (_days.isEmpty)
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
          )
        else ...[
          Text('Itinerary day', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
          const SizedBox(height: kSpace3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: kSpace3),
            decoration: BoxDecoration(
              color: kColorSurfaceSunken,
              borderRadius: kRadiusMd,
              border: Border.all(color: kColorBorder),
            ),
            child: DropdownButton<TripDay>(
              value: _selectedDay,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              style: kStyleBodyMedium,
              items: _days
                  .map((d) => DropdownMenuItem(
                        value: d,
                        child: Text('Day ${d.dayNumber} – ${d.city}', style: kStyleBodyMedium),
                      ))
                  .toList(),
              onChanged: (d) => setState(() => _selectedDay = d),
            ),
          ),
        ],
        const SizedBox(height: kSpace4),
        Text('Type', style: kStyleCaptionMedium.copyWith(color: kColorInk)),
        const SizedBox(height: kSpace3),
        Wrap(
          spacing: kSpace2,
          runSpacing: kSpace2,
          children: ItineraryItemType.values.map((t) {
            final isSelected = t == _planItemType;
            return GestureDetector(
              onTap: () => setState(() => _planItemType = t),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace2),
                decoration: BoxDecoration(
                  color: isSelected ? kColorPrimary : kColorSurfaceSunken,
                  borderRadius: kRadiusMd,
                  border: Border.all(color: isSelected ? kColorPrimary : kColorBorder),
                ),
                child: Text(
                  t.label,
                  style: kStyleBodyMedium.copyWith(
                    color: isSelected ? kColorTextOnPrimary : kColorInk,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: kSpace4),
        WabwayTextField(
          label: 'Notes (optional)',
          controller: _planNotesCtrl,
          maxLines: 3,
        ),
        const SizedBox(height: kSpace5),
        Row(
          children: [
            Expanded(
              child: WabwayButton(
                label: 'Discard',
                variant: WabwayButtonVariant.ghost,
                onPressed: _handleDiscard,
                fullWidth: true,
              ),
            ),
            const SizedBox(width: kSpace3),
            Expanded(
              flex: 2,
              child: WabwayButton(
                label: 'Save plan item',
                icon: Icons.check_rounded,
                onPressed: _savePlanItem,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

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
                  if (_canSaveAsStay) ...[
                    _ParseItineraryBanner(
                      icon: Icons.hotel_rounded,
                      label: 'Save as stay',
                      subtitle: 'Parse listing details automatically',
                      scanning: _scanningStay,
                      disabled: _anyScan,
                      onTap: _saveAsStay,
                    ),
                    const SizedBox(height: kSpace4),
                  ],
                  Text(
                    'Details',
                    style: kStyleCaptionMedium.copyWith(color: kColorInkSoft),
                  ),
                  const SizedBox(height: kSpace3),
                  if (_destination == ShareDestination.planItem)
                    _buildPlanItemForm()
                  else
                    ShareForm(
                      key: ValueKey(_destination),
                      share: _activeShare,
                      destination: _destination!,
                      onSave: _handleSave,
                      onDiscard: _handleDiscard,
                    ),
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
            if (_canSaveAsStay) ...[
              _ParseItineraryBanner(
                icon: Icons.hotel_rounded,
                label: 'Save as stay',
                subtitle: 'Parse listing details automatically',
                scanning: _scanningStay,
                disabled: _anyScan,
                onTap: _saveAsStay,
              ),
              const SizedBox(height: kSpace4),
            ],
            Text(
              'Details',
              style: kStyleCaptionMedium.copyWith(color: kColorInkSoft),
            ),
            const SizedBox(height: kSpace3),
            if (_destination == ShareDestination.planItem)
              _buildPlanItemForm()
            else
              ShareForm(
                key: ValueKey(_destination),
                share: _activeShare,
                destination: _destination!,
                onSave: _handleSave,
                onDiscard: _handleDiscard,
              ),
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

class IncomingShareDemoLauncher extends StatefulWidget {
  const IncomingShareDemoLauncher({super.key});

  @override
  State<IncomingShareDemoLauncher> createState() =>
      _IncomingShareDemoLauncherState();
}

class _IncomingShareDemoLauncherState extends State<IncomingShareDemoLauncher> {
  int _shareIndex = 0;

  IncomingShare get _currentShare =>
      kMockIncomingShares[_shareIndex % kMockIncomingShares.length];

  void _launch() {
    final tripId = TripState.tripOf(context).id;
    final userId = ProfileState.of(context).id;
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
      };
}
