import 'package:flutter/material.dart';
import '../../data/share_data.dart';
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
    this.onDone,
  });

  final IncomingShare share;
  final VoidCallback? onDone;

  @override
  State<IncomingShareScreen> createState() => _IncomingShareScreenState();
}

class _IncomingShareScreenState extends State<IncomingShareScreen> {
  ShareDestination? _destination;

  void _selectDestination(ShareDestination dest) {
    setState(() => _destination = dest);
  }

  void _handleSave() {
    final dest = _destination;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          dest != null
              ? 'Saved as ${dest.label.toLowerCase()}'
              : 'Saved',
          style: kStyleBodyMedium.copyWith(color: kColorTextOnPrimary),
        ),
        backgroundColor: kColorPrimary,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: kRadiusMd),
        margin: const EdgeInsets.all(kSpace4),
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onDone?.call();
    });
  }

  void _handleDiscard() {
    widget.onDone?.call();
  }

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IncomingShareScreen(
          share: _currentShare,
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
