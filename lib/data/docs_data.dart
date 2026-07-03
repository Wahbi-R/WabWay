import 'package:flutter/material.dart';

// ─── Doc type ─────────────────────────────────────────────────────────────────

enum DocType {
  flight,
  hotel,
  train,
  ticket,
  reservation,
  receipt,
  insurance,
  form,
  screenshot,
  other;

  String get label => switch (this) {
        DocType.flight => 'Flight',
        DocType.hotel => 'Hotel',
        DocType.train => 'Train',
        DocType.ticket => 'Ticket',
        DocType.reservation => 'Reservation',
        DocType.receipt => 'Receipt',
        DocType.insurance => 'Insurance',
        DocType.form => 'Form',
        DocType.screenshot => 'Screenshot',
        DocType.other => 'Other',
      };

  IconData get icon => switch (this) {
        DocType.flight => Icons.flight_rounded,
        DocType.hotel => Icons.hotel_rounded,
        DocType.train => Icons.train_rounded,
        DocType.ticket => Icons.confirmation_number_rounded,
        DocType.reservation => Icons.event_note_rounded,
        DocType.receipt => Icons.receipt_long_rounded,
        DocType.insurance => Icons.health_and_safety_rounded,
        DocType.form => Icons.description_rounded,
        DocType.screenshot => Icons.screenshot_monitor_rounded,
        DocType.other => Icons.insert_drive_file_rounded,
      };

  Color get color => switch (this) {
        DocType.flight => const Color(0xFF4A7AB5),
        DocType.hotel => const Color(0xFFD6A84F),
        DocType.train => const Color(0xFF7D9A75),
        DocType.ticket => const Color(0xFFA97BB5),
        DocType.reservation => const Color(0xFF4A9B8A),
        DocType.receipt => const Color(0xFFC96F4A),
        DocType.insurance => const Color(0xFF5B6E8A),
        DocType.form => const Color(0xFF6F665D),
        DocType.screenshot => const Color(0xFFD97B8A),
        DocType.other => const Color(0xFF8A7F75),
      };

  Color get softColor => switch (this) {
        DocType.flight => const Color(0xFFE8EEF6),
        DocType.hotel => const Color(0xFFF8F0E2),
        DocType.train => const Color(0xFFEEF4EC),
        DocType.ticket => const Color(0xFFF5EEF7),
        DocType.reservation => const Color(0xFFE8F4F2),
        DocType.receipt => const Color(0xFFF7EDE7),
        DocType.insurance => const Color(0xFFEBEFF4),
        DocType.form => const Color(0xFFEEEAE3),
        DocType.screenshot => const Color(0xFFF7EBEE),
        DocType.other => const Color(0xFFEEEAE3),
      };
}

// ─── Linked type ──────────────────────────────────────────────────────────────

enum DocLinkedType {
  spot,
  travelItem,
  receipt,
  cashWithdrawal,
  itineraryItem,
  itineraryDay,
  trip;

  String get label => switch (this) {
        DocLinkedType.spot => 'Spot',
        DocLinkedType.travelItem => 'Travel',
        DocLinkedType.receipt => 'Receipt',
        DocLinkedType.cashWithdrawal => 'Withdrawal',
        DocLinkedType.itineraryItem => 'Itinerary Item',
        DocLinkedType.itineraryDay => 'Itinerary Day',
        DocLinkedType.trip => 'Trip',
      };

  IconData get icon => switch (this) {
        DocLinkedType.spot => Icons.place_rounded,
        DocLinkedType.travelItem => Icons.flight_rounded,
        DocLinkedType.receipt => Icons.receipt_long_rounded,
        DocLinkedType.cashWithdrawal => Icons.atm_rounded,
        DocLinkedType.itineraryItem => Icons.event_rounded,
        DocLinkedType.itineraryDay => Icons.calendar_today_rounded,
        DocLinkedType.trip => Icons.luggage_rounded,
      };
}

// ─── Document link ────────────────────────────────────────────────────────────

class DocumentLink {
  const DocumentLink({
    required this.type,
    required this.linkedId,
  });
  final DocLinkedType type;
  final String linkedId;
}

// ─── Trip document ────────────────────────────────────────────────────────────

class TripDocument {
  const TripDocument({
    required this.id,
    required this.title,
    required this.type,
    required this.ext,
    required this.uploadedById,
    required this.uploadedAt,
    this.storagePath,
    this.fileSizeKb,
    this.amount,
    this.currency,
    this.notes,
    this.links = const [],
  });

  final String id;
  final String title;
  final DocType type;
  final String ext;
  final String uploadedById;
  final DateTime uploadedAt;
  final String? storagePath;
  final int? fileSizeKb;
  final double? amount;
  final String? currency;
  final String? notes;
  final List<DocumentLink> links;

  String get formattedSize {
    if (fileSizeKb == null) return '—';
    if (fileSizeKb! < 1024) return '$fileSizeKb KB';
    return '${(fileSizeKb! / 1024).toStringAsFixed(1)} MB';
  }

  String get extUpper => ext.toUpperCase();

  Color get extColor => switch (ext.toLowerCase()) {
        'pdf' => const Color(0xFFB94A48),
        'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => const Color(0xFF4F8A5B),
        'xlsx' || 'csv' => const Color(0xFF3A7A4A),
        'docx' || 'doc' => const Color(0xFF4A7AB5),
        _ => const Color(0xFF6F665D),
      };

  Color get extSoftColor => switch (ext.toLowerCase()) {
        'pdf' => const Color(0xFFF5E8E8),
        'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => const Color(0xFFEEF4EC),
        'xlsx' || 'csv' => const Color(0xFFEBF4EE),
        'docx' || 'doc' => const Color(0xFFE8EEF6),
        _ => const Color(0xFFEEEAE3),
      };

  bool get isImage {
    final e = ext.toLowerCase();
    return e == 'jpg' || e == 'jpeg' || e == 'png' || e == 'webp' || e == 'gif';
  }

  TripDocument copyWith({String? title}) => TripDocument(
        id: id,
        title: title ?? this.title,
        type: type,
        ext: ext,
        uploadedById: uploadedById,
        uploadedAt: uploadedAt,
        storagePath: storagePath,
        fileSizeKb: fileSizeKb,
        amount: amount,
        currency: currency,
        notes: notes,
        links: links,
      );
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final kMockDocuments = <TripDocument>[
  TripDocument(
    id: 'd1',
    title: 'JAL Flight JL723 — Narita',
    type: DocType.flight,
    ext: 'pdf',
    uploadedById: 'alex',
    uploadedAt: DateTime(2024, 10, 15),
    fileSizeKb: 245,
    notes: 'Outbound flight. Arrives Nov 11 at 3:40pm local time.',
    links: const [
      DocumentLink(type: DocLinkedType.trip, linkedId: 'trip1'),
    ],
  ),
  TripDocument(
    id: 'd2',
    title: 'Return Flight JL724',
    type: DocType.flight,
    ext: 'pdf',
    uploadedById: 'alex',
    uploadedAt: DateTime(2024, 10, 15),
    fileSizeKb: 220,
    notes: 'Departs Nov 20 at 11:55pm.',
    links: const [
      DocumentLink(type: DocLinkedType.trip, linkedId: 'trip1'),
    ],
  ),
  TripDocument(
    id: 'd3',
    title: 'Hotel Shinjuku Confirmation',
    type: DocType.hotel,
    ext: 'pdf',
    uploadedById: 'jordan',
    uploadedAt: DateTime(2024, 10, 20),
    fileSizeKb: 180,
    amount: 36000,
    currency: 'JPY',
    notes: 'Check-in Nov 12, check-out Nov 14. Breakfast included.',
    links: const [
      DocumentLink(type: DocLinkedType.receipt, linkedId: 'r3'),
    ],
  ),
  TripDocument(
    id: 'd4',
    title: 'Kyoto Ryokan Booking',
    type: DocType.hotel,
    ext: 'pdf',
    uploadedById: 'you',
    uploadedAt: DateTime(2024, 10, 25),
    fileSizeKb: 320,
    amount: 52000,
    currency: 'JPY',
    notes: 'Traditional ryokan with onsen. Dinner and breakfast included.',
    links: const [
      DocumentLink(type: DocLinkedType.receipt, linkedId: 'r7'),
    ],
  ),
  TripDocument(
    id: 'd5',
    title: 'Shinkansen Tickets × 4',
    type: DocType.train,
    ext: 'pdf',
    uploadedById: 'you',
    uploadedAt: DateTime(2024, 11, 1),
    fileSizeKb: 150,
    amount: 27400,
    currency: 'JPY',
    links: const [
      DocumentLink(type: DocLinkedType.receipt, linkedId: 'r2'),
    ],
  ),
  TripDocument(
    id: 'd6',
    title: 'Japan Rail Pass',
    type: DocType.train,
    ext: 'pdf',
    uploadedById: 'alex',
    uploadedAt: DateTime(2024, 9, 10),
    fileSizeKb: 890,
    notes: '14-day JR Pass. Valid Nov 11–25.',
    links: const [
      DocumentLink(type: DocLinkedType.trip, linkedId: 'trip1'),
    ],
  ),
  TripDocument(
    id: 'd7',
    title: 'teamLab Borderless Tickets',
    type: DocType.ticket,
    ext: 'pdf',
    uploadedById: 'alex',
    uploadedAt: DateTime(2024, 11, 5),
    fileSizeKb: 95,
    amount: 14000,
    currency: 'JPY',
    notes: '4 × ¥3,500. Nov 14 at 10:00am.',
    links: const [
      DocumentLink(type: DocLinkedType.receipt, linkedId: 'r6'),
      DocumentLink(type: DocLinkedType.spot, linkedId: '8'),
    ],
  ),
  TripDocument(
    id: 'd8',
    title: 'Travel Insurance Policy',
    type: DocType.insurance,
    ext: 'pdf',
    uploadedById: 'you',
    uploadedAt: DateTime(2024, 9, 28),
    fileSizeKb: 3800,
    notes: 'Emergency medical up to \$500k USD. 24/7 hotline: +1-800-555-0100.',
    links: const [
      DocumentLink(type: DocLinkedType.trip, linkedId: 'trip1'),
    ],
  ),
  TripDocument(
    id: 'd9',
    title: 'Customs Declaration Form',
    type: DocType.form,
    ext: 'pdf',
    uploadedById: 'jordan',
    uploadedAt: DateTime(2024, 11, 11),
    fileSizeKb: 45,
    links: const [
      DocumentLink(type: DocLinkedType.trip, linkedId: 'trip1'),
    ],
  ),
  TripDocument(
    id: 'd10',
    title: 'Ramen Ichiran Receipt Photo',
    type: DocType.receipt,
    ext: 'jpg',
    uploadedById: 'alex',
    uploadedAt: DateTime(2024, 11, 12),
    fileSizeKb: 1240,
    amount: 4800,
    currency: 'JPY',
    links: const [
      DocumentLink(type: DocLinkedType.receipt, linkedId: 'r1'),
    ],
  ),
  TripDocument(
    id: 'd11',
    title: '7-Eleven ATM Slip',
    type: DocType.receipt,
    ext: 'jpg',
    uploadedById: 'you',
    uploadedAt: DateTime(2024, 11, 12),
    fileSizeKb: 640,
    amount: 50000,
    currency: 'JPY',
    links: const [
      DocumentLink(type: DocLinkedType.cashWithdrawal, linkedId: 'w1'),
    ],
  ),
  TripDocument(
    id: 'd12',
    title: 'Dotonbori Night — Screenshot',
    type: DocType.screenshot,
    ext: 'png',
    uploadedById: 'sam',
    uploadedAt: DateTime(2024, 11, 18),
    fileSizeKb: 2100,
    links: const [
      DocumentLink(type: DocLinkedType.spot, linkedId: '4'),
    ],
  ),
];
