import '../auth/app_profile.dart';

class AppTripMember {
  const AppTripMember({
    required this.userId,
    required this.role,
    required this.profile,
  });

  final String userId;
  final String role;
  final AppProfile profile;

  bool get isOwner => role == 'owner';

  factory AppTripMember.fromMap(Map<String, dynamic> map) {
    final profileMap = map['profiles'] as Map<String, dynamic>;
    return AppTripMember(
      userId: map['user_id'] as String,
      role: map['role'] as String,
      profile: AppProfile.fromMap(profileMap),
    );
  }
}
