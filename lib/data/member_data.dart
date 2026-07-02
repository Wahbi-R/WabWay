// ─── Member identity ──────────────────────────────────────────────────────────

class TripMember {
  const TripMember({required this.id, required this.name});
  final String id;
  final String name;
  bool get isYou => id == kYouId;
}

const kYouId = 'you';

const kMockMembers = <TripMember>[
  TripMember(id: 'you',    name: 'You'),
  TripMember(id: 'alex',   name: 'Alex'),
  TripMember(id: 'jordan', name: 'Jordan'),
  TripMember(id: 'sam',    name: 'Sam'),
];

TripMember memberById(String id) =>
    kMockMembers.firstWhere((m) => m.id == id,
        orElse: () => TripMember(id: id, name: id));
