// -- create table accommodations (
// --   id uuid primary key default gen_random_uuid(),
// --   trip_id uuid not null references trips(id) on delete cascade,
// --   name text not null,
// --   url text,
// --   city text not null default '',
// --   address text,
// --   latitude float8,
// --   longitude float8,
// --   price_per_night numeric,
// --   currency text not null default 'USD',
// --   check_in date,
// --   check_out date,
// --   status text not null default 'brainstorming',
// --   source text,
// --   notes text,
// --   image_url text,
// --   created_by uuid references auth.users(id),
// --   created_at timestamptz not null default now()
// -- );

import '../../data/accommodation_data.dart';
import 'client.dart';

abstract final class AccommodationService {
  // ─── Enum converters ────────────────────────────────────────────────────────

  static AccommodationStatus _statusFrom(String s) => switch (s) {
        'brainstorming' => AccommodationStatus.brainstorming,
        'shortlisted'   => AccommodationStatus.shortlisted,
        'booked'        => AccommodationStatus.booked,
        _               => AccommodationStatus.brainstorming,
      };

  static String _statusToDb(AccommodationStatus s) => switch (s) {
        AccommodationStatus.brainstorming => 'brainstorming',
        AccommodationStatus.shortlisted   => 'shortlisted',
        AccommodationStatus.booked        => 'booked',
      };

  static AccommodationSource? _sourceFrom(String? s) {
    if (s == null) return null;
    return switch (s) {
      'airbnb'  => AccommodationSource.airbnb,
      'booking' => AccommodationSource.booking,
      'expedia' => AccommodationSource.expedia,
      'avion'   => AccommodationSource.avion,
      'vrbo'    => AccommodationSource.vrbo,
      'hotels'  => AccommodationSource.hotels,
      'other'   => AccommodationSource.other,
      _         => AccommodationSource.other,
    };
  }

  static String _sourceToDb(AccommodationSource s) => switch (s) {
        AccommodationSource.airbnb   => 'airbnb',
        AccommodationSource.booking  => 'booking',
        AccommodationSource.expedia  => 'expedia',
        AccommodationSource.avion    => 'avion',
        AccommodationSource.vrbo     => 'vrbo',
        AccommodationSource.hotels   => 'hotels',
        AccommodationSource.other    => 'other',
      };

  // ─── Row → model ────────────────────────────────────────────────────────────

  static Accommodation _fromRow(Map<String, dynamic> row) => Accommodation(
        id:            row['id'] as String,
        tripId:        row['trip_id'] as String,
        name:          row['name'] as String,
        url:           row['url'] as String?,
        city:          row['city'] as String? ?? '',
        address:       row['address'] as String?,
        latitude:      (row['latitude'] as num?)?.toDouble(),
        longitude:     (row['longitude'] as num?)?.toDouble(),
        pricePerNight: (row['price_per_night'] as num?)?.toDouble(),
        currency:      row['currency'] as String? ?? 'USD',
        checkIn:       row['check_in'] != null
            ? DateTime.tryParse(row['check_in'] as String)
            : null,
        checkOut:      row['check_out'] != null
            ? DateTime.tryParse(row['check_out'] as String)
            : null,
        status:        _statusFrom(row['status'] as String? ?? 'brainstorming'),
        source:        _sourceFrom(row['source'] as String?),
        notes:         row['notes'] as String?,
        imageUrl:      row['image_url'] as String?,
        createdBy:     row['created_by'] as String? ?? '',
        createdAt:     DateTime.parse(row['created_at'] as String),
      );

  // ─── Queries ────────────────────────────────────────────────────────────────

  static Future<List<Accommodation>> loadAll(String tripId) async {
    try {
      final data = await supabase
          .from('accommodations')
          .select('*')
          .eq('trip_id', tripId)
          .order('created_at', ascending: false);
      return data.map((r) => _fromRow(r)).toList();
    } catch (_) {
      return kMockAccommodations
          .where((a) => a.tripId == tripId || tripId.isEmpty)
          .toList();
    }
  }

  static Future<Accommodation> create({
    required String tripId,
    required String userId,
    required String name,
    required String city,
    String? url,
    String? address,
    double? lat,
    double? lon,
    double? pricePerNight,
    String currency = 'USD',
    DateTime? checkIn,
    DateTime? checkOut,
    AccommodationStatus status = AccommodationStatus.brainstorming,
    AccommodationSource? source,
    String? notes,
    String? imageUrl,
  }) async {
    final inserted = await supabase.from('accommodations').insert({
      'trip_id':         tripId,
      'name':            name.trim(),
      'city':            city.trim().isEmpty ? '' : city.trim(),
      'currency':        currency,
      'status':          _statusToDb(status),
      'created_by':      userId,
      if (url           != null && url.trim().isNotEmpty)     'url':             url.trim(),
      if (address       != null && address.trim().isNotEmpty) 'address':         address.trim(),
      if (lat           != null)                              'latitude':        lat,
      if (lon           != null)                              'longitude':       lon,
      if (pricePerNight != null)                              'price_per_night': pricePerNight,
      if (checkIn       != null)                              'check_in':        checkIn.toIso8601String().substring(0, 10),
      if (checkOut      != null)                              'check_out':       checkOut.toIso8601String().substring(0, 10),
      if (source        != null)                              'source':          _sourceToDb(source),
      if (notes         != null && notes.trim().isNotEmpty)   'notes':           notes.trim(),
      if (imageUrl      != null && imageUrl.trim().isNotEmpty)'image_url':       imageUrl.trim(),
    }).select('*').single();
    return _fromRow(inserted);
  }

  static Future<void> updateStatus(String id, AccommodationStatus status) async {
    await supabase
        .from('accommodations')
        .update({'status': _statusToDb(status)})
        .eq('id', id);
  }

  static Future<void> delete(String id) async {
    await supabase.from('accommodations').delete().eq('id', id);
  }
}
