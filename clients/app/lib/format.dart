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

  String two(int v) => v.toString().padLeft(2, '0');
  return '${then.year}-${two(then.month)}-${two(then.day)}';
}

/// First non-empty content, flattened to a single line for list/card previews.
/// Strips the most common markdown markers so previews read cleanly.
String previewText(String body) {
  final flat = body
      .replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '') // headings
      .replaceAll(RegExp(r'[*_`>~]'), '') // emphasis / code / quote marks
      .replaceAll(RegExp(r'^\s*[-+]\s+', multiLine: true), '• ') // bullets
      .replaceAll('\n', ' ')
      .trim();
  return flat.isEmpty ? '' : flat;
}
