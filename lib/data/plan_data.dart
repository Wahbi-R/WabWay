import 'package:flutter/material.dart';

// ─── Item type ────────────────────────────────────────────────────────────────

enum ItineraryItemType {
  spot,
  travel,
  food,
  activity,
  freeTime,
  transport,
  other;

  String get label => switch (this) {
        ItineraryItemType.spot => 'Spot',
        ItineraryItemType.travel => 'Travel',
        ItineraryItemType.food => 'Food & Drink',
        ItineraryItemType.activity => 'Activity',
        ItineraryItemType.freeTime => 'Free Time',
        ItineraryItemType.transport => 'Transport',
        ItineraryItemType.other => 'Other',
      };

  IconData get icon => switch (this) {
        ItineraryItemType.spot => Icons.place_rounded,
        ItineraryItemType.travel => Icons.flight_rounded,
        ItineraryItemType.food => Icons.restaurant_rounded,
        ItineraryItemType.activity => Icons.camera_alt_rounded,
        ItineraryItemType.freeTime => Icons.self_improvement_rounded,
        ItineraryItemType.transport => Icons.train_rounded,
        ItineraryItemType.other => Icons.circle_outlined,
      };

  Color get color => switch (this) {
        ItineraryItemType.spot => const Color(0xFFC96F4A),
        ItineraryItemType.travel => const Color(0xFF4A7AB5),
        ItineraryItemType.food => const Color(0xFFD6A84F),
        ItineraryItemType.activity => const Color(0xFF7D9A75),
        ItineraryItemType.freeTime => const Color(0xFF8A7F75),
        ItineraryItemType.transport => const Color(0xFFC98A2E),
        ItineraryItemType.other => const Color(0xFF6F665D),
      };

  Color get softColor => switch (this) {
        ItineraryItemType.spot => const Color(0xFFF7EDE7),
        ItineraryItemType.travel => const Color(0xFFE8EEF6),
        ItineraryItemType.food => const Color(0xFFF8F0E2),
        ItineraryItemType.activity => const Color(0xFFEEF4EC),
        ItineraryItemType.freeTime => const Color(0xFFEEEAE3),
        ItineraryItemType.transport => const Color(0xFFF6EDDF),
        ItineraryItemType.other => const Color(0xFFEEEAE3),
      };
}

// ─── Itinerary item ───────────────────────────────────────────────────────────

class ItineraryItem {
  ItineraryItem({
    required this.id,
    required this.dayId,
    required this.title,
    required this.type,
    this.time,
    this.city,
    this.country,
    this.location,
    this.mapsUrl,
    this.confirmationUrl,
    this.notes,
    this.linkedSpotId,
    this.linkedDocIds = const [],
    this.sortOrder = 0,
    this.isDone = false,
  });

  final String id;
  final String dayId;
  final String title;
  final ItineraryItemType type;

  // "09:00" 24h format, null = flexible / no set time
  final String? time;
  final String? city;
  final String? country;
  final String? location;
  final String? mapsUrl;
  final String? confirmationUrl;
  final String? notes;
  final String? linkedSpotId;
  final List<String> linkedDocIds;
  final int sortOrder;
  final bool isDone;

  bool get hasTime => time != null;
  bool get hasLinks => linkedSpotId != null || linkedDocIds.isNotEmpty;

  ItineraryItem copyWith({bool? isDone}) => ItineraryItem(
        id:              id,
        dayId:           dayId,
        title:           title,
        type:            type,
        time:            time,
        city:            city,
        country:         country,
        location:        location,
        mapsUrl:         mapsUrl,
        confirmationUrl: confirmationUrl,
        notes:           notes,
        linkedSpotId:    linkedSpotId,
        linkedDocIds:    linkedDocIds,
        sortOrder:       sortOrder,
        isDone:          isDone ?? this.isDone,
      );
}

// ─── Trip day ─────────────────────────────────────────────────────────────────

class TripDay {
  TripDay({
    required this.id,
    required this.dayNumber,
    required this.date,
    required this.city,
    this.notes,
    List<ItineraryItem>? items,
  }) : items = items ?? [];

  final String id;
  final int dayNumber;
  final DateTime date;
  final String city;
  final String? notes;
  final List<ItineraryItem> items;

  List<ItineraryItem> get sortedItems {
    final timed = items.where((i) => i.hasTime).toList()
      ..sort((a, b) => a.time!.compareTo(b.time!));
    final flex = items.where((i) => !i.hasTime).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return [...timed, ...flex];
  }
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final kMockTripDays = <TripDay>[
  // ── Day 1: Nov 11 — Arrival ─────────────────────────────────────────────────
  TripDay(
    id: 'day1',
    dayNumber: 1,
    date: DateTime(2024, 11, 11),
    city: 'Tokyo',
    notes: 'Long travel day. Pick up IC cards at the airport.',
    items: [
      ItineraryItem(
        id: 'i1_1',
        dayId: 'day1',
        title: 'Arrive Narita Airport',
        type: ItineraryItemType.travel,
        time: '15:40',
        city: 'Tokyo',
        location: 'Narita International Airport',
        notes: 'JAL JL723. Terminal 2. Immigration + baggage claim.',
        linkedDocIds: ['d1'],
      ),
      ItineraryItem(
        id: 'i1_2',
        dayId: 'day1',
        title: 'Narita Express → Shinjuku',
        type: ItineraryItemType.transport,
        time: '17:10',
        city: 'Tokyo',
        location: 'Narita Airport Station → Shinjuku Station',
        notes: 'N\'EX takes ~80 min. JR Pass covers this.',
        linkedDocIds: ['d6'],
      ),
      ItineraryItem(
        id: 'i1_3',
        dayId: 'day1',
        title: 'Check in — Shinjuku Hotel',
        type: ItineraryItemType.activity,
        time: '19:00',
        city: 'Tokyo',
        location: 'Shinjuku, Tokyo',
        notes: '2 nights. Breakfast included.',
        linkedDocIds: ['d3'],
      ),
      ItineraryItem(
        id: 'i1_4',
        dayId: 'day1',
        title: 'Ramen dinner — Ichiran',
        type: ItineraryItemType.food,
        time: '20:30',
        city: 'Tokyo',
        location: 'Ichiran Shinjuku',
        linkedSpotId: null,
        notes: 'Solo booth ramen. Get the tonkotsu.',
      ),
    ],
  ),

  // ── Day 2: Nov 12 — Tokyo temples & markets ─────────────────────────────────
  TripDay(
    id: 'day2',
    dayNumber: 2,
    date: DateTime(2024, 11, 12),
    city: 'Tokyo',
    items: [
      ItineraryItem(
        id: 'i2_1',
        dayId: 'day2',
        title: 'Senso-ji Temple',
        type: ItineraryItemType.spot,
        time: '09:00',
        city: 'Tokyo',
        location: '2-3-1 Asakusa, Taito City',
        mapsUrl: 'https://maps.google.com/?q=Senso-ji+Temple+Tokyo',
        linkedSpotId: '1',
        notes: 'Arrive early to beat the crowds. Get omamori charms.',
      ),
      ItineraryItem(
        id: 'i2_2',
        dayId: 'day2',
        title: 'Tsukiji Outer Market — lunch',
        type: ItineraryItemType.food,
        time: '12:00',
        city: 'Tokyo',
        location: 'Tsukiji Outer Market, Chuo City',
        mapsUrl: 'https://maps.google.com/?q=Tsukiji+Outer+Market',
        linkedSpotId: '2',
        notes: 'Try the tamagoyaki and fresh sushi sets.',
      ),
      ItineraryItem(
        id: 'i2_3',
        dayId: 'day2',
        title: 'ATM cash withdrawal',
        type: ItineraryItemType.activity,
        time: '14:30',
        city: 'Tokyo',
        location: '7-Eleven Convenience Store, Shinjuku',
        notes: '¥50,000 withdrawal. 7-Eleven ATMs accept foreign cards.',
        linkedDocIds: ['d11'],
      ),
      ItineraryItem(
        id: 'i2_4',
        dayId: 'day2',
        title: 'Shibuya Crossing at dusk',
        type: ItineraryItemType.spot,
        time: '17:30',
        city: 'Tokyo',
        location: 'Shibuya Crossing, Shibuya',
        mapsUrl: 'https://maps.google.com/?q=Shibuya+Crossing+Tokyo',
        linkedSpotId: '6',
        notes: 'Go to Starbucks or Mag\'s Park for the overhead view.',
      ),
    ],
  ),

  // ── Day 3: Nov 13 — Parks & culture ─────────────────────────────────────────
  TripDay(
    id: 'day3',
    dayNumber: 3,
    date: DateTime(2024, 11, 13),
    city: 'Tokyo',
    notes: 'Quieter day. Garden in the morning, Harajuku in the afternoon.',
    items: [
      ItineraryItem(
        id: 'i3_1',
        dayId: 'day3',
        title: 'Shinjuku Gyoen garden',
        type: ItineraryItemType.activity,
        time: '10:00',
        city: 'Tokyo',
        location: '3-1 Naito-machi, Shinjuku City',
        mapsUrl: 'https://maps.google.com/?q=Shinjuku+Gyoen',
        notes: '¥500 entry. Beautiful in autumn colours.',
      ),
      ItineraryItem(
        id: 'i3_2',
        dayId: 'day3',
        title: 'Convenience store haul',
        type: ItineraryItemType.food,
        time: '12:30',
        city: 'Tokyo',
        notes: 'Onigiri, melon pan, matcha KitKat.',
      ),
      ItineraryItem(
        id: 'i3_3',
        dayId: 'day3',
        title: 'Harajuku + Takeshita Street',
        type: ItineraryItemType.activity,
        time: '14:00',
        city: 'Tokyo',
        location: 'Takeshita Street, Harajuku',
        mapsUrl: 'https://maps.google.com/?q=Takeshita+Street+Harajuku',
        notes: 'Crepes, thrift shops, and wild fashion.',
      ),
      ItineraryItem(
        id: 'i3_4',
        dayId: 'day3',
        title: 'Onsen day pass',
        type: ItineraryItemType.activity,
        time: '19:00',
        city: 'Tokyo',
        location: 'Thermae-yu, Kabukicho',
        notes: 'Bring own towel or rent on-site. No tattoos allowed.',
      ),
    ],
  ),

  // ── Day 4: Nov 14 — teamLab + Shinkansen ─────────────────────────────────────
  TripDay(
    id: 'day4',
    dayNumber: 4,
    date: DateTime(2024, 11, 14),
    city: 'Tokyo → Kyoto',
    notes: 'Big day — teamLab in the morning, bullet train to Kyoto in the afternoon.',
    items: [
      ItineraryItem(
        id: 'i4_1',
        dayId: 'day4',
        title: 'teamLab Borderless',
        type: ItineraryItemType.activity,
        time: '10:00',
        city: 'Tokyo',
        location: 'teamLab Borderless, Azabudai Hills',
        mapsUrl: 'https://maps.google.com/?q=teamLab+Borderless+Tokyo',
        confirmationUrl: 'https://borderless.teamlab.art/wr/',
        linkedSpotId: '8',
        linkedDocIds: ['d7'],
        notes: 'Timed entry at 10:00. Wear comfortable shoes. No bags inside.',
      ),
      ItineraryItem(
        id: 'i4_2',
        dayId: 'day4',
        title: 'Shinkansen Nozomi — Tokyo → Kyoto',
        type: ItineraryItemType.transport,
        time: '14:16',
        city: 'Tokyo → Kyoto',
        location: 'Tokyo Station → Kyoto Station',
        confirmationUrl: 'https://www.jrpass.com/',
        linkedDocIds: ['d5'],
        notes: 'Nozomi 33. Reserved seats car 6. ~2h15m journey.',
      ),
      ItineraryItem(
        id: 'i4_3',
        dayId: 'day4',
        title: 'Check in — Kyoto Ryokan',
        type: ItineraryItemType.activity,
        time: '17:00',
        city: 'Kyoto',
        location: 'Higashiyama district, Kyoto',
        notes: 'Traditional ryokan with onsen. Yukata provided. Dinner at 19:00.',
        linkedDocIds: ['d4'],
      ),
      ItineraryItem(
        id: 'i4_4',
        dayId: 'day4',
        title: 'Nishiki Market stroll',
        type: ItineraryItemType.spot,
        city: 'Kyoto',
        location: 'Nishiki Market, Nakagyo Ward',
        mapsUrl: 'https://maps.google.com/?q=Nishiki+Market+Kyoto',
        linkedSpotId: '7',
        notes: 'Flexible — go if time allows before sunset.',
      ),
    ],
  ),

  // ── Day 5: Nov 15 — Kyoto temples ────────────────────────────────────────────
  TripDay(
    id: 'day5',
    dayNumber: 5,
    date: DateTime(2024, 11, 15),
    city: 'Kyoto',
    items: [
      ItineraryItem(
        id: 'i5_1',
        dayId: 'day5',
        title: 'Fushimi Inari Taisha',
        type: ItineraryItemType.spot,
        time: '09:00',
        city: 'Kyoto',
        location: '68 Fukakusa Yabunouchicho, Fushimi Ward',
        mapsUrl: 'https://maps.google.com/?q=Fushimi+Inari+Taisha',
        linkedSpotId: '5',
        notes: 'Start the hike up early before crowds. Takes 2–3h for full loop.',
      ),
      ItineraryItem(
        id: 'i5_2',
        dayId: 'day5',
        title: 'Lunch in Fushimi',
        type: ItineraryItemType.food,
        time: '13:00',
        city: 'Kyoto',
        notes: 'Inari sushi near the shrine entrance.',
      ),
      ItineraryItem(
        id: 'i5_3',
        dayId: 'day5',
        title: 'Kinkaku-ji — Golden Pavilion',
        type: ItineraryItemType.activity,
        time: '15:00',
        city: 'Kyoto',
        location: '1 Kinkakujicho, Kita Ward',
        mapsUrl: 'https://maps.google.com/?q=Kinkaku-ji+Kyoto',
        notes: '¥500 entry. Very crowded — arrive at opening time if possible.',
      ),
      ItineraryItem(
        id: 'i5_4',
        dayId: 'day5',
        title: 'Ryokan kaiseki dinner',
        type: ItineraryItemType.food,
        time: '19:00',
        city: 'Kyoto',
        notes: 'Multi-course traditional dinner included with ryokan stay.',
        linkedDocIds: ['d4'],
      ),
    ],
  ),

  // ── Day 6: Nov 16 — Arashiyama & Gion ──────────────────────────────────────
  TripDay(
    id: 'day6',
    dayNumber: 6,
    date: DateTime(2024, 11, 16),
    city: 'Kyoto',
    items: [
      ItineraryItem(
        id: 'i6_1',
        dayId: 'day6',
        title: 'Arashiyama Bamboo Grove',
        type: ItineraryItemType.spot,
        time: '09:00',
        city: 'Kyoto',
        location: 'Sagaogurayama Tabuchiyamacho, Ukyo Ward',
        mapsUrl: 'https://maps.google.com/?q=Arashiyama+Bamboo+Grove',
        linkedSpotId: '3',
        notes: 'Early morning is quieter. Monkey Park nearby.',
      ),
      ItineraryItem(
        id: 'i6_2',
        dayId: 'day6',
        title: 'Togetsu-kyo Bridge',
        type: ItineraryItemType.activity,
        time: '11:00',
        city: 'Kyoto',
        location: 'Togetsu-kyo, Arashiyama',
      ),
      ItineraryItem(
        id: 'i6_3',
        dayId: 'day6',
        title: 'Free time + café',
        type: ItineraryItemType.freeTime,
        time: '13:00',
        city: 'Kyoto',
        notes: 'Rest, matcha café, souvenir shopping.',
      ),
      ItineraryItem(
        id: 'i6_4',
        dayId: 'day6',
        title: 'Gion District at dusk',
        type: ItineraryItemType.spot,
        time: '17:00',
        city: 'Kyoto',
        location: 'Gion, Higashiyama Ward',
        mapsUrl: 'https://maps.google.com/?q=Gion+District+Kyoto',
        linkedSpotId: '9',
        notes: 'Walk Hanamikoji Street. Good chance of seeing geiko/maiko.',
      ),
      ItineraryItem(
        id: 'i6_5',
        dayId: 'day6',
        title: 'Izakaya group dinner',
        type: ItineraryItemType.food,
        time: '20:00',
        city: 'Kyoto',
        location: 'Gion area izakaya',
        notes: 'Settle up here — big shared bill.',
      ),
    ],
  ),

  // ── Day 7: Nov 17 — Osaka day trip ──────────────────────────────────────────
  TripDay(
    id: 'day7',
    dayNumber: 7,
    date: DateTime(2024, 11, 17),
    city: 'Osaka (day trip)',
    notes: 'JR Pass covers Kyoto ↔ Osaka. Leave bags at ryokan.',
    items: [
      ItineraryItem(
        id: 'i7_1',
        dayId: 'day7',
        title: 'JR train to Osaka',
        type: ItineraryItemType.transport,
        time: '10:00',
        city: 'Kyoto → Osaka',
        location: 'Kyoto Station → Osaka Station',
        notes: '15 min on shinkansen or 30 min on JR rapid.',
        linkedDocIds: ['d6'],
      ),
      ItineraryItem(
        id: 'i7_2',
        dayId: 'day7',
        title: 'Dotonbori lunch',
        type: ItineraryItemType.food,
        time: '12:00',
        city: 'Osaka',
        location: 'Dotonbori, Namba',
        mapsUrl: 'https://maps.google.com/?q=Dotonbori+Osaka',
        linkedSpotId: '4',
        notes: 'Try takoyaki at Aizuya, kushikatsu at Daruma. Duck ramen too.',
      ),
      ItineraryItem(
        id: 'i7_3',
        dayId: 'day7',
        title: 'Osaka Castle',
        type: ItineraryItemType.activity,
        time: '14:00',
        city: 'Osaka',
        location: '1-1 Osakajo, Chuo Ward',
        mapsUrl: 'https://maps.google.com/?q=Osaka+Castle',
        notes: '¥600 museum entry. Nice park around it.',
      ),
      ItineraryItem(
        id: 'i7_4',
        dayId: 'day7',
        title: 'Return to Kyoto',
        type: ItineraryItemType.transport,
        time: '19:00',
        city: 'Osaka → Kyoto',
      ),
    ],
  ),

  // ── Day 8: Nov 18 — Rest + Nijo Castle ──────────────────────────────────────
  TripDay(
    id: 'day8',
    dayNumber: 8,
    date: DateTime(2024, 11, 18),
    city: 'Kyoto',
    notes: 'Flexible day. Last full day in Kyoto.',
    items: [
      ItineraryItem(
        id: 'i8_1',
        dayId: 'day8',
        title: 'Free morning',
        type: ItineraryItemType.freeTime,
        city: 'Kyoto',
        notes: 'Sleep in, onsen, or explore neighbourhood.',
      ),
      ItineraryItem(
        id: 'i8_2',
        dayId: 'day8',
        title: 'Nijo Castle',
        type: ItineraryItemType.activity,
        time: '13:00',
        city: 'Kyoto',
        location: '541 Nijojonishi-machi, Nakagyo Ward',
        mapsUrl: 'https://maps.google.com/?q=Nijo+Castle+Kyoto',
        notes: '¥620. Famous for the "nightingale floors".',
      ),
      ItineraryItem(
        id: 'i8_3',
        dayId: 'day8',
        title: 'Check out & head to Tokyo',
        type: ItineraryItemType.travel,
        time: '16:00',
        city: 'Kyoto → Tokyo',
        location: 'Kyoto Station',
        linkedDocIds: ['d5'],
        notes: 'Final Shinkansen back to Tokyo for the flight home.',
      ),
    ],
  ),

  // ── Day 9: Nov 19 — Last day in Tokyo ───────────────────────────────────────
  TripDay(
    id: 'day9',
    dayNumber: 9,
    date: DateTime(2024, 11, 19),
    city: 'Tokyo',
    notes: 'Last full day. Pack light — flight is tomorrow night.',
    items: [
      ItineraryItem(
        id: 'i9_1',
        dayId: 'day9',
        title: 'Shopping in Shinjuku',
        type: ItineraryItemType.activity,
        time: '11:00',
        city: 'Tokyo',
        location: 'Shinjuku, Tokyo',
        notes: 'Yodobashi Camera, Don Quijote, Isetan department store.',
      ),
      ItineraryItem(
        id: 'i9_2',
        dayId: 'day9',
        title: 'Farewell ramen dinner',
        type: ItineraryItemType.food,
        time: '19:00',
        city: 'Tokyo',
        notes: 'Choose anywhere — last meal counts.',
      ),
      ItineraryItem(
        id: 'i9_3',
        dayId: 'day9',
        title: 'Pack and rest',
        type: ItineraryItemType.freeTime,
        time: '21:00',
        city: 'Tokyo',
        notes: 'Early night — Narita Express tomorrow evening.',
      ),
    ],
  ),

  // ── Day 10: Nov 20 — Departure ───────────────────────────────────────────────
  TripDay(
    id: 'day10',
    dayNumber: 10,
    date: DateTime(2024, 11, 20),
    city: 'Tokyo',
    notes: 'Departure day. Narita Express takes ~80 min — allow plenty of time.',
    items: [
      ItineraryItem(
        id: 'i10_1',
        dayId: 'day10',
        title: 'Check out of hotel',
        type: ItineraryItemType.activity,
        time: '10:00',
        city: 'Tokyo',
        notes: 'Baggage storage available until departure.',
      ),
      ItineraryItem(
        id: 'i10_2',
        dayId: 'day10',
        title: 'Narita Express to airport',
        type: ItineraryItemType.transport,
        time: '20:00',
        city: 'Tokyo',
        location: 'Shinjuku Station → Narita Airport Terminal 2',
        notes: 'Allow 80 min + 2h check-in buffer before departure.',
        linkedDocIds: ['d6'],
      ),
      ItineraryItem(
        id: 'i10_3',
        dayId: 'day10',
        title: 'Depart — JAL JL724',
        type: ItineraryItemType.travel,
        time: '23:55',
        city: 'Tokyo',
        location: 'Narita International Airport, Terminal 2',
        notes: 'Online check-in closes 30 min before departure.',
        linkedDocIds: ['d2'],
      ),
    ],
  ),
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

String fmtDayDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];
  return '${months[d.month - 1]} ${d.day}';
}

ItineraryItem? itemById(List<TripDay> days, String id) {
  for (final day in days) {
    for (final item in day.items) {
      if (item.id == id) return item;
    }
  }
  return null;
}

TripDay? dayForItem(List<TripDay> days, String itemId) {
  for (final day in days) {
    if (day.items.any((i) => i.id == itemId)) return day;
  }
  return null;
}
