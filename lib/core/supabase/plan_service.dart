import '../../core/offline_cache.dart';
import '../../data/date_utils.dart';
import '../../data/plan_data.dart';
import 'client.dart';
import 'connection_service.dart';

abstract final class PlanService {
  // ── Enum converters ──────────────────────────────────────────────────────────

  static ItineraryItemType _typeFrom(String s) => switch (s) {
        'spot'      => ItineraryItemType.spot,
        'travel'    => ItineraryItemType.travel,
        'food'      => ItineraryItemType.food,
        'activity'  => ItineraryItemType.activity,
        'free_time' => ItineraryItemType.freeTime,
        'transport' => ItineraryItemType.transport,
        _           => ItineraryItemType.other,
      };

  static String _typeToDb(ItineraryItemType t) => switch (t) {
        ItineraryItemType.spot      => 'spot',
        ItineraryItemType.travel    => 'travel',
        ItineraryItemType.food      => 'food',
        ItineraryItemType.activity  => 'activity',
        ItineraryItemType.freeTime  => 'free_time',
        ItineraryItemType.transport => 'transport',
        ItineraryItemType.other     => 'other',
      };

  // ── Row → model ──────────────────────────────────────────────────────────────

  static ItineraryItem _itemFromRow(
    Map<String, dynamic> row,
    List<String> docIds, {
    String? spotId,
  }) {
    // Postgres returns time as "HH:MM:SS"; the model uses "HH:MM".
    final rawTime = row['time'] as String?;
    final time = rawTime?.substring(0, 5);
    return ItineraryItem(
      id:              row['id'] as String,
      dayId:           row['day_id'] as String,
      title:           row['title'] as String,
      type:            _typeFrom(row['type'] as String),
      time:            time,
      city:            row['city'] as String?,
      country:         row['country'] as String?,
      location:        row['location'] as String?,
      mapsUrl:         row['maps_url'] as String?,
      confirmationUrl: row['confirmation_url'] as String?,
      notes:           row['notes'] as String?,
      linkedSpotId:    spotId,
      linkedDocIds:    docIds,
      sortOrder:       (row['sort_order'] as num?)?.toInt() ?? 0,
      isDone:          (row['is_done'] as bool?) ?? false,
      plannedCost:     (row['planned_cost'] as num?)?.toDouble(),
      currency:        row['currency'] as String?,
    );
  }

  static TripDay _dayFromRow(Map<String, dynamic> row, List<ItineraryItem> items) {
    return TripDay(
      id:        row['id'] as String,
      dayNumber: (row['day_number'] as num).toInt(),
      date:      DateTime.parse(row['date'] as String),
      city:      (row['city'] as String?) ?? '',
      notes:     row['notes'] as String?,
      items:     items,
    );
  }

  // ── Queries ──────────────────────────────────────────────────────────────────

  /// Loads all itinerary days and items for [tripId] in three round-trips:
  /// days → items → document_links for items.
  static Future<List<TripDay>> loadAll(String tripId) async {
    final daysData = await supabase
        .from('itinerary_days')
        .select()
        .eq('trip_id', tripId)
        .order('day_number');

    final itemsData = await supabase
        .from('itinerary_items')
        .select()
        .eq('trip_id', tripId)
        .order('sort_order');

    // Build a map of itemId → [docId, ...] from document_links
    final Map<String, List<String>> itemDocIds = {};
    final itemIds = itemsData.map((r) => r['id'] as String).toList();
    if (itemIds.isNotEmpty) {
      final linksData = await supabase
          .from('document_links')
          .select('linked_id, document_id')
          .eq('linked_type', 'itinerary_item')
          .inFilter('linked_id', itemIds);
      for (final row in linksData) {
        final itemId = row['linked_id'] as String;
        final docId  = row['document_id'] as String;
        (itemDocIds[itemId] ??= []).add(docId);
      }
    }

    // Load spot connections from trip_connections for all items.
    final spotMap = itemIds.isNotEmpty
        ? await ConnectionService.fetchSpotMapForItems(itemIds)
        : <String, String>{};

    final allItems = itemsData
        .map((r) => _itemFromRow(
              r,
              itemDocIds[r['id'] as String] ?? [],
              spotId: spotMap[r['id'] as String],
            ))
        .toList();

    // Group items by dayId
    final dayItems = <String, List<ItineraryItem>>{};
    for (final item in allItems) {
      (dayItems[item.dayId] ??= []).add(item);
    }

    final days = daysData
        .map<TripDay>((r) => _dayFromRow(r, dayItems[r['id'] as String] ?? []))
        .toList();
    OfflineCache.write(OfflineCache.planKey(tripId), days.map(_dayToJson).toList());
    return days;
  }

  static Map<String, dynamic> _itemToJson(ItineraryItem i) => {
    'id': i.id, 'day_id': i.dayId, 'title': i.title,
    'type': i.type.name, 'time': i.time, 'city': i.city,
    'country': i.country, 'location': i.location, 'maps_url': i.mapsUrl,
    'confirmation_url': i.confirmationUrl, 'notes': i.notes,
    'linked_spot_id': i.linkedSpotId, 'linked_doc_ids': i.linkedDocIds,
    'sort_order': i.sortOrder, 'is_done': i.isDone,
    'planned_cost': i.plannedCost, 'currency': i.currency,
  };

  static Map<String, dynamic> _dayToJson(TripDay d) => {
    'id': d.id, 'day_number': d.dayNumber,
    'date': d.date.toIso8601String(), 'city': d.city,
    'notes': d.notes, 'items': d.items.map(_itemToJson).toList(),
  };

  static ItineraryItem _itemFromJson(Map<String, dynamic> j) => ItineraryItem(
    id: j['id'] as String, dayId: j['day_id'] as String,
    title: j['title'] as String,
    type: ItineraryItemType.values.byName(j['type'] as String? ?? 'other'),
    time: j['time'] as String?, city: j['city'] as String?,
    country: j['country'] as String?, location: j['location'] as String?,
    mapsUrl: j['maps_url'] as String?, confirmationUrl: j['confirmation_url'] as String?,
    notes: j['notes'] as String?,
    linkedSpotId: j['linked_spot_id'] as String?,
    linkedDocIds: (j['linked_doc_ids'] as List?)?.cast<String>() ?? [],
    sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
    isDone: (j['is_done'] as bool?) ?? false,
    plannedCost: (j['planned_cost'] as num?)?.toDouble(),
    currency: j['currency'] as String?,
  );

  static TripDay _dayFromJson(Map<String, dynamic> j) => TripDay(
    id: j['id'] as String,
    dayNumber: (j['day_number'] as num).toInt(),
    date: DateTime.parse(j['date'] as String),
    city: j['city'] as String? ?? '',
    notes: j['notes'] as String?,
    items: (j['items'] as List?)
        ?.map((i) => _itemFromJson(Map<String, dynamic>.from(i as Map)))
        .toList() ?? [],
  );

  static Future<List<TripDay>?> loadFromCache(String tripId) =>
      OfflineCache.read(
        OfflineCache.planKey(tripId),
        (json) => (json as List)
            .map((d) => _dayFromJson(Map<String, dynamic>.from(d as Map)))
            .toList(),
      );

  // ── Mutations ─────────────────────────────────────────────────────────────────

  static Future<TripDay> createDay({
    required String tripId,
    required int dayNumber,
    required DateTime date,
    required String city,
    required String createdBy,
    String? notes,
  }) async {
    final row = await supabase.from('itinerary_days').insert({
      'trip_id':    tripId,
      'day_number': dayNumber,
      'date':       isoDate(date),
      'city':       city.trim(),
      'created_by': createdBy,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    }).select().single();
    return _dayFromRow(row, []);
  }

  static Future<ItineraryItem> createItem({
    required String tripId,
    required String dayId,
    required String title,
    required ItineraryItemType type,
    required String createdBy,
    String? time,
    String? city,
    String? country,
    String? location,
    String? mapsUrl,
    String? confirmationUrl,
    String? notes,
    String? linkedSpotId,
    List<String> linkedDocIds = const [],
    int sortOrder = 0,
    double? plannedCost,
    String? currency,
  }) async {
    final row = await supabase.from('itinerary_items').insert({
      'trip_id':    tripId,
      'day_id':     dayId,
      'title':      title.trim(),
      'type':       _typeToDb(type),
      'created_by': createdBy,
      'sort_order': sortOrder,
      if (time != null) 'time': time,
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (country != null && country.trim().isNotEmpty) 'country': country.trim(),
      if (location != null && location.trim().isNotEmpty) 'location': location.trim(),
      if (mapsUrl != null && mapsUrl.trim().isNotEmpty) 'maps_url': mapsUrl.trim(),
      if (confirmationUrl != null && confirmationUrl.trim().isNotEmpty)
        'confirmation_url': confirmationUrl.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      if (plannedCost != null) 'planned_cost': plannedCost,
      if (currency != null) 'currency': currency,
    }).select().single();

    final itemId = row['id'] as String;

    if (linkedDocIds.isNotEmpty) {
      await supabase.from('document_links').insert(
        linkedDocIds
            .map((docId) => {
                  'document_id': docId,
                  'linked_type': 'itinerary_item',
                  'linked_id':   itemId,
                  'created_by':  createdBy,
                })
            .toList(),
      );
    }

    return _itemFromRow(row, linkedDocIds);
  }

  static Future<void> updateItem(ItineraryItem item) async {
    await supabase.from('itinerary_items').update({
      'title':            item.title,
      'type':             _typeToDb(item.type),
      'time':             item.time,
      'city':             item.city,
      'country':          item.country,
      'location':         item.location,
      'maps_url':         item.mapsUrl,
      'confirmation_url': item.confirmationUrl,
      'notes':            item.notes,
      'is_done':          item.isDone,
      'planned_cost':     item.plannedCost,
      'currency':         item.currency,
    }).eq('id', item.id);
  }

  // Lightweight toggle — avoids sending the full payload on every checkbox tap.
  static Future<void> toggleDone(String itemId, {required bool done}) async {
    await supabase
        .from('itinerary_items')
        .update({'is_done': done})
        .eq('id', itemId);
  }

  static Future<void> deleteItem(String itemId) async {
    await supabase.from('itinerary_items').delete().eq('id', itemId);
  }

  static Future<void> deleteDay(String dayId) async {
    await supabase.from('itinerary_days').delete().eq('id', dayId);
  }

  static Future<void> updateDay(
    String dayId, {
    String? city,
    DateTime? date,
    String? notes,
    bool clearNotes = false,
  }) async {
    final updates = <String, dynamic>{
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (date != null) 'date': isoDate(date),
      if (clearNotes) 'notes': null
      else if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(),
    };
    if (updates.isEmpty) return;
    await supabase.from('itinerary_days').update(updates).eq('id', dayId);
  }

  static Future<void> moveItem(String itemId, String newDayId) async {
    await supabase
        .from('itinerary_items')
        .update({'day_id': newDayId})
        .eq('id', itemId);
  }

  static Future<ItineraryItem> duplicateItem(
    ItineraryItem item, {
    required String createdBy,
  }) async {
    final row = await supabase.from('itinerary_items').insert({
      'trip_id':    (await supabase
              .from('itinerary_items')
              .select('trip_id')
              .eq('id', item.id)
              .single())['trip_id'],
      'day_id':     item.dayId,
      'title':      '${item.title} (copy)',
      'type':       _typeToDb(item.type),
      'created_by': createdBy,
      'sort_order': 999,
      if (item.time != null) 'time': item.time,
      if (item.city != null) 'city': item.city,
      if (item.location != null) 'location': item.location,
      if (item.mapsUrl != null) 'maps_url': item.mapsUrl,
      if (item.confirmationUrl != null) 'confirmation_url': item.confirmationUrl,
      if (item.notes != null) 'notes': item.notes,
      if (item.linkedSpotId != null) 'linked_spot_id': item.linkedSpotId,
    }).select().single();
    return _itemFromRow(row, []);
  }

  static Future<void> reorderItemsInDay(List<ItineraryItem> items) async {
    for (var i = 0; i < items.length; i++) {
      if (items[i].sortOrder != i) {
        await supabase
            .from('itinerary_items')
            .update({'sort_order': i})
            .eq('id', items[i].id);
      }
    }
  }

  // ── Item comments ─────────────────────────────────────────────────────────────

  static Future<List<ItineraryItemComment>> fetchComments(String itemId) async {
    final rows = await supabase
        .from('itinerary_item_comments')
        .select()
        .eq('item_id', itemId)
        .order('created_at');
    return rows.map(ItineraryItemComment.fromMap).toList();
  }

  static Future<ItineraryItemComment> addComment({
    required String itemId,
    required String authorId,
    required String body,
  }) async {
    final row = await supabase
        .from('itinerary_item_comments')
        .insert({'item_id': itemId, 'author_id': authorId, 'body': body.trim()})
        .select()
        .single();
    return ItineraryItemComment.fromMap(row);
  }

  static Future<void> deleteComment(String commentId) async {
    await supabase.from('itinerary_item_comments').delete().eq('id', commentId);
  }

  static Future<void> syncDocLinks(
    String itemId,
    List<String> oldDocIds,
    List<String> newDocIds,
    String userId,
  ) async {
    final toRemove = oldDocIds.toSet().difference(newDocIds.toSet());
    final toAdd    = newDocIds.toSet().difference(oldDocIds.toSet());

    if (toRemove.isNotEmpty) {
      await supabase
          .from('document_links')
          .delete()
          .eq('linked_type', 'itinerary_item')
          .eq('linked_id', itemId)
          .inFilter('document_id', toRemove.toList());
    }
    if (toAdd.isNotEmpty) {
      await supabase.from('document_links').insert(
        toAdd.map((docId) => {
          'document_id': docId,
          'linked_type': 'itinerary_item',
          'linked_id':   itemId,
          'created_by':  userId,
        }).toList(),
      );
    }
  }

}
