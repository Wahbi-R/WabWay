import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Fire-and-forget helper — calls the send-notification Edge Function.
/// Errors are swallowed so a failed notification never breaks the UI flow.
Future<void> pushNotify({
  required String tripId,
  required String title,
  required String body,
  String? excludeUserId,
  Map<String, String> data = const {},
}) async {
  if (kIsWeb) return;
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
