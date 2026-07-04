import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();
  static final instance = AppLogger._();

  final _entries = <LogEntry>[];

  void log(String message, {String tag = 'APP'}) {
    final entry = LogEntry(
      time: DateTime.now(),
      tag: tag,
      message: message,
    );
    _entries.add(entry);
    if (_entries.length > 300) _entries.removeAt(0);
    debugPrint('[${entry.tag}] ${entry.message}');
  }

  void error(String message, {String tag = 'APP', Object? error}) {
    final full = error != null ? '$message\n  error: $error' : message;
    log(full, tag: tag);
  }

  List<LogEntry> get entries => List.unmodifiable(_entries);

  String get dump {
    return _entries
        .map((e) =>
            '[${_fmt(e.time)}] [${e.tag}] ${e.message}')
        .join('\n');
  }

  void clear() => _entries.clear();

  static String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}.'
      '${t.millisecond.toString().padLeft(3, '0')}';
}

class LogEntry {
  const LogEntry({
    required this.time,
    required this.tag,
    required this.message,
  });
  final DateTime time;
  final String tag;
  final String message;
}
