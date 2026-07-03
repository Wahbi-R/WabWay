import 'package:flutter/material.dart';

// ─── Share content type ───────────────────────────────────────────────────────

enum ShareContentType {
  googleMapsLink,
  instagramLink,
  tiktokLink,
  youtubeLink,
  restaurantWebsite,
  blogArticle,
  pdfFile,
  receiptPhoto,
  screenshot;

  String get label => switch (this) {
        ShareContentType.googleMapsLink => 'Google Maps link',
        ShareContentType.instagramLink => 'Instagram link',
        ShareContentType.tiktokLink => 'TikTok link',
        ShareContentType.youtubeLink => 'YouTube link',
        ShareContentType.restaurantWebsite => 'Restaurant website',
        ShareContentType.blogArticle => 'Article or blog',
        ShareContentType.pdfFile => 'PDF file',
        ShareContentType.receiptPhoto => 'Receipt photo',
        ShareContentType.screenshot => 'Screenshot',
      };

  String get sourceName => switch (this) {
        ShareContentType.googleMapsLink => 'Google Maps',
        ShareContentType.instagramLink => 'Instagram',
        ShareContentType.tiktokLink => 'TikTok',
        ShareContentType.youtubeLink => 'YouTube',
        ShareContentType.restaurantWebsite => 'Web',
        ShareContentType.blogArticle => 'Web',
        ShareContentType.pdfFile => 'Files',
        ShareContentType.receiptPhoto => 'Photos',
        ShareContentType.screenshot => 'Photos',
      };

  IconData get icon => switch (this) {
        ShareContentType.googleMapsLink => Icons.map_rounded,
        ShareContentType.instagramLink => Icons.camera_alt_rounded,
        ShareContentType.tiktokLink => Icons.music_video_rounded,
        ShareContentType.youtubeLink => Icons.play_circle_rounded,
        ShareContentType.restaurantWebsite => Icons.restaurant_rounded,
        ShareContentType.blogArticle => Icons.article_rounded,
        ShareContentType.pdfFile => Icons.picture_as_pdf_rounded,
        ShareContentType.receiptPhoto => Icons.receipt_long_rounded,
        ShareContentType.screenshot => Icons.screenshot_monitor_rounded,
      };

  Color get color => switch (this) {
        ShareContentType.googleMapsLink => const Color(0xFF4A7AB5),
        ShareContentType.instagramLink => const Color(0xFFA97BB5),
        ShareContentType.tiktokLink => const Color(0xFF2F2A25),
        ShareContentType.youtubeLink => const Color(0xFFB94A48),
        ShareContentType.restaurantWebsite => const Color(0xFFC96F4A),
        ShareContentType.blogArticle => const Color(0xFF4A9B8A),
        ShareContentType.pdfFile => const Color(0xFFB94A48),
        ShareContentType.receiptPhoto => const Color(0xFF7D9A75),
        ShareContentType.screenshot => const Color(0xFF6F665D),
      };

  Color get softColor => switch (this) {
        ShareContentType.googleMapsLink => const Color(0xFFE8EEF6),
        ShareContentType.instagramLink => const Color(0xFFF4EEF7),
        ShareContentType.tiktokLink => const Color(0xFFEEEAE3),
        ShareContentType.youtubeLink => const Color(0xFFF5E8E8),
        ShareContentType.restaurantWebsite => const Color(0xFFF7EDE7),
        ShareContentType.blogArticle => const Color(0xFFE8F3F1),
        ShareContentType.pdfFile => const Color(0xFFF5E8E8),
        ShareContentType.receiptPhoto => const Color(0xFFEEF4EC),
        ShareContentType.screenshot => const Color(0xFFEEEAE3),
      };

  List<ShareDestination> get suggestedDestinations => switch (this) {
        ShareContentType.googleMapsLink => [ShareDestination.spot],
        ShareContentType.instagramLink => [
            ShareDestination.link,
            ShareDestination.spot
          ],
        ShareContentType.tiktokLink => [
            ShareDestination.link,
            ShareDestination.spot
          ],
        ShareContentType.youtubeLink => [ShareDestination.link],
        ShareContentType.restaurantWebsite => [
            ShareDestination.spot,
            ShareDestination.link
          ],
        ShareContentType.blogArticle => [ShareDestination.link],
        ShareContentType.pdfFile => [
            ShareDestination.document,
            ShareDestination.travelItem
          ],
        ShareContentType.receiptPhoto => [
            ShareDestination.receipt,
            ShareDestination.document
          ],
        ShareContentType.screenshot => [ShareDestination.document],
      };
}

// ─── Share destination ────────────────────────────────────────────────────────

enum ShareDestination {
  spot,
  link,
  travelItem,
  document,
  receipt,
  itineraryNote;

  String get label => switch (this) {
        ShareDestination.spot => 'Spot',
        ShareDestination.link => 'Link',
        ShareDestination.travelItem => 'Travel item',
        ShareDestination.document => 'Document',
        ShareDestination.receipt => 'Receipt',
        ShareDestination.itineraryNote => 'Itinerary note',
      };

  String get description => switch (this) {
        ShareDestination.spot => 'Save as a place to visit',
        ShareDestination.link => 'Save the URL with a title',
        ShareDestination.travelItem => 'Add to flights, hotels, or bookings',
        ShareDestination.document => 'Store as a trip document',
        ShareDestination.receipt => 'Log as a group expense',
        ShareDestination.itineraryNote => 'Add a note to a day',
      };

  IconData get icon => switch (this) {
        ShareDestination.spot => Icons.place_rounded,
        ShareDestination.link => Icons.link_rounded,
        ShareDestination.travelItem => Icons.flight_rounded,
        ShareDestination.document => Icons.description_rounded,
        ShareDestination.receipt => Icons.receipt_long_rounded,
        ShareDestination.itineraryNote => Icons.event_note_rounded,
      };

  Color get color => switch (this) {
        ShareDestination.spot => const Color(0xFFC96F4A),
        ShareDestination.link => const Color(0xFF4A7AB5),
        ShareDestination.travelItem => const Color(0xFF7D9A75),
        ShareDestination.document => const Color(0xFF5B6E8A),
        ShareDestination.receipt => const Color(0xFFD6A84F),
        ShareDestination.itineraryNote => const Color(0xFF4A9B8A),
      };

  Color get softColor => switch (this) {
        ShareDestination.spot => const Color(0xFFF7EDE7),
        ShareDestination.link => const Color(0xFFE8EEF6),
        ShareDestination.travelItem => const Color(0xFFEEF4EC),
        ShareDestination.document => const Color(0xFFECEEF2),
        ShareDestination.receipt => const Color(0xFFF8F0E2),
        ShareDestination.itineraryNote => const Color(0xFFE8F3F1),
      };
}

// ─── Incoming share model ─────────────────────────────────────────────────────

class IncomingShare {
  const IncomingShare({
    required this.id,
    required this.contentType,
    required this.rawContent,
    required this.detectedTitle,
    this.detectedDescription,
    this.sharedAt,
    this.filePath,
  });

  final String id;
  final ShareContentType contentType;
  final String rawContent;
  final String detectedTitle;
  final String? detectedDescription;
  final DateTime? sharedAt;
  /// Local file path for image/PDF shares. Null for text/URL shares.
  final String? filePath;
}

// ─── Content type detection (mock) ───────────────────────────────────────────

ShareContentType detectContentType(String rawContent) {
  final lower = rawContent.toLowerCase();
  if (lower.contains('maps.google.com') || lower.contains('goo.gl/maps')) {
    return ShareContentType.googleMapsLink;
  }
  if (lower.contains('instagram.com')) return ShareContentType.instagramLink;
  if (lower.contains('tiktok.com') || lower.contains('vm.tiktok.com')) {
    return ShareContentType.tiktokLink;
  }
  if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
    return ShareContentType.youtubeLink;
  }
  if (lower.endsWith('.pdf')) return ShareContentType.pdfFile;
  if (lower.startsWith('receipt:') || lower.contains('receipt')) {
    return ShareContentType.receiptPhoto;
  }
  if (lower.startsWith('screenshot:') || lower.endsWith('.png')) {
    return ShareContentType.screenshot;
  }
  if (lower.contains('restaurant') ||
      lower.contains('eatery') ||
      lower.contains('cafe') ||
      lower.contains('ramen') ||
      lower.contains('sushi')) {
    return ShareContentType.restaurantWebsite;
  }
  return ShareContentType.blogArticle;
}

// ─── Mock sample data ─────────────────────────────────────────────────────────

final kMockIncomingShares = <IncomingShare>[
  IncomingShare(
    id: 'share_1',
    contentType: ShareContentType.googleMapsLink,
    rawContent: 'https://maps.google.com/?q=Ichiran+Shinjuku',
    detectedTitle: 'Ichiran — Shinjuku',
    detectedDescription: 'Ramen restaurant in Shinjuku, Tokyo',
    sharedAt: DateTime(2024, 10, 15, 9, 30),
  ),
  IncomingShare(
    id: 'share_2',
    contentType: ShareContentType.instagramLink,
    rawContent: 'https://www.instagram.com/p/abc123/',
    detectedTitle: 'Arashiyama Bamboo Grove',
    detectedDescription: 'Stunning morning light through the bamboo forest',
    sharedAt: DateTime(2024, 10, 15, 11, 0),
  ),
  IncomingShare(
    id: 'share_3',
    contentType: ShareContentType.tiktokLink,
    rawContent: 'https://vm.tiktok.com/def456/',
    detectedTitle: 'Hidden ramen spots in Tokyo',
    detectedDescription: 'Must-try ramen shops locals actually visit',
    sharedAt: DateTime(2024, 10, 16, 14, 0),
  ),
  IncomingShare(
    id: 'share_4',
    contentType: ShareContentType.youtubeLink,
    rawContent: 'https://www.youtube.com/watch?v=ghi789',
    detectedTitle: 'Japan Travel Guide 2024 — What to know before you go',
    detectedDescription:
        'Tips for first-time visitors, transport, food, and budgeting',
    sharedAt: DateTime(2024, 10, 17, 16, 30),
  ),
  IncomingShare(
    id: 'share_5',
    contentType: ShareContentType.restaurantWebsite,
    rawContent: 'https://www.kyotoramen.jp/',
    detectedTitle: 'Kyoto Ramen — Honten',
    detectedDescription: 'Traditional tonkotsu ramen near Nijo Castle',
    sharedAt: DateTime(2024, 10, 18, 10, 0),
  ),
  IncomingShare(
    id: 'share_6',
    contentType: ShareContentType.blogArticle,
    rawContent: 'https://www.tokyotravelblog.com/best-spots-shibuya',
    detectedTitle: 'Best things to do in Shibuya — 2024',
    detectedDescription:
        'From the famous crossing to hidden neighbourhood finds',
    sharedAt: DateTime(2024, 10, 19, 8, 0),
  ),
  IncomingShare(
    id: 'share_7',
    contentType: ShareContentType.pdfFile,
    rawContent: 'jal_booking_confirmation.pdf',
    detectedTitle: 'JAL JL723 Booking Confirmation',
    detectedDescription: 'Flight confirmation — Narita, Nov 11',
    sharedAt: DateTime(2024, 10, 20, 12, 0),
  ),
  IncomingShare(
    id: 'share_8',
    contentType: ShareContentType.receiptPhoto,
    rawContent: 'receipt_photo_izakaya_kyoto.jpg',
    detectedTitle: 'Receipt — Izakaya Gion',
    detectedDescription: 'Photo of receipt from dinner on Nov 16',
    sharedAt: DateTime(2024, 11, 16, 22, 0),
  ),
  IncomingShare(
    id: 'share_9',
    contentType: ShareContentType.screenshot,
    rawContent: 'screenshot_teamlab_tickets.png',
    detectedTitle: 'Screenshot',
    detectedDescription: 'teamLab Borderless ticket confirmation screenshot',
    sharedAt: DateTime(2024, 10, 21, 15, 0),
  ),
];
