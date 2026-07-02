import 'package:supabase_flutter/supabase_flutter.dart';
import 'client.dart';

abstract final class AuthService {
  static Future<void> sendMagicLink(String email) =>
      supabase.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: true,
      );

  static Future<void> signInWithPassword({
    required String email,
    required String password,
  }) =>
      supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

  static Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final response = await supabase.auth.signUp(
      email: email.trim(),
      password: password,
      data: {'display_name': displayName.trim()},
    );
    // When email confirmation is on, Supabase returns a ghost response with
    // empty identities instead of throwing when the email already exists.
    if (response.user?.identities?.isEmpty == true) {
      throw const AuthException('user already registered');
    }
  }

  static Future<void> sendPasswordReset(String email) =>
      supabase.auth.resetPasswordForEmail(email.trim());

  static Future<void> updatePassword(String newPassword) =>
      supabase.auth.updateUser(UserAttributes(password: newPassword));

  static Future<void> updateDisplayName(String name) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await Future.wait<void>([
      supabase.auth.updateUser(
        UserAttributes(data: {'display_name': name.trim()}),
      ),
      supabase
          .from('profiles')
          .update({'display_name': name.trim()})
          .eq('id', uid),
    ]);
  }

  static Future<void> signOut() => supabase.auth.signOut();
}
