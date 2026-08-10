import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/app_profile.dart';
import '../supabase/client.dart';

class ProfileNotifier extends StateNotifier<AppProfile?> {
  ProfileNotifier() : super(null);

  void set(AppProfile? profile) => state = profile;

  Future<void> refresh() async {
    final userId = state?.id ?? supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) state = AppProfile.fromMap(data);
    } catch (_) {}
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, AppProfile?>((ref) => ProfileNotifier());
