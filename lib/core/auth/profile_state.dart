import 'package:flutter/widgets.dart';
import 'app_profile.dart';

class ProfileState extends InheritedWidget {
  const ProfileState({
    super.key,
    required this.profile,
    required super.child,
    this.onRefresh,
  });

  final AppProfile profile;

  /// Call after mutating profile data (name, password) to re-fetch from DB.
  final VoidCallback? onRefresh;

  static AppProfile of(BuildContext context) {
    final state = context.dependOnInheritedWidgetOfExactType<ProfileState>();
    assert(state != null, 'ProfileState not found — widget must be below AuthGate');
    return state!.profile;
  }

  static AppProfile? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileState>()?.profile;

  /// Re-fetches the profile from DB — call after editing name or other fields.
  static void refresh(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileState>()?.onRefresh?.call();

  @override
  bool updateShouldNotify(ProfileState old) => profile.id != old.profile.id;
}
