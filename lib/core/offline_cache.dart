import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

abstract final class OfflineCache {
  static SharedPreferences? _prefs;

  static Future<void> _init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> write(String key, dynamic jsonSerializable) async {
    try {
      await _init();
      await _prefs!.setString(key, jsonEncode(jsonSerializable));
    } catch (_) {}
  }

  static Future<T?> read<T>(String key, T Function(dynamic) fromJson) async {
    try {
      await _init();
      final raw = _prefs!.getString(key);
      if (raw == null) return null;
      return fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String key) async {
    try {
      await _init();
      await _prefs!.remove(key);
    } catch (_) {}
  }

  static String spotsKey(String tripId) => 'cache_spots_$tripId';
  static String docsKey(String tripId) => 'cache_docs_$tripId';
  static String planKey(String tripId) => 'cache_plan_$tripId';
}
