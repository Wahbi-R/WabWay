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
