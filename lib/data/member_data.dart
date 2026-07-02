// ─── Member identity ──────────────────────────────────────────────────────────

class TripMember {
  const TripMember({required this.id, required this.name});
  final String id;
  final String name;
  bool get isYou => id == kYouId;
}

// Mock fallback — used only for demo/test paths where live data is not loaded.
// Never mutated at runtime; connected screens pass real members explicitly.
const String kYouId = 'you';

const List<TripMember> kMockMembers = [
  TripMember(id: 'you',    name: 'You'),
  TripMember(id: 'alex',   name: 'Alex'),
  TripMember(id: 'jordan', name: 'Jordan'),
  TripMember(id: 'sam',    name: 'Sam'),
];

/// Looks up a member by ID.
///
/// Pass the active [members] list so the lookup uses real data. Falls back to
/// [kMockMembers] when [members] is omitted (demo / non-connected paths).
TripMember memberById(String id, [List<TripMember>? members]) =>
    (members ?? kMockMembers).firstWhere(
      (m) => m.id == id,
      orElse: () => TripMember(id: id, name: id),
    );
