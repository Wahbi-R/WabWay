class AppProfile {
  const AppProfile({
    required this.id,
    required this.displayName,
    required this.email,
    this.avatarUrl,
    this.displayNameIsSet = true,
  });

  final String id;
  final String displayName;
  final String email;
  final String? avatarUrl;

  /// False when the user signed up via magic link and has never set a name.
  final bool displayNameIsSet;

  factory AppProfile.fromMap(Map<String, dynamic> map) {
    final rawName = map['display_name'] as String?;
    final email = map['email'] as String? ?? '';
    // The DB trigger sets display_name to the email prefix as a fallback for
    // magic-link users who never explicitly set a name. Detect that case so
    // we can prompt them for a real name on first sign-in.
    final emailPrefix = email.split('@').first.toLowerCase();
    final nameIsSet = rawName != null &&
        rawName.isNotEmpty &&
        rawName.toLowerCase() != emailPrefix;
    return AppProfile(
      id: map['id'] as String,
      displayName: rawName?.isNotEmpty == true ? rawName! : 'Traveller',
      displayNameIsSet: nameIsSet,
      email: email,
      avatarUrl: map['avatar_url'] as String?,
    );
  }

  AppProfile copyWith({String? displayName, bool? displayNameIsSet}) => AppProfile(
        id: id,
        displayName: displayName ?? this.displayName,
        displayNameIsSet: displayNameIsSet ?? this.displayNameIsSet,
        email: email,
        avatarUrl: avatarUrl,
      );

  String get initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';
  }
}
