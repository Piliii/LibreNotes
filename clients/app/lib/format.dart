// Small presentation helpers shared across the UI.

/// A compact, human "time ago" for note timestamps (ms since epoch).
String relativeTime(int ms) {
  final now = DateTime.now();
  final then = DateTime.fromMillisecondsSinceEpoch(ms);
  final diff = now.difference(then);

  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final label = '${months[then.month - 1]} ${then.day}';
  return then.year == now.year ? label : '$label ${then.year}';
}

/// How long a trashed note has left before auto-purge, e.g. "12 days left".
/// [deletedAtMs] is when it was trashed; reads "Deleting soon" once the
/// retention window has (nearly) run out. A [graceUntil] later than the
/// note's own deadline pushes the deadline out to it.
String trashRemainingLabel(
  int deletedAtMs, {
  required Duration retention,
  DateTime? graceUntil,
  DateTime? now,
}) {
  var deadline =
      DateTime.fromMillisecondsSinceEpoch(deletedAtMs).add(retention);
  if (graceUntil != null && graceUntil.isAfter(deadline)) {
    deadline = graceUntil;
  }
  final left = deadline.difference(now ?? DateTime.now());
  if (left <= Duration.zero) return 'Deleting soon';
  final days = (left.inMinutes / Duration.minutesPerDay).ceil();
  return days == 1 ? '1 day left' : '$days days left';
}

/// Body flattened to a single line for list/card previews.
String previewText(String body) => body.replaceAll(RegExp(r'\s*\n\s*'), ' ').trim();
