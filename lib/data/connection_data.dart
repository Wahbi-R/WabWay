import 'package:flutter/material.dart';

enum EntityType {
  spot,
  planItem,
  travel,
  stay,
  doc,
  link;

  String get dbValue => switch (this) {
        EntityType.spot     => 'spot',
        EntityType.planItem => 'plan_item',
        EntityType.travel   => 'travel',
        EntityType.stay     => 'stay',
        EntityType.doc      => 'doc',
        EntityType.link     => 'link',
      };

  static EntityType fromDb(String v) => switch (v) {
        'spot'      => EntityType.spot,
        'plan_item' => EntityType.planItem,
        'travel'    => EntityType.travel,
        'stay'      => EntityType.stay,
        'doc'       => EntityType.doc,
        'link'      => EntityType.link,
        _           => throw ArgumentError('Unknown entity type: $v'),
      };

  String get label => switch (this) {
        EntityType.spot     => 'Spot',
        EntityType.planItem => 'Plan item',
        EntityType.travel   => 'Travel',
        EntityType.stay     => 'Stay',
        EntityType.doc      => 'Document',
        EntityType.link     => 'Link',
      };

  String get pluralLabel => switch (this) {
        EntityType.spot     => 'Spots',
        EntityType.planItem => 'Plan',
        EntityType.travel   => 'Travel',
        EntityType.stay     => 'Stays',
        EntityType.doc      => 'Docs',
        EntityType.link     => 'Links',
      };

  IconData get icon => switch (this) {
        EntityType.spot     => Icons.place_rounded,
        EntityType.planItem => Icons.event_note_rounded,
        EntityType.travel   => Icons.flight_rounded,
        EntityType.stay     => Icons.hotel_rounded,
        EntityType.doc      => Icons.insert_drive_file_rounded,
        EntityType.link     => Icons.link_rounded,
      };
}

class TripConnection {
  const TripConnection({
    required this.id,
    required this.tripId,
    required this.entityAType,
    required this.entityAId,
    required this.entityBType,
    required this.entityBId,
    required this.createdAt,
  });

  final String     id;
  final String     tripId;
  final EntityType entityAType;
  final String     entityAId;
  final EntityType entityBType;
  final String     entityBId;
  final DateTime   createdAt;

  // Returns the OTHER side of the connection relative to [myId].
  EntityType peerType(String myId) =>
      entityAId == myId ? entityBType : entityAType;
  String peerId(String myId) =>
      entityAId == myId ? entityBId : entityAId;
}

// Resolved connection — the peer entity's name is looked up at display time.
class ResolvedConnection {
  const ResolvedConnection({
    required this.connection,
    required this.peerType,
    required this.peerId,
    required this.peerName,
  });

  final TripConnection connection;
  final EntityType     peerType;
  final String         peerId;
  final String         peerName;
}
