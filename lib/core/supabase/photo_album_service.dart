import '../../data/photo_album_data.dart';
import 'client.dart';

abstract final class PhotoAlbumService {
  static TripPhotoAlbum _fromRow(Map<String, dynamic> r) => TripPhotoAlbum(
        id:        r['id'] as String,
        tripId:    r['trip_id'] as String,
        addedById: r['added_by'] as String,
        title:     r['title'] as String,
        url:       r['url'] as String,
        service:   AlbumService.fromDb(r['service'] as String),
        note:      r['note'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  static Future<List<TripPhotoAlbum>> loadAlbums(String tripId) async {
    final data = await supabase
        .from('trip_photo_albums')
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);
    return (data as List).map((r) => _fromRow(r as Map<String, dynamic>)).toList();
  }

  static Future<TripPhotoAlbum> createAlbum({
    required String       tripId,
    required String       addedBy,
    required String       title,
    required String       url,
    required AlbumService service,
    String? note,
  }) async {
    final row = await supabase.from('trip_photo_albums').insert({
      'trip_id':  tripId,
      'added_by': addedBy,
      'title':    title.trim(),
      'url':      url.trim(),
      'service':  service.dbValue,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    }).select().single();
    return _fromRow(row as Map<String, dynamic>);
  }

  static Future<void> deleteAlbum(String albumId) async {
    await supabase.from('trip_photo_albums').delete().eq('id', albumId);
  }
}
