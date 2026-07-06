import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/ocr/gemini_parser.dart';
import '../../core/places/google_maps_parser.dart';
import '../../core/places/listing_parser.dart';
import '../../screens/accommodations/add_accommodation_sheet.dart';
import '../../core/ocr/itinerary_scanner.dart';
import '../../core/places/social_place_extractor.dart';
import '../../core/platform/platform_file.dart';
import '../../core/auth/profile_state.dart';
import '../../core/supabase/doc_service.dart';
import '../../core/supabase/links_service.dart';
import '../../core/supabase/money_service.dart';
import '../../core/supabase/spot_service.dart';
import '../../core/supabase/travel_service.dart';
import '../../core/trip/trip_state.dart';
import '../../data/docs_data.dart';
import '../../data/links_data.dart';
import '../../data/money_data.dart';
import '../../data/share_data.dart';
import '../../data/spot_data.dart';
import '../../data/travel_data.dart';
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

class IncomingShareScreen extends StatefulWidget {
  const IncomingShareScreen({
    super.key,
    required this.share,
    required this.tripId,
    required this.userId,
    this.onDone,
  });

  final IncomingShare share;
  final String tripId;
  final String userId;
  final VoidCallback? onDone;

  @override
  State<IncomingShareScreen> createState() => _IncomingShareScreenState();
}

class _IncomingShareScreenState extends State<IncomingShareScreen> {
  ShareDestination? _destination;
  bool _scanningAi     = false;
  bool _scanningOcr    = false;
  bool _scanningPlaces = false;
  bool _scanningStay   = false;
  bool _scanningMaps   = false;

  bool get _anyScan =>
      _scanningAi || _scanningOcr || _scanningPlaces || _scanningStay || _scanningMaps;

  void _selectDestination(ShareDestination dest) {
    setState(() => _destination = dest);
  }

  bool get _canParseItinerary =>
      !kIsWeb &&
      _destination == ShareDestination.travelItem &&
      widget.share.filePath != null &&
      (widget.share.contentType == ShareContentType.screenshot ||
          widget.share.contentType == ShareContentType.pdfFile ||
          widget.share.contentType == ShareContentType.receiptPhoto);

  bool get _canFindPlaces =>
      widget.share.contentType == ShareContentType.tiktokLink ||
      widget.share.contentType == ShareContentType.instagramLink;

  bool get _canImportMaps =>
      widget.share.contentType == ShareContentType.googleMapsLink;

  bool get _canSaveAsStay =>
      widget.share.contentType == ShareContentType.accommodationLink;

  Future<void> _saveAsStay() async {
    if (_anyScan) return;
    setState(() => _scanningStay = true);
    try {
      final url    = widget.share.rawContent;
      final result = await ListingParser.parse(url);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => AddAccommodationSheet(
          tripId:     widget.tripId,
          userId:     widget.userId,
          prefilled:  result,
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
      final result = await SocialPlaceExtractor.extract(widget.share.rawContent);
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
            places:    result.places,
            caption:   result.caption,
            sourceUrl: widget.share.rawContent,
            tripId:    widget.tripId,
            userId:    widget.userId,
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

  Future<void> _importFromMaps() async {
    if (_anyScan) return;
    setState(() => _scanningMaps = true);
    try {
      final result = await GoogleMapsParser.parse(widget.share.rawContent);
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
    final filePath = widget.share.filePath;
    if (filePath == null || _anyScan) return;
    setState(() => _scanningAi = true);
    try {
      final bytes  = await readFileAsBytes(filePath);
      final ext    = _extFromShare(filePath, widget.share.contentType);
      final result = await ItineraryScanner.scanWithAi(bytes, ext);
      if (!mounted) return;
      if (result.bookings.isEmpty) {
        final aiStatus = GeminiParser.lastHttpStatus;
        final msg = switch (aiStatus) {
          429  => 'AI quota exceeded — try OCR instead',
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
      await _pushResults(result, bytes, ext, filePath);
    } finally {
      if (mounted) setState(() => _scanningAi = false);
    }
  }

  Future<void> _parseWithOcr() async {
    final filePath = widget.share.filePath;
    if (filePath == null || _anyScan) return;
    setState(() => _scanningOcr = true);
    try {
      final bytes  = await readFileAsBytes(filePath);
      final ext    = _extFromShare(filePath, widget.share.contentType);
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
      await _pushResults(result, bytes, ext, filePath);
    } finally {
      if (mounted) setState(() => _scanningOcr = false);
    }
  }

  Future<void> _pushResults(
    ScanResult result,
    Uint8List bytes,
    String ext,
    String filePath,
  ) async {
    final fileName = filePath.split('/').last;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ParsedItineraryScreen(
          bookings:       result.bookings,
          tripId:         widget.tripId,
          userId:         widget.userId,
          sourceBytes:    bytes,
          sourceExt:      ext,
          sourceFileName: fileName,
          onDone: () {
            Navigator.pop(context);
            widget.onDone?.call();
          },
        ),
      ),
    );
  }

  Future<void> _handleSave(ShareSaveData data) async {
    final dest = _destination;
    if (dest == null) return;

    final tripId = widget.tripId;
    final userId = widget.userId;

    switch (dest) {
      case ShareDestination.spot:
        final isMaps = widget.share.contentType == ShareContentType.googleMapsLink;
        await SpotService.createSpot(
          tripId:      tripId,
          name:        data.title,
          city:        data.location ?? 'Unknown',
          area:        '',
          category:    _spotCategory(data.category),
          status:      SpotStatus.idea,
          addedBy:     userId,
          sourceUrl:   isMaps ? null : widget.share.rawContent,
          mapsUrl:     data.mapsUrl,
          notes:       data.notes.isEmpty ? null : data.notes,
          latitude:    data.latitude,
          longitude:   data.longitude,
          placeSource: data.placeSource,
        );

      case ShareDestination.document:
        final filePath = widget.share.filePath;
        if (filePath != null) {
          final bytes = await readFileAsBytes(filePath);
          final ext = filePath.split('.').last.toLowerCase();
          await DocService.uploadAndCreate(
            tripId: tripId,
            userId: userId,
            title: data.title,
            type: _docType(data.docType),
            ext: ext,
            bytes: bytes,
            fileSizeKb: (bytes.length / 1024).round(),
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
        final filePath = widget.share.filePath;
        if (filePath != null) {
          final bytes = await readFileAsBytes(filePath);
          final ext   = filePath.split('.').last.toLowerCase();
          travelDoc = await DocService.uploadAndCreate(
            tripId:     tripId,
            userId:     userId,
            title:      data.title,
            type:       _docType(data.docType),
            ext:        ext,
            bytes:      bytes,
            fileSizeKb: (bytes.length / 1024).round(),
            notes:      data.notes.isEmpty ? null : data.notes,
          );
        }
        final travelItem = await TravelService.createItem(
          tripId:    tripId,
          title:     data.title,
          type:      _travelItemType(data.travelType),
          createdBy: userId,
          date:      data.date,
          notes:     data.notes.isEmpty ? null : data.notes,
        );
        if (travelDoc != null) {
          await DocService.addLink(
            documentId: travelDoc.id,
            linkedType: DocLinkedType.travelItem,
            linkedId:   travelItem.id,
            createdBy:  userId,
          );
        }

      case ShareDestination.receipt:
        TripDocument? receiptDoc;
        final receiptFilePath = widget.share.filePath;
        if (receiptFilePath != null) {
          final bytes = await readFileAsBytes(receiptFilePath);
          final ext   = receiptFilePath.split('.').last.toLowerCase();
          receiptDoc = await DocService.uploadAndCreate(
            tripId:     tripId,
            userId:     userId,
            title:      data.title,
            type:       DocType.receipt,
            ext:        ext,
            bytes:      bytes,
            fileSizeKb: (bytes.length / 1024).round(),
          );
        }
        final amount = data.amount ?? 0.0;
        final receipt = await MoneyService.createReceipt(
          tripId:   tripId,
          paidBy:   userId,
          title:    data.title,
          amount:   amount,
          currency: 'JPY',
          category: _receiptCategory(data.category),
          date:     data.date ?? DateTime.now(),
          notes:    data.notes.isEmpty ? null : data.notes,
          splits:   [ReceiptSplit(memberId: userId, amount: amount)],
        );
        if (receiptDoc != null) {
          await DocService.addLink(
            documentId: receiptDoc.id,
            linkedType: DocLinkedType.receipt,
            linkedId:   receipt.id,
            createdBy:  userId,
          );
        }

      case ShareDestination.link:
        final url = widget.share.rawContent;
        if (url.isEmpty) return;
        await LinksService.createLink(
          tripId:   tripId,
          addedBy:  userId,
          title:    data.title,
          url:      url,
          category: _linkCategory(widget.share.contentType),
          notes:    data.notes.isEmpty ? null : data.notes,
        );

      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            '${dest.label} saving coming soon',
            style: kStyleBodyMedium.copyWith(color: kColorTextOnPrimary),
          ),
          backgroundColor: kColorPrimary,
          behavior: SnackBarBehavior.floating,
          shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
          margin: const EdgeInsets.all(kSpace4),
        ));
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

  /// Derives the file extension for [ItineraryScanner].
  /// Prefers the [contentType] enum (reliable) over splitting the file path
  /// (unreliable on Android — package-name dots pollute the result).
  static String _extFromShare(String filePath, ShareContentType contentType) {
    if (contentType == ShareContentType.pdfFile) return 'pdf';
    // For images, pull just the filename part before splitting on '.'.
    final filename = filePath.split('/').last;
    final dotIdx = filename.lastIndexOf('.');
    if (dotIdx >= 0 && dotIdx < filename.length - 1) {
      return filename.substring(dotIdx + 1).toLowerCase();
    }
    return contentType == ShareContentType.screenshot ? 'png' : '';
  }

  static SpotCategory _spotCategory(String? raw) => switch (raw) {
        'food'          => SpotCategory.food,
        'shopping'      => SpotCategory.shopping,
        'accommodation' => SpotCategory.experience,
        'attraction'    => SpotCategory.landmark,
        _               => SpotCategory.landmark,
      };

  static DocType _docType(String? raw) => switch (raw) {
        'flight'      => DocType.flight,
        'hotel'       => DocType.hotel,
        'ticket'      => DocType.ticket,
        'insurance'   => DocType.insurance,
        'screenshot'  => DocType.screenshot,
        _             => DocType.other,
      };

  static TravelItemType _travelItemType(String? raw) => switch (raw) {
        'flight'      => TravelItemType.flight,
        'hotel'       => TravelItemType.hotel,
        'train'       => TravelItemType.train,
        'ticket'      => TravelItemType.ticket,
        'reservation' => TravelItemType.reservation,
        _             => TravelItemType.other,
      };

  static ReceiptCategory _receiptCategory(String? raw) => switch (raw) {
        'food'          => ReceiptCategory.food,
        'transport'     => ReceiptCategory.transport,
        'accommodation' => ReceiptCategory.accommodation,
        'activity'      => ReceiptCategory.activity,
        'shopping'      => ReceiptCategory.shopping,
        _               => ReceiptCategory.other,
      };

  static LinkCategory _linkCategory(ShareContentType contentType) =>
      switch (contentType) {
        ShareContentType.instagramLink => LinkCategory.social,
        ShareContentType.tiktokLink    => LinkCategory.social,
        ShareContentType.youtubeLink   => LinkCategory.article,
        ShareContentType.blogArticle   => LinkCategory.article,
        _                              => LinkCategory.general,
      };

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    return Scaffold(
      backgroundColor: kColorCream,
      appBar: AppBar(
        title: Text('Add to trip', style: kStyleTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _handleDiscard,
          tooltip: 'Discard',
        ),
      ),
      body: isDesktop ? _buildDesktop() : _buildMobile(),
    );
  }

  // ─── Desktop ──────────────────────────────────────────────────────────────

  Widget _buildDesktop() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left panel: preview + content type info
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
                  ContentPreviewCard(share: widget.share),
                  const SizedBox(height: kSpace5),
                  _ContentTypeInfoCard(contentType: widget.share.contentType),
                ],
              ),
            ),
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: kColorBorder),
        // Right panel: destination selector + form
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kSpace5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DestinationSelector(
                  contentType: widget.share.contentType,
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
                  ShareForm(
                    key: ValueKey(_destination),
                    share: widget.share,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(kSpace4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContentPreviewCard(share: widget.share),
          const SizedBox(height: kSpace5),
          DestinationSelector(
            contentType: widget.share.contentType,
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
            ShareForm(
              key: ValueKey(_destination),
              share: widget.share,
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

// ─── Parse itinerary banner ────────────────────────────────────────────────────

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
  final String   label;
  final String   subtitle;
  final bool     scanning;
  final bool     disabled;
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
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: _blue),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Demo launcher — surfaces the share flow from the More screen ─────────────

class IncomingShareDemoLauncher extends StatefulWidget {
  const IncomingShareDemoLauncher({super.key});

  @override
  State<IncomingShareDemoLauncher> createState() =>
      _IncomingShareDemoLauncherState();
}

class _IncomingShareDemoLauncherState
    extends State<IncomingShareDemoLauncher> {
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
