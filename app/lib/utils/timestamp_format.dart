const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats an ISO-8601 timestamp as `17 Sep 2026, 09:14 UTC` — never a raw ISO string in a display row.
String formatDisplayTimestamp(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  try {
    final dt = DateTime.parse(iso).toUtc();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${_months[dt.month - 1]} ${dt.year}, $h:$m UTC';
  } catch (_) {
    return iso;
  }
}

/// Formats the elapsed duration between two ISO-8601 timestamps as `4.2 s`,
/// or `null` if either timestamp is missing/unparsable.
String? formatElapsedSeconds(String? createdAtIso, String? checkedAtIso) {
  if (createdAtIso == null || checkedAtIso == null) return null;
  try {
    final created = DateTime.parse(createdAtIso);
    final checked = DateTime.parse(checkedAtIso);
    final seconds = checked.difference(created).inMilliseconds / 1000;
    if (seconds < 0) return null;
    return '${seconds.toStringAsFixed(1)} s';
  } catch (_) {
    return null;
  }
}
