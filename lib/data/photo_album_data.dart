import 'package:flutter/material.dart';

// ─── Service enum ─────────────────────────────────────────────────────────────

enum AlbumService {
  googlePhotos,
  icloud,
  dropbox,
  other;

  String get label => switch (this) {
        AlbumService.googlePhotos => 'Google Photos',
        AlbumService.icloud       => 'iCloud',
        AlbumService.dropbox      => 'Dropbox',
        AlbumService.other        => 'Album',
      };

  IconData get icon => switch (this) {
        AlbumService.googlePhotos => Icons.photo_library_rounded,
        AlbumService.icloud       => Icons.cloud_rounded,
        AlbumService.dropbox      => Icons.folder_special_rounded,
        AlbumService.other        => Icons.collections_rounded,
      };

  Color get color => switch (this) {
        AlbumService.googlePhotos => const Color(0xFF4285F4),
        AlbumService.icloud       => const Color(0xFF3478F6),
        AlbumService.dropbox      => const Color(0xFF0061FF),
        AlbumService.other        => const Color(0xFF6F8A9B),
      };

  Color get softColor => switch (this) {
        AlbumService.googlePhotos => const Color(0xFFE8F0FE),
        AlbumService.icloud       => const Color(0xFFE8F1FB),
        AlbumService.dropbox      => const Color(0xFFE6EFFF),
        AlbumService.other        => const Color(0xFFECF0F3),
      };

  String get dbValue => switch (this) {
        AlbumService.googlePhotos => 'google_photos',
        AlbumService.icloud       => 'icloud',
        AlbumService.dropbox      => 'dropbox',
        AlbumService.other        => 'other',
      };

  static AlbumService fromDb(String s) => switch (s) {
        'google_photos' => AlbumService.googlePhotos,
        'icloud'        => AlbumService.icloud,
        'dropbox'       => AlbumService.dropbox,
        _               => AlbumService.other,
      };

  static AlbumService fromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('photos.google') || lower.contains('goo.gl/photos')) {
      return AlbumService.googlePhotos;
    }
    if (lower.contains('icloud.com') || lower.contains('apple.com/shared-album')) {
      return AlbumService.icloud;
    }
    if (lower.contains('dropbox.com')) return AlbumService.dropbox;
    return AlbumService.other;
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class TripPhotoAlbum {
  const TripPhotoAlbum({
    required this.id,
    required this.tripId,
    required this.addedById,
    required this.title,
    required this.url,
    required this.service,
    required this.createdAt,
    this.note,
  });

  final String       id;
  final String       tripId;
  final String       addedById;
  final String       title;
  final String       url;
  final AlbumService service;
  final DateTime     createdAt;
  final String?      note;

  String get domain {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final host = uri.host.replaceFirst(RegExp(r'^www\.'), '');
    return host.isEmpty ? url : host;
  }
}
