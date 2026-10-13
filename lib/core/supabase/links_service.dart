import '../../data/links_data.dart';
import 'client.dart';

/// Saved links. Since build 417 a link is stored as a `documents` row with a
/// `link_category` (one home for every saved URL). Older links still live in
/// `trip_links` and are read alongside, untouched; edits/deletes go to the
/// table each link came from ([TripLink.isDocument]).
abstract final class LinksService {
  static LinkCategory _catFrom(String? s) => switch (s) {
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

  /// Legacy `trip_links` row.
  static TripLink _fromLinkRow(Map<String, dynamic> r) => TripLink(
        id:        r['id'] as String,
        tripId:    r['trip_id'] as String,
        addedById: r['added_by'] as String,
        title:     r['title'] as String,
        url:       r['url'] as String,
        category:  _catFrom(r['category'] as String?),
        notes:     r['notes'] as String?,
        createdAt: DateTime.parse(r['created_at'] as String),
      );

  /// `documents` row with a link_category.
  static TripLink _fromDocRow(Map<String, dynamic> r) => TripLink(
        id:         r['id'] as String,
        tripId:     r['trip_id'] as String,
        addedById:  r['uploaded_by'] as String,
        title:      r['title'] as String,
        url:        (r['url'] as String?) ?? '',
        category:   _catFrom(r['link_category'] as String?),
        notes:      r['notes'] as String?,
        createdAt:  DateTime.parse(r['created_at'] as String),
        isDocument: true,
      );

  static Future<List<TripLink>> loadLinks(String tripId) async {
    final results = await Future.wait([
      supabase.from('trip_links').select().eq('trip_id', tripId),
      supabase
          .from('documents')
          .select()
          .eq('trip_id', tripId)
          .not('link_category', 'is', null),
    ]);
    return [
      ...results[0].map(_fromLinkRow),
      ...results[1].map(_fromDocRow),
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Future<TripLink> createLink({
    required String tripId,
    required String addedBy,
    required String title,
    required String url,
    required LinkCategory category,
    String? notes,
  }) async {
    final row = await supabase.from('documents').insert({
      'trip_id':       tripId,
      'uploaded_by':   addedBy,
      'title':         title.trim(),
      'type':          'other',
      'ext':           'url',
      'url':           url.trim(),
      'link_category': _catToDb(category),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    }).select().single();
    return _fromDocRow(row);
  }

  static Future<TripLink> updateLink(
    TripLink link, {
    required String title,
    required String url,
    required LinkCategory category,
    String? notes,
  }) async {
    final cleanNotes = notes != null && notes.trim().isNotEmpty ? notes.trim() : null;
    if (link.isDocument) {
      final row = await supabase
          .from('documents')
          .update({
            'title':         title.trim(),
            'url':           url.trim(),
            'link_category': _catToDb(category),
            'notes':         cleanNotes,
          })
          .eq('id', link.id)
          .select()
          .single();
      return _fromDocRow(row);
    }
    final row = await supabase
        .from('trip_links')
        .update({
          'title':    title.trim(),
          'url':      url.trim(),
          'category': _catToDb(category),
          'notes':    cleanNotes,
        })
        .eq('id', link.id)
        .select()
        .single();
    return _fromLinkRow(row);
  }

  static Future<void> deleteLink(TripLink link) async {
    await supabase
        .from(link.isDocument ? 'documents' : 'trip_links')
        .delete()
        .eq('id', link.id);
  }
}
