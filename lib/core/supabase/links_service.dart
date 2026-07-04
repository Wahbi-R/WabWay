import '../../data/links_data.dart';
import 'client.dart';

abstract final class LinksService {
  static LinkCategory _catFrom(String s) => switch (s) {
        'food'          => LinkCategory.food,
        'accommodation' => LinkCategory.accommodation,
        'activity'      => LinkCategory.activity,
        'shopping'      => LinkCategory.shopping,
        'article'       => LinkCategory.article,
        'social'        => LinkCategory.social,
        _               => LinkCategory.general,
      };

  static String _catToDb(LinkCategory c) => switch (c) {
        LinkCategory.general       => 'general',
        LinkCategory.food          => 'food',
        LinkCategory.accommodation => 'accommodation',
        LinkCategory.activity      => 'activity',
        LinkCategory.shopping      => 'shopping',
        LinkCategory.article       => 'article',
        LinkCategory.social        => 'social',
      };

  static TripLink _fromRow(Map<String, dynamic> r) => TripLink(
        id:        r['id'] as String,
        tripId:    r['trip_id'] as String,
        addedById: r['added_by'] as String,
        title:     r['title'] as String,
        url:       r['url'] as String,
        category:  _catFrom(r['category'] as String),
        notes:     r['notes'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  static Future<List<TripLink>> loadLinks(String tripId) async {
    final data = await supabase
        .from('trip_links')
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);
    return data.map(_fromRow).toList();
  }

  static Future<TripLink> createLink({
    required String tripId,
    required String addedBy,
    required String title,
    required String url,
    required LinkCategory category,
    String? notes,
  }) async {
    final row = await supabase.from('trip_links').insert({
      'trip_id':  tripId,
      'added_by': addedBy,
      'title':    title.trim(),
      'url':      url.trim(),
      'category': _catToDb(category),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    }).select().single();
    return _fromRow(row);
  }

  static Future<void> deleteLink(String linkId) async {
    await supabase.from('trip_links').delete().eq('id', linkId);
  }
}
