import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ─── Event type ────────────────────────────────────────────────────────────────

enum ActivityEventType {
  spotAdded,
  receiptAdded,
  withdrawalAdded,
  travelItemAdded,
  planItemAdded,
  documentAdded,
  linkAdded,
  memberJoined,
  unknown;

  static ActivityEventType fromDb(String s) => switch (s) {
        'spot_added'         => ActivityEventType.spotAdded,
        'receipt_added'      => ActivityEventType.receiptAdded,
        'withdrawal_added'   => ActivityEventType.withdrawalAdded,
        'travel_item_added'  => ActivityEventType.travelItemAdded,
        'plan_item_added'    => ActivityEventType.planItemAdded,
        'document_added'     => ActivityEventType.documentAdded,
        'link_added'         => ActivityEventType.linkAdded,
        'member_joined'      => ActivityEventType.memberJoined,
        _                    => ActivityEventType.unknown,
      };

  String get verb => switch (this) {
        ActivityEventType.spotAdded       => 'added a spot',
        ActivityEventType.receiptAdded    => 'added a receipt',
        ActivityEventType.withdrawalAdded => 'logged a cash withdrawal',
        ActivityEventType.travelItemAdded => 'added a travel item',
        ActivityEventType.planItemAdded   => 'added a plan item',
        ActivityEventType.documentAdded   => 'uploaded a document',
        ActivityEventType.linkAdded       => 'saved a link',
        ActivityEventType.memberJoined    => 'joined the trip',
        ActivityEventType.unknown         => 'did something',
      };

  IconData get icon => switch (this) {
        ActivityEventType.spotAdded       => Icons.place_rounded,
        ActivityEventType.receiptAdded    => Icons.receipt_long_rounded,
        ActivityEventType.withdrawalAdded => Icons.local_atm_rounded,
        ActivityEventType.travelItemAdded => Icons.flight_rounded,
        ActivityEventType.planItemAdded   => Icons.calendar_month_rounded,
        ActivityEventType.documentAdded   => Icons.insert_drive_file_rounded,
        ActivityEventType.linkAdded       => Icons.link_rounded,
        ActivityEventType.memberJoined    => Icons.person_add_rounded,
        ActivityEventType.unknown         => Icons.circle_outlined,
      };

  Color get color => switch (this) {
        ActivityEventType.spotAdded       => kColorPrimary,
        ActivityEventType.receiptAdded    => const Color(0xFFC96F4A),
        ActivityEventType.withdrawalAdded => const Color(0xFF6F8A9B),
        ActivityEventType.travelItemAdded => const Color(0xFF4A9B8A),
        ActivityEventType.planItemAdded   => const Color(0xFF7D9A75),
        ActivityEventType.documentAdded   => const Color(0xFF4A7AB5),
        ActivityEventType.linkAdded       => const Color(0xFFA97BB5),
        ActivityEventType.memberJoined    => kColorSuccess,
        ActivityEventType.unknown         => kColorInkSoft,
      };

  Color get softColor => switch (this) {
        ActivityEventType.spotAdded       => kColorPrimarySoft,
        ActivityEventType.receiptAdded    => const Color(0xFFF7EDE7),
        ActivityEventType.withdrawalAdded => const Color(0xFFECF0F3),
        ActivityEventType.travelItemAdded => const Color(0xFFE8F3F1),
        ActivityEventType.planItemAdded   => const Color(0xFFEEF4EC),
        ActivityEventType.documentAdded   => const Color(0xFFE8EEF6),
        ActivityEventType.linkAdded       => const Color(0xFFF4EEF7),
        ActivityEventType.memberJoined    => const Color(0xFFE8F5EE),
        ActivityEventType.unknown         => kColorSurfaceSunken,
      };
}

// ─── Model ─────────────────────────────────────────────────────────────────────

class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.tripId,
    required this.actorId,
    required this.actorName,
    required this.type,
    required this.entityId,
    required this.createdAt,
    this.entityTitle,
    this.meta,
  });

  final String id;
  final String tripId;
  final String actorId;
  final String actorName;
  final ActivityEventType type;
  final String entityId;
  final String? entityTitle;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
}
