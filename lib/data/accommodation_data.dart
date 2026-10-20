import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'date_utils.dart';
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
    this.checkInTime,
    this.checkOutTime,
    this.status = AccommodationStatus.brainstorming,
    this.source,
    this.notes,
    this.imageUrl,
    this.confirmationNumber,
    this.spotId,
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
  final String? checkInTime;  // "HH:MM" 24h — check-in from
  final String? checkOutTime; // "HH:MM" 24h — check-out by
  final AccommodationStatus status;
  final AccommodationSource? source;
  final String? notes;
  final String? imageUrl;
  final String? confirmationNumber;
  final String? spotId;
  final String createdBy;
  final DateTime createdAt;

  int? get nights {
    if (checkIn == null || checkOut == null) return null;
    return checkOut!.difference(checkIn!).inDays;
  }

  /// "Nov 11, 15:00" — check-in date plus time when known.
  String? get checkInLabel =>
      checkIn == null ? null : fmtDateTime(checkIn!, checkInTime);

  /// "Nov 16, 11:00" — check-out date plus time when known.
  String? get checkOutLabel =>
      checkOut == null ? null : fmtDateTime(checkOut!, checkOutTime);

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

  // Default for nullable fields copyWith can clear (pass null to clear).
  static const _keep = Object();

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
    Object? checkInTime = _keep,
    Object? checkOutTime = _keep,
    AccommodationStatus? status,
    AccommodationSource? source,
    String? notes,
    String? imageUrl,
    String? confirmationNumber,
    Object? spotId = _keep,
  }) => Accommodation(
    id:                 id,
    tripId:             tripId,
    name:               name ?? this.name,
    url:                url ?? this.url,
    city:               city ?? this.city,
    address:            address ?? this.address,
    latitude:           latitude ?? this.latitude,
    longitude:          longitude ?? this.longitude,
    pricePerNight:      pricePerNight ?? this.pricePerNight,
    currency:           currency ?? this.currency,
    checkIn:            checkIn ?? this.checkIn,
    checkOut:           checkOut ?? this.checkOut,
    checkInTime:        identical(checkInTime, _keep) ? this.checkInTime : checkInTime as String?,
    checkOutTime:       identical(checkOutTime, _keep) ? this.checkOutTime : checkOutTime as String?,
    status:             status ?? this.status,
    source:             source ?? this.source,
    notes:              notes ?? this.notes,
    imageUrl:           imageUrl ?? this.imageUrl,
    confirmationNumber: confirmationNumber ?? this.confirmationNumber,
    spotId:             identical(spotId, _keep) ? this.spotId : spotId as String?,
    createdBy:          createdBy,
    createdAt:          createdAt,
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
    checkInTime: '15:00',
    checkOutTime: '11:00',
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

