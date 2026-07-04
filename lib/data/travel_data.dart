import 'package:flutter/material.dart';

// ─── Booking status ───────────────────────────────────────────────────────────

enum TravelBookingStatus {
  booked,
  tentative,
  cancelled;

  String get label => switch (this) {
        TravelBookingStatus.booked    => 'Booked',
        TravelBookingStatus.tentative => 'Tentative',
        TravelBookingStatus.cancelled => 'Cancelled',
      };

  IconData get icon => switch (this) {
        TravelBookingStatus.booked    => Icons.check_circle_rounded,
        TravelBookingStatus.tentative => Icons.schedule_rounded,
        TravelBookingStatus.cancelled => Icons.cancel_rounded,
      };

  Color get color => switch (this) {
        TravelBookingStatus.booked    => const Color(0xFF3A8C5A),
        TravelBookingStatus.tentative => const Color(0xFFD6A84F),
        TravelBookingStatus.cancelled => const Color(0xFFB04040),
      };

  Color get softColor => switch (this) {
        TravelBookingStatus.booked    => const Color(0xFFE8F5EE),
        TravelBookingStatus.tentative => const Color(0xFFF8F0E2),
        TravelBookingStatus.cancelled => const Color(0xFFF5E8E8),
      };

  static TravelBookingStatus fromDb(String? s) => switch (s) {
        'tentative' => TravelBookingStatus.tentative,
        'cancelled' => TravelBookingStatus.cancelled,
        _           => TravelBookingStatus.booked,
      };

  String get toDb => switch (this) {
        TravelBookingStatus.booked    => 'booked',
        TravelBookingStatus.tentative => 'tentative',
        TravelBookingStatus.cancelled => 'cancelled',
      };
}

// ─── Travel item type ─────────────────────────────────────────────────────────

enum TravelItemType {
  flight,
  hotel,
  train,
  ticket,
  reservation,
  other;

  String get label => switch (this) {
        TravelItemType.flight => 'Flight',
        TravelItemType.hotel => 'Hotel',
        TravelItemType.train => 'Train',
        TravelItemType.ticket => 'Ticket',
        TravelItemType.reservation => 'Reservation',
        TravelItemType.other => 'Other',
      };

  IconData get icon => switch (this) {
        TravelItemType.flight => Icons.flight_rounded,
        TravelItemType.hotel => Icons.hotel_rounded,
        TravelItemType.train => Icons.train_rounded,
        TravelItemType.ticket => Icons.confirmation_number_rounded,
        TravelItemType.reservation => Icons.event_note_rounded,
        TravelItemType.other => Icons.circle_outlined,
      };

  Color get color => switch (this) {
        TravelItemType.flight => const Color(0xFF4A7AB5),
        TravelItemType.hotel => const Color(0xFFD6A84F),
        TravelItemType.train => const Color(0xFF7D9A75),
        TravelItemType.ticket => const Color(0xFFA97BB5),
        TravelItemType.reservation => const Color(0xFF4A9B8A),
        TravelItemType.other => const Color(0xFF6F665D),
      };

  Color get softColor => switch (this) {
        TravelItemType.flight => const Color(0xFFE8EEF6),
        TravelItemType.hotel => const Color(0xFFF8F0E2),
        TravelItemType.train => const Color(0xFFEEF4EC),
        TravelItemType.ticket => const Color(0xFFF5EEF7),
        TravelItemType.reservation => const Color(0xFFE8F4F2),
        TravelItemType.other => const Color(0xFFEEEAE3),
      };
}

// ─── Travel item ──────────────────────────────────────────────────────────────

class TravelItem {
  const TravelItem({
    required this.id,
    required this.title,
    required this.type,
    this.status = TravelBookingStatus.booked,
    this.date,
    this.endDate,
    this.time,
    this.endTime,
    this.location,
    this.destination,
    this.confirmationNumber,
    this.address,
    this.notes,
    this.linkedDocIds = const [],
    this.linkedItineraryItemId,
    this.linkedDayId,
  });

  final String id;
  final String title;
  final TravelItemType type;
  final TravelBookingStatus status;

  // Primary date (departure / check-in / event date)
  final DateTime? date;
  // End date for multi-day items (check-out, pass expiry)
  final DateTime? endDate;
  // "HH:MM" 24h — departure/start time
  final String? time;
  // "HH:MM" 24h — arrival/end time
  final String? endTime;
  // Origin city/airport/station, or property name for hotels
  final String? location;
  // Destination city/airport/station (transport only)
  final String? destination;
  // Booking/confirmation reference code
  final String? confirmationNumber;
  // Street address (hotels, venues)
  final String? address;
  final String? notes;
  final List<String> linkedDocIds;
  // Links to itinerary (plan_data.dart)
  final String? linkedItineraryItemId;
  final String? linkedDayId;

  bool get hasDate => date != null;
  bool get hasEndDate => endDate != null;
  bool get hasConfirmation => confirmationNumber != null;
  bool get isTransit =>
      type == TravelItemType.flight || type == TravelItemType.train;
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final kMockTravelItems = <TravelItem>[
  TravelItem(
    id: 't1',
    title: 'JAL JL723 — Outbound flight',
    type: TravelItemType.flight,
    date: DateTime(2024, 11, 11),
    time: '08:30',
    endTime: '15:40',
    location: 'London Heathrow (LHR)',
    destination: 'Narita International Airport (NRT)',
    confirmationNumber: 'JL723-LHR-NRT-2024',
    notes:
        'Terminal 5 departure. Online check-in opens 48h before. Meals included on this route. JAL Mileage Bank booking.',
    linkedDocIds: ['d1'],
    linkedItineraryItemId: 'i1_1',
    linkedDayId: 'day1',
  ),
  TravelItem(
    id: 't2',
    title: 'JAL JL724 — Return flight',
    type: TravelItemType.flight,
    date: DateTime(2024, 11, 20),
    time: '23:55',
    endTime: '05:20', // arrives next day London time
    location: 'Narita International Airport (NRT)',
    destination: 'London Heathrow (LHR)',
    confirmationNumber: 'JL724-NRT-LHR-2024',
    notes:
        'Terminal 2 at Narita. Online check-in closes 30 min before departure. Allow 2h for check-in + security.',
    linkedDocIds: ['d2'],
    linkedItineraryItemId: 'i10_3',
    linkedDayId: 'day10',
  ),
  TravelItem(
    id: 't3',
    title: 'Hotel Shinjuku',
    type: TravelItemType.hotel,
    date: DateTime(2024, 11, 11),
    endDate: DateTime(2024, 11, 14),
    time: '15:00',
    endTime: '11:00',
    location: 'Shinjuku, Tokyo',
    address: '7-chome Nishi-Shinjuku, Shinjuku City, Tokyo 160-0023',
    confirmationNumber: 'HSJ-2024-8847',
    notes:
        'Check-in from 15:00, check-out by 11:00. Breakfast included daily. Luggage storage available after check-out.',
    linkedDocIds: ['d3'],
    linkedItineraryItemId: 'i1_3',
    linkedDayId: 'day1',
  ),
  TravelItem(
    id: 't4',
    title: 'Kyoto Ryokan',
    type: TravelItemType.hotel,
    date: DateTime(2024, 11, 14),
    endDate: DateTime(2024, 11, 18),
    time: '15:00',
    endTime: '10:00',
    location: 'Higashiyama, Kyoto',
    address: '5 Yamatooji-dori, Higashiyama Ward, Kyoto 605-0825',
    confirmationNumber: 'RYK-2024-3329',
    notes:
        'Traditional ryokan with private onsen access. Yukata provided. Dinner at 19:00, breakfast at 08:00. No tattoos in communal baths.',
    linkedDocIds: ['d4'],
    linkedItineraryItemId: 'i4_3',
    linkedDayId: 'day4',
  ),
  TravelItem(
    id: 't5',
    title: 'Shinkansen Nozomi — Tokyo → Kyoto',
    type: TravelItemType.train,
    date: DateTime(2024, 11, 14),
    time: '14:16',
    endTime: '16:33',
    location: 'Tokyo Station',
    destination: 'Kyoto Station',
    confirmationNumber: 'NOZOMI-33-CAR6-S14',
    notes:
        'Nozomi 33. Reserved seats car 6, seats 14A–D. ~2h15m journey. JR Pass covers this route.',
    linkedDocIds: ['d5', 'd6'],
    linkedItineraryItemId: 'i4_2',
    linkedDayId: 'day4',
  ),
  TravelItem(
    id: 't6',
    title: 'Japan Rail Pass — 14 day',
    type: TravelItemType.train,
    date: DateTime(2024, 11, 11),
    endDate: DateTime(2024, 11, 25),
    location: 'All JR lines',
    confirmationNumber: 'JRP-14D-2024-7741',
    notes:
        'Valid Nov 11–25. Covers Shinkansen (except Nozomi/Mizuho on Tokaido line), N\'EX, and local JR trains. Exchange voucher at Narita airport JR office on arrival.',
    linkedDocIds: ['d6'],
  ),
  TravelItem(
    id: 't7',
    title: 'Narita Express — Narita → Shinjuku',
    type: TravelItemType.train,
    date: DateTime(2024, 11, 11),
    time: '17:10',
    endTime: '18:33',
    location: 'Narita Airport Station',
    destination: 'Shinjuku Station',
    notes:
        'JR Pass covers this. Takes ~80 min. Seats reserved at JR Pass exchange counter. Platform 1 at Narita T2.',
    linkedDocIds: ['d6'],
    linkedItineraryItemId: 'i1_2',
    linkedDayId: 'day1',
  ),
  TravelItem(
    id: 't8',
    title: 'teamLab Borderless — 4 tickets',
    type: TravelItemType.ticket,
    date: DateTime(2024, 11, 14),
    time: '10:00',
    location: 'Azabudai Hills, Minato City, Tokyo',
    address: 'Azabudai Hills Garden Plaza B, 4-1 Azabudai, Minato City',
    confirmationNumber: 'TLB-2024-88920',
    notes:
        'Timed entry at 10:00. 4 × ¥3,500. Wear comfortable shoes — no bags inside main space. No re-entry after exit.',
    linkedDocIds: ['d7'],
    linkedItineraryItemId: 'i4_1',
    linkedDayId: 'day4',
  ),
  TravelItem(
    id: 't9',
    title: 'Thermae-yu Onsen — day pass × 4',
    type: TravelItemType.reservation,
    date: DateTime(2024, 11, 13),
    time: '19:00',
    location: 'Kabukicho, Shinjuku, Tokyo',
    address: '1-1-2 Kabukicho, Shinjuku City, Tokyo 160-0021',
    notes:
        'No tattoos policy strictly enforced. Bring own towel or rent on-site (¥300). Mixed baths area open until 24:00. Locker deposit ¥100 (returned).',
    linkedItineraryItemId: 'i3_4',
    linkedDayId: 'day3',
  ),
  TravelItem(
    id: 't10',
    title: 'Izakaya group dinner reservation',
    type: TravelItemType.reservation,
    date: DateTime(2024, 11, 16),
    time: '20:00',
    location: 'Gion area, Kyoto',
    address: 'Hanamikoji Street, Gion, Higashiyama Ward, Kyoto',
    confirmationNumber: 'IZK-GIO-2024-512',
    notes:
        'Reserved for 4 people. Course menu ¥5,500/person. Big shared bill — settle here.',
    linkedItineraryItemId: 'i6_5',
    linkedDayId: 'day6',
  ),
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

String fmtTravelDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}';
}

String fmtTravelDateRange(DateTime start, DateTime end) {
  if (start.month == end.month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[start.month - 1]} ${start.day}–${end.day}';
  }
  return '${fmtTravelDate(start)} – ${fmtTravelDate(end)}';
}
