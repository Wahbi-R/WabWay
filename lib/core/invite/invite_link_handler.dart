import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles invite links of the form:
///   https://wabway.wabble.ca/?invite=ABCD1234
///
/// On web the code is read from Uri.base query params on init.
/// On Android the app is launched via an App Link and the URL is forwarded
/// from MainActivity via the `ca.wabble.wabway/links` MethodChannel.
///
/// The pending code is persisted in SharedPreferences so it survives the
/// sign-up flow (new user gets link → signs up → invite is still waiting).
class InviteLinkHandler {
  InviteLinkHandler._();
  static final instance = InviteLinkHandler._();

  static const _channel = MethodChannel('ca.wabble.wabway/links');
  static const _prefKey = 'pending_invite_code';

  /// Reactive invite code waiting to be redeemed.
  final pendingCode = ValueNotifier<String?>(null);

  Future<void> init() async {
    // Restore any code left from a previous session (e.g. user got link,
    // opened app, had to sign up, code is still pending).
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    if (stored != null) pendingCode.value = stored;

    if (kIsWeb) {
      _initWeb();
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _initAndroid();
    }
  }

  void _initWeb() {
    final code = Uri.base.queryParameters['invite']?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) _setCode(code);
  }

  Future<void> _initAndroid() async {
    // Get the URL that launched the app (null if not launched from a link).
    try {
      final url = await _channel.invokeMethod<String>('getInitialLink');
      if (url != null) _parseAndSet(url);
    } catch (_) {}

    // Handle links that arrive while the app is already running.
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNewLink') {
        final url = call.arguments as String?;
        if (url != null) _parseAndSet(url);
      }
    });
  }

  void _parseAndSet(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final code = uri.queryParameters['invite']?.trim().toUpperCase();
    if (code != null && code.isNotEmpty) _setCode(code);
  }

  void _setCode(String code) {
    pendingCode.value = code;
    SharedPreferences.getInstance().then((p) => p.setString(_prefKey, code));
  }

  Future<void> clearCode() async {
    pendingCode.value = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  /// The shareable link for a given invite code.
  static String linkFor(String code) =>
      'https://wabway.wabble.ca/?invite=${Uri.encodeComponent(code)}';
}
