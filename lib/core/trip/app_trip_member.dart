import '../auth/app_profile.dart';

class AppTripMember {
  const AppTripMember({
    required this.userId,
    required this.role,
    required this.profile,
    this.arrivalDate,
    this.departureDate,
  });

  final String userId;
  final String role;
  final AppProfile profile;
  final DateTime? arrivalDate;
  final DateTime? departureDate;

  bool get isOwner => role == 'owner';
  bool get hasDates => arrivalDate != null || departureDate != null;

  factory AppTripMember.fromMap(Map<String, dynamic> map) {
    final profileMap = map['profiles'] as Map<String, dynamic>;
    return AppTripMember(
      userId:        map['user_id'] as String,
      role:          map['role'] as String,
      profile:       AppProfile.fromMap(profileMap),
      arrivalDate:   map['arrival_date'] != null ? DateTime.parse(map['arrival_date'] as String) : null,
      departureDate: map['departure_date'] != null ? DateTime.parse(map['departure_date'] as String) : null,
    );
  }
}
