import 'package:flutter/material.dart';

enum AutoLinkSource {
  spot,
  shopping,
  itinerary,
  travel,
  accommodation;

  String get label => switch (this) {
        AutoLinkSource.spot          => 'Spots',
        AutoLinkSource.shopping      => 'Shopping',
        AutoLinkSource.itinerary     => 'Itinerary',
        AutoLinkSource.travel        => 'Travel',
        AutoLinkSource.accommodation => 'Accommodations',
      };

  IconData get icon => switch (this) {
        AutoLinkSource.spot          => Icons.place_rounded,
        AutoLinkSource.shopping      => Icons.shopping_bag_rounded,
        AutoLinkSource.itinerary     => Icons.event_note_rounded,
        AutoLinkSource.travel        => Icons.flight_rounded,
        AutoLinkSource.accommodation => Icons.hotel_rounded,
      };

  Color get color => switch (this) {
        AutoLinkSource.spot          => const Color(0xFF4A9B8A),
        AutoLinkSource.shopping      => const Color(0xFFA97BB5),
        AutoLinkSource.itinerary     => const Color(0xFF4A7AB5),
        AutoLinkSource.travel        => const Color(0xFFC96F4A),
        AutoLinkSource.accommodation => const Color(0xFF7D9A75),
      };

  Color get softColor => switch (this) {
        AutoLinkSource.spot          => const Color(0xFFE8F3F1),
        AutoLinkSource.shopping      => const Color(0xFFF4EEF7),
        AutoLinkSource.itinerary     => const Color(0xFFE8EEF6),
        AutoLinkSource.travel        => const Color(0xFFF7EDE7),
        AutoLinkSource.accommodation => const Color(0xFFEEF4EC),
      };
}

class AutoLink {
  const AutoLink({
    required this.source,
    required this.itemId,
    required this.itemName,
    required this.url,
  });

  final AutoLinkSource source;
  final String itemId;
  final String itemName;
  final String url;

  String get domain {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    return host.isEmpty ? url : host;
  }
}
