// Shared display-format date helpers.
// DB/ISO formatting lives in each service file where `DateTime.toIso8601String()` is preferred.

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
];

// Returns "Jan 7" — used everywhere a short human-readable date is needed.
String fmtDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';
