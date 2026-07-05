import 'package:flutter/material.dart';
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

  void _selectDestination(ShareDestination dest) {
    setState(() => _destination = dest);
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
        final url = widget.share.rawContent ?? '';
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
      };
}
