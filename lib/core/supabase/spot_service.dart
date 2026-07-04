import '../../data/spot_data.dart';
import 'client.dart';

abstract final class SpotService {
  // ─── Enum converters ────────────────────────────────────────────────────────

  static SpotCategory _catFrom(String s) => switch (s) {
        'food'       => SpotCategory.food,
        'landmark'   => SpotCategory.landmark,
        'nature'     => SpotCategory.nature,
        'experience' => SpotCategory.experience,
        'shopping'   => SpotCategory.shopping,
        'nightlife'  => SpotCategory.nightlife,
        _            => SpotCategory.landmark,
      };

  static String _catToDb(SpotCategory c) => switch (c) {
        SpotCategory.food       => 'food',
        SpotCategory.landmark   => 'landmark',
        SpotCategory.nature     => 'nature',
        SpotCategory.experience => 'experience',
        SpotCategory.shopping   => 'shopping',
        SpotCategory.nightlife  => 'nightlife',
      };

  static SpotStatus _statusFrom(String s) => switch (s) {
        'idea'       => SpotStatus.idea,
        'want_to_go' => SpotStatus.wantToGo,
        'must_do'    => SpotStatus.mustDo,
        'planned'    => SpotStatus.planned,
        'booked'     => SpotStatus.booked,
        'skipped'    => SpotStatus.skipped,
        _            => SpotStatus.idea,
      };

  static String _statusToDb(SpotStatus s) => switch (s) {
        SpotStatus.idea     => 'idea',
        SpotStatus.wantToGo => 'want_to_go',
        SpotStatus.mustDo   => 'must_do',
        SpotStatus.planned  => 'planned',
        SpotStatus.booked   => 'booked',
        SpotStatus.skipped  => 'skipped',
      };

  static VoteType _voteFrom(String s) => switch (s) {
        'must_do' => VoteType.mustDo,
        'want'    => VoteType.want,
        'maybe'   => VoteType.maybe,
        'skip'    => VoteType.skip,
        _         => VoteType.maybe,
      };

  static String _voteToDb(VoteType v) => switch (v) {
        VoteType.mustDo => 'must_do',
        VoteType.want   => 'want',
        VoteType.maybe  => 'maybe',
        VoteType.skip   => 'skip',
      };

  // ─── Row → model ────────────────────────────────────────────────────────────

  static Spot _spotFromRow(Map<String, dynamic> row) {
    final votesRaw = row['spot_votes'] as List? ?? [];
    final commentsRaw = (row['spot_comments'] as List? ?? [])
      ..sort((a, b) {
        final at = a['created_at'] as String? ?? '';
        final bt = b['created_at'] as String? ?? '';
        return at.compareTo(bt);
      });

    final mustDo = <String>[];
    final want   = <String>[];
    final maybe  = <String>[];
    final skip   = <String>[];
    for (final v in votesRaw) {
      final uid = v['user_id'] as String;
      switch (v['vote'] as String) {
        case 'must_do': mustDo.add(uid);
        case 'want':    want.add(uid);
        case 'maybe':   maybe.add(uid);
        case 'skip':    skip.add(uid);
      }
    }

    final comments = commentsRaw.map((c) => SpotComment(
          id:        c['id'] as String,
          authorId:  c['author_id'] as String,
          vote:      c['vote'] != null ? _voteFrom(c['vote'] as String) : null,
          text:      c['body'] as String,
          createdAt: DateTime.parse(c['created_at'] as String),
        )).toList();

    return Spot(
      id:          row['id'] as String,
      name:        row['name'] as String,
      city:        row['city'] as String,
      area:        row['area'] as String? ?? '',
      category:    _catFrom(row['category'] as String),
      status:      _statusFrom(row['status'] as String),
      sourceUrl:   row['source_url'] as String?,
      mapsUrl:     row['maps_url'] as String?,
      notes:       row['notes'] as String?,
      address:     row['address'] as String?,
      latitude:    (row['latitude'] as num?)?.toDouble(),
      longitude:   (row['longitude'] as num?)?.toDouble(),
      placeSource: row['place_source'] as String?,
      addedById:   row['added_by'] as String,
      votes:       SpotVotes(mustDo: mustDo, want: want, maybe: maybe, skip: skip),
      comments:    comments,
    );
  }

  static SpotComment _commentFromRow(Map<String, dynamic> row) => SpotComment(
        id:        row['id'] as String,
        authorId:  row['author_id'] as String,
        vote:      row['vote'] != null ? _voteFrom(row['vote'] as String) : null,
        text:      row['body'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  // ─── Queries ────────────────────────────────────────────────────────────────

  static Future<List<Spot>> loadSpots(String tripId) async {
    final data = await supabase
        .from('spots')
        .select('*, spot_votes(*), spot_comments(*)')
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);
    return data
        .map((r) => _spotFromRow(r))
        .toList();
  }

  static Future<Spot> createSpot({
    required String tripId,
    required String name,
    required String city,
    required String area,
    required SpotCategory category,
    required SpotStatus status,
    required String addedBy,
    String? sourceUrl,
    String? mapsUrl,
    String? notes,
    String? address,
    double? latitude,
    double? longitude,
    String? placeSource,
  }) async {
    final inserted = await supabase.from('spots').insert({
      'trip_id':  tripId,
      'name':     name.trim(),
      'city':     city.trim().isEmpty ? 'Unknown' : city.trim(),
      'area':     area.trim(),
      'category': _catToDb(category),
      'status':   _statusToDb(status),
      'added_by': addedBy,
      if (sourceUrl   != null && sourceUrl.trim().isNotEmpty)   'source_url':   sourceUrl.trim(),
      if (mapsUrl     != null && mapsUrl.trim().isNotEmpty)     'maps_url':     mapsUrl.trim(),
      if (notes       != null && notes.trim().isNotEmpty)       'notes':        notes.trim(),
      if (address     != null && address.trim().isNotEmpty)     'address':      address.trim(),
      if (latitude    != null)                                  'latitude':     latitude,
      if (longitude   != null)                                  'longitude':    longitude,
      if (placeSource != null && placeSource.trim().isNotEmpty) 'place_source': placeSource.trim(),
    }).select('*, spot_votes(*), spot_comments(*)').single();
    return _spotFromRow(inserted);
  }

  static Future<void> deleteSpot(String spotId) async {
    await supabase.from('spots').delete().eq('id', spotId);
  }

  // ─── Votes ──────────────────────────────────────────────────────────────────

  static Future<void> upsertVote({
    required String spotId,
    required String userId,
    required VoteType vote,
  }) async {
    await supabase.from('spot_votes').upsert({
      'spot_id': spotId,
      'user_id': userId,
      'vote':    _voteToDb(vote),
    });
  }

  static Future<void> deleteVote({
    required String spotId,
    required String userId,
  }) async {
    await supabase
        .from('spot_votes')
        .delete()
        .eq('spot_id', spotId)
        .eq('user_id', userId);
  }

  // ─── Comments ───────────────────────────────────────────────────────────────

  static Future<SpotComment> addComment({
    required String spotId,
    required String authorId,
    required String body,
    VoteType? vote,
  }) async {
    final row = await supabase.from('spot_comments').insert({
      'spot_id':   spotId,
      'author_id': authorId,
      'body':      body.trim(),
      if (vote != null) 'vote': _voteToDb(vote),
    }).select().single();
    return _commentFromRow(row);
  }
}
