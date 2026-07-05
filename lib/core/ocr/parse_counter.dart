import 'package:shared_preferences/shared_preferences.dart';

/// Tracks daily Gemini vision API usage against the free-tier limit (1,500/day).
abstract final class ParseCounter {
  static const int dailyLimit = 1500;

  static String _key() {
    final now = DateTime.now();
    return 'gemini_parses_${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}';
  }

  static Future<int> todayCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_key()) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> increment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key   = _key();
      await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
    } catch (_) {}
  }

  static Future<int> remaining() async => dailyLimit - await todayCount();
}
