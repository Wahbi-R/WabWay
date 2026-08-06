import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Top-level handler required by firebase_messaging for background messages.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // Flutter handles showing the notification automatically in background/terminated.
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _db = Supabase.instance.client;

  Future<void> init() async {
    if (kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      await _saveToken();
      // Refresh token if it rotates
      _messaging.onTokenRefresh.listen(_upsertToken);
    }
  }

  Future<void> _saveToken() async {
    final token = await _messaging.getToken();
    if (token != null) await _upsertToken(token);
  }

  Future<void> _upsertToken(String token) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    await _db.from('device_tokens').upsert(
      {'user_id': userId, 'token': token, 'platform': 'android', 'updated_at': DateTime.now().toIso8601String()},
      onConflict: 'user_id, token',
    );
  }

  // Call on sign-out so stale tokens don't receive notifications.
  Future<void> removeToken() async {
    final token = await _messaging.getToken();
    if (token == null) return;
    await _db.from('device_tokens').delete().eq('token', token);
    await _messaging.deleteToken();
  }
}
