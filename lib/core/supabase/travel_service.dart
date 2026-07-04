import '../../data/travel_data.dart';
import 'client.dart';

abstract final class TravelService {
  // ── Enum converters ──────────────────────────────────────────────────────────

  static TravelItemType _typeFrom(String s) => switch (s) {
        'flight'      => TravelItemType.flight,
        'hotel'       => TravelItemType.hotel,
        'train'       => TravelItemType.train,
        'ticket'      => TravelItemType.ticket,
        'reservation' => TravelItemType.reservation,
        _             => TravelItemType.other,
      };

  static String _typeToDb(TravelItemType t) => switch (t) {
        TravelItemType.flight      => 'flight',
        TravelItemType.hotel       => 'hotel',
        TravelItemType.train       => 'train',
        TravelItemType.ticket      => 'ticket',
        TravelItemType.reservation => 'reservation',
        TravelItemType.other       => 'other',
      };

  // ── Row → model ──────────────────────────────────────────────────────────────

  static TravelItem _fromRow(Map<String, dynamic> row, List<String> docIds) {
    final rawDate    = row['date'] as String?;
    final rawEndDate = row['end_date'] as String?;
    final rawTime    = row['time'] as String?;
    final rawEndTime = row['end_time'] as String?;
    return TravelItem(
      id:                     row['id'] as String,
      title:                  row['title'] as String,
      type:                   _typeFrom(row['type'] as String),
      status:                 TravelBookingStatus.fromDb(row['status'] as String?),
      date:                   rawDate != null ? DateTime.parse(rawDate) : null,
      endDate:                rawEndDate != null ? DateTime.parse(rawEndDate) : null,
      time:                   rawTime?.substring(0, 5),
      endTime:                rawEndTime?.substring(0, 5),
      location:               row['location'] as String?,
      destination:            row['destination'] as String?,
      confirmationNumber:     row['confirmation_number'] as String?,
      address:                row['address'] as String?,
      notes:                  row['notes'] as String?,
      linkedDocIds:           docIds,
      linkedItineraryItemId:  row['linked_itinerary_item_id'] as String?,
      linkedDayId:            row['linked_day_id'] as String?,
    );
  }

  // ── Queries ──────────────────────────────────────────────────────────────────

  /// Loads all travel items for [tripId] and their document_links.
  static Future<List<TravelItem>> loadItems(String tripId) async {
    final itemsData = await supabase
        .from('travel_items')
        .select()
        .eq('trip_id', tripId)
        .order('date', ascending: true, nullsFirst: false);

    final itemIds = itemsData.map((r) => r['id'] as String).toList();
    final Map<String, List<String>> itemDocIds = {};
    if (itemIds.isNotEmpty) {
      final linksData = await supabase
          .from('document_links')
          .select('linked_id, document_id')
          .eq('linked_type', 'travel_item')
          .inFilter('linked_id', itemIds);
      for (final row in linksData) {
        (itemDocIds[row['linked_id'] as String] ??= []).add(row['document_id'] as String);
      }
    }

    return itemsData
        .map((r) => _fromRow(r, itemDocIds[r['id'] as String] ?? []))
        .toList();
  }

  // ── Mutations ─────────────────────────────────────────────────────────────────

  static Future<TravelItem> createItem({
    required String tripId,
    required String title,
    required TravelItemType type,
    required String createdBy,
    TravelBookingStatus status = TravelBookingStatus.booked,
    DateTime? date,
    DateTime? endDate,
    String? time,
    String? endTime,
    String? location,
    String? destination,
    String? confirmationNumber,
    String? address,
    String? notes,
    String? linkedItineraryItemId,
    String? linkedDayId,
    List<String> linkedDocIds = const [],
  }) async {
    final row = await supabase.from('travel_items').insert({
      'trip_id':    tripId,
      'title':      title.trim(),
      'type':       _typeToDb(type),
      'status':     status.toDb,
      'created_by': createdBy,
      if (date != null) 'date': _fmtDate(date),
      if (endDate != null) 'end_date': _fmtDate(endDate),
      if (time != null) 'time': time,
      if (endTime != null) 'end_time': endTime,
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
      if (destination != null && destination.trim().isNotEmpty)
        'destination': destination.trim(),
      if (confirmationNumber != null && confirmationNumber.trim().isNotEmpty)
        'confirmation_number': confirmationNumber.trim(),
      if (address != null && address.trim().isNotEmpty)
        'address': address.trim(),
      if (notes != null && notes.trim().isNotEmpty)
        'notes': notes.trim(),
      if (linkedItineraryItemId != null)
        'linked_itinerary_item_id': linkedItineraryItemId,
      if (linkedDayId != null)
        'linked_day_id': linkedDayId,
    }).select().single();

    final itemId = row['id'] as String;

    if (linkedDocIds.isNotEmpty) {
      await supabase.from('document_links').insert(
        linkedDocIds
            .map((docId) => {
                  'document_id': docId,
                  'linked_type': 'travel_item',
                  'linked_id':   itemId,
                  'created_by':  createdBy,
                })
            .toList(),
      );
    }

    return _fromRow(row, linkedDocIds);
  }

  static Future<void> updateItem(TravelItem item) async {
    await supabase.from('travel_items').update({
      'title':               item.title,
      'type':                _typeToDb(item.type),
      'status':              item.status.toDb,
      'date':                item.date != null ? _fmtDate(item.date!) : null,
      'end_date':            item.endDate != null ? _fmtDate(item.endDate!) : null,
      'time':                item.time,
      'end_time':            item.endTime,
      'location':            item.location,
      'destination':         item.destination,
      'confirmation_number': item.confirmationNumber,
      'address':             item.address,
      'notes':               item.notes,
    }).eq('id', item.id);
  }

  /// Syncs document links for a travel item: deletes removed, inserts new.
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
          .eq('linked_type', 'travel_item')
          .eq('linked_id', itemId)
          .inFilter('document_id', toRemove.toList());
    }
    if (toAdd.isNotEmpty) {
      await supabase.from('document_links').insert(
        toAdd.map((docId) => {
          'document_id': docId,
          'linked_type': 'travel_item',
          'linked_id':   itemId,
          'created_by':  userId,
        }).toList(),
      );
    }
  }

  static Future<void> deleteItem(String itemId) async {
    await supabase.from('travel_items').delete().eq('id', itemId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────────

  static String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
