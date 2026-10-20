// Shared date formatting helpers used across UI and service layers.

import 'package:flutter/material.dart' show TimeOfDay;

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

// Returns "Jan 7" — human-readable short date for display.
String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

// Returns "2025-07-10" — ISO 8601 date string for Supabase date columns.
String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// Returns "Jan 7, 2026" — full date for form fields and detail views.
String fmtDateLong(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

// Returns "Jul 3–9" (same month) or "Jul 30 – Aug 2".
String fmtDateRange(DateTime start, DateTime end) {
  if (start.year == end.year && start.month == end.month) {
    return '${_months[start.month - 1]} ${start.day}–${end.day}';
  }
  return '${fmtDate(start)} – ${fmtDate(end)}';
}

// Returns "09:30" — 24h time for form fields.
String fmtTimeOfDay(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

// Returns "Jan 7" or "Jan 7, 15:00" when an "HH:MM" time is known.
String fmtDateTime(DateTime d, String? time) =>
    time == null ? fmtDate(d) : '${fmtDate(d)}, $time';

// "HH:MM" (or Postgres "HH:MM:SS") → TimeOfDay; null when missing or malformed.
TimeOfDay? parseTimeOfDay(String? hhmm) {
  if (hhmm == null) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h > 23 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

// Postgres `time` columns come back as "15:00:00" — trim to "15:00".
String? hhmmFromDb(Object? raw) {
  final s = raw as String?;
  return (s != null && s.length >= 5) ? s.substring(0, 5) : s;
}
