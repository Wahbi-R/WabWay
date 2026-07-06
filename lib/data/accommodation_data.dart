import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../widgets/wabway_badge.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum AccommodationStatus {
  brainstorming,
  shortlisted,
  booked;

  String get label => switch (this) {
    AccommodationStatus.brainstorming => 'Brainstorming',
    AccommodationStatus.shortlisted   => 'Shortlisted',
    AccommodationStatus.booked        => 'Booked',
  };

  Color get color => switch (this) {
    AccommodationStatus.brainstorming => kColorInkSoft,
    AccommodationStatus.shortlisted   => const Color(0xFFB8860B),
    AccommodationStatus.booked        => kColorSuccess,
  };

  WabwayBadgeTone get tone => switch (this) {
    AccommodationStatus.brainstorming => WabwayBadgeTone.neutral,
    AccommodationStatus.shortlisted   => WabwayBadgeTone.accent,
    AccommodationStatus.booked        => WabwayBadgeTone.success,
  };
}

enum AccommodationSource {
  airbnb,
  booking,
  expedia,
  avion,
  vrbo,
  hotels,
  other;

  String get label => switch (this) {
    AccommodationSource.airbnb   => 'Airbnb',
    AccommodationSource.booking  => 'Booking.com',
    AccommodationSource.expedia  => 'Expedia',
    AccommodationSource.avion    => 'Avion',
    AccommodationSource.vrbo     => 'VRBO',
    AccommodationSource.hotels   => 'Hotels.com',
    AccommodationSource.other    => 'Other',
  };

  IconData get icon => switch (this) {
    AccommodationSource.airbnb   => Icons.home_rounded,
    AccommodationSource.vrbo     => Icons.home_rounded,
    AccommodationSource.booking  => Icons.hotel_rounded,
    AccommodationSource.expedia  => Icons.hotel_rounded,
    AccommodationSource.hotels   => Icons.hotel_rounded,
    AccommodationSource.avion    => Icons.hotel_rounded,
    AccommodationSource.other    => Icons.link_rounded,
  };

  static AccommodationSource fromUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('airbnb.'))    return AccommodationSource.airbnb;
    if (lower.contains('booking.com')) return AccommodationSource.booking;
    if (lower.contains('expedia.'))   return AccommodationSource.expedia;
    if (lower.contains('avion.'))     return AccommodationSource.avion;
    if (lower.contains('vrbo.'))      return AccommodationSource.vrbo;
    if (lower.contains('hotels.com')) return AccommodationSource.hotels;
    return AccommodationSource.other;
  }
}

// ─── Accommodation ────────────────────────────────────────────────────────────

class Accommodation {
  const Accommodation({
    required this.id,
    required this.tripId,
    required this.name,
    this.url,
    required this.city,
    this.address,
    this.latitude,
    this.longitude,
    this.pricePerNight,
    this.currency = 'USD',
    this.checkIn,
    this.checkOut,
    this.status = AccommodationStatus.brainstorming,
    this.source,
    this.notes,
    this.imageUrl,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String name;
  final String? url;
  final String city;
  final String? address;
  final double? latitude;
  final double? longitude;
  final double? pricePerNight;
  final String currency;
  final DateTime? checkIn;
  final DateTime? checkOut;
  final AccommodationStatus status;
  final AccommodationSource? source;
  final String? notes;
  final String? imageUrl;
  final String createdBy;
  final DateTime createdAt;

  int? get nights {
    if (checkIn == null || checkOut == null) return null;
    return checkOut!.difference(checkIn!).inDays;
  }

  double? get totalPrice {
    final n = nights;
    if (pricePerNight == null || n == null) return null;
    return pricePerNight! * n;
  }

  AccommodationSource get detectedSource {
    if (source != null) return source!;
    if (url != null) return AccommodationSource.fromUrl(url!);
    return AccommodationSource.other;
  }

  Accommodation copyWith({
    String? name,
    String? url,
    String? city,
    String? address,
    double? latitude,
    double? longitude,
    double? pricePerNight,
    String? currency,
    DateTime? checkIn,
    DateTime? checkOut,
    AccommodationStatus? status,
    AccommodationSource? source,
    String? notes,
    String? imageUrl,
  }) => Accommodation(
    id:            id,
    tripId:        tripId,
    name:          name ?? this.name,
    url:           url ?? this.url,
    city:          city ?? this.city,
    address:       address ?? this.address,
    latitude:      latitude ?? this.latitude,
    longitude:     longitude ?? this.longitude,
    pricePerNight: pricePerNight ?? this.pricePerNight,
    currency:      currency ?? this.currency,
    checkIn:       checkIn ?? this.checkIn,
    checkOut:      checkOut ?? this.checkOut,
    status:        status ?? this.status,
    source:        source ?? this.source,
    notes:         notes ?? this.notes,
    imageUrl:      imageUrl ?? this.imageUrl,
    createdBy:     createdBy,
    createdAt:     createdAt,
  );
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final kMockAccommodations = <Accommodation>[
  Accommodation(
    id: 'acc_1',
    tripId: 'trip_mock',
    name: 'Cozy Shinjuku Apartment',
    url: 'https://www.airbnb.com/rooms/12345678',
    city: 'Shinjuku, Tokyo',
    address: '3-5-12 Kabukicho, Shinjuku-ku, Tokyo',
    pricePerNight: 12000,
    currency: 'JPY',
    checkIn: DateTime(2024, 11, 11),
    checkOut: DateTime(2024, 11, 16),
    status: AccommodationStatus.booked,
    source: AccommodationSource.airbnb,
    notes: 'Check-in after 3pm. Host leaves key in lockbox — code sent via Airbnb message.',
    imageUrl: null,
    createdBy: 'alex',
    createdAt: DateTime(2024, 10, 20, 14, 30),
  ),
  Accommodation(
    id: 'acc_2',
    tripId: 'trip_mock',
    name: 'APA Hotel Kyoto Ekimae',
    url: 'https://www.booking.com/hotel/jp/apa-kyoto-ekimae.html',
    city: 'Kyoto',
    address: '662 Higashishiokojicho, Shimogyo-ku, Kyoto',
    pricePerNight: 9500,
    currency: 'JPY',
    checkIn: DateTime(2024, 11, 16),
    checkOut: DateTime(2024, 11, 18),
    status: AccommodationStatus.shortlisted,
    source: AccommodationSource.booking,
    notes: 'Right next to Kyoto Station. Free cancellation until Nov 12.',
    imageUrl: null,
    createdBy: 'sam',
    createdAt: DateTime(2024, 10, 22, 9, 15),
  ),
  Accommodation(
    id: 'acc_3',
    tripId: 'trip_mock',
    name: 'Dotonbori River Loft',
    url: 'https://www.airbnb.com/rooms/87654321',
    city: 'Osaka',
    address: 'Namba, Chuo-ku, Osaka',
    pricePerNight: 14500,
    currency: 'JPY',
    status: AccommodationStatus.brainstorming,
    source: AccommodationSource.airbnb,
    notes: 'Views of the canal. Might be noisy at night — worth checking reviews.',
    imageUrl: null,
    createdBy: 'jordan',
    createdAt: DateTime(2024, 10, 25, 18, 0),
  ),
];

