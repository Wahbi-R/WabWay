import 'package:flutter/material.dart';

// ─── Category ─────────────────────────────────────────────────────────────────

enum LinkCategory {
  general,
  food,
  accommodation,
  activity,
  shopping,
  article,
  social;

  String get label => switch (this) {
        LinkCategory.general       => 'General',
        LinkCategory.food          => 'Food & drink',
        LinkCategory.accommodation => 'Stay',
        LinkCategory.activity      => 'Activity',
        LinkCategory.shopping      => 'Shopping',
        LinkCategory.article       => 'Article',
        LinkCategory.social        => 'Social',
      };

  IconData get icon => switch (this) {
        LinkCategory.general       => Icons.link_rounded,
        LinkCategory.food          => Icons.restaurant_rounded,
        LinkCategory.accommodation => Icons.hotel_rounded,
        LinkCategory.activity      => Icons.local_activity_rounded,
        LinkCategory.shopping      => Icons.shopping_bag_rounded,
        LinkCategory.article       => Icons.article_rounded,
        LinkCategory.social        => Icons.camera_alt_rounded,
      };

  Color get color => switch (this) {
        LinkCategory.general       => const Color(0xFF6F8A9B),
        LinkCategory.food          => const Color(0xFFC96F4A),
        LinkCategory.accommodation => const Color(0xFF7D9A75),
        LinkCategory.activity      => const Color(0xFF4A9B8A),
        LinkCategory.shopping      => const Color(0xFFA97BB5),
        LinkCategory.article       => const Color(0xFF4A7AB5),
        LinkCategory.social        => const Color(0xFFB94A48),
      };

  Color get softColor => switch (this) {
        LinkCategory.general       => const Color(0xFFECF0F3),
        LinkCategory.food          => const Color(0xFFF7EDE7),
        LinkCategory.accommodation => const Color(0xFFEEF4EC),
        LinkCategory.activity      => const Color(0xFFE8F3F1),
        LinkCategory.shopping      => const Color(0xFFF4EEF7),
        LinkCategory.article       => const Color(0xFFE8EEF6),
        LinkCategory.social        => const Color(0xFFF5E8E8),
      };
}

// ─── Model ────────────────────────────────────────────────────────────────────

class TripLink {
  const TripLink({
    required this.id,
    required this.tripId,
    required this.addedById,
    required this.title,
    required this.url,
    required this.category,
    required this.createdAt,
    this.notes,
  });

  final String id;
  final String tripId;
  final String addedById;
  final String title;
  final String url;
  final LinkCategory category;
  final DateTime createdAt;
  final String? notes;

  String get domain {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    return host.isEmpty ? url : host;
  }
}
