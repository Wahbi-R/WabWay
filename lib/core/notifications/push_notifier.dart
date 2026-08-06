import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../screens/notification_settings_screen.dart';

/// Fire-and-forget push via the send-notification Edge Function.
/// Checks the local notification pref key before sending — if the user
/// has disabled that category, the call is skipped entirely.
/// Errors are swallowed so a failed notification never breaks the UI flow.
Future<void> pushNotify({
  required String tripId,
  required String title,
  required String body,
  String? excludeUserId,
  Map<String, String> data = const {},
  String? prefKey, // one of kPrefNotif* constants — null means always send
}) async {
  if (kIsWeb) return;
  if (prefKey != null) {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(prefKey) ?? true)) return;
  }
  try {
    await Supabase.instance.client.functions.invoke(
      'send-notification',
      body: {
        'trip_id': tripId,
        'title': title,
        'body': body,
        if (excludeUserId != null) 'exclude_user_id': excludeUserId,
        'data': data,
      },
    );
  } catch (e) {
    debugPrint('[PushNotify] failed: $e');
  }
}
