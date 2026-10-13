// Shared date formatting helpers used across UI and service layers.

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
