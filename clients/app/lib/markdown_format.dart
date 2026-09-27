import 'package:flutter/services.dart';

/// Toggles a `**bold**`/`*italic*` marker pair around [text] — wraps it if
/// not already wrapped, strips the markers if it already is, so re-selecting
/// the same span and pressing the same action again is idempotent (select
/// bold text, hit Bold again, get plain text back). Doesn't try to handle
/// combined ***bold italic*** toggling — a reasonable limit given most
/// selections apply one format at a time.
String toggleBold(String text) => _toggleWrap(text, '**');

String toggleItalic(String text) {
  if (text.length >= 2 &&
      text.startsWith('*') &&
      text.endsWith('*') &&
      !text.startsWith('**')) {
    return text.substring(1, text.length - 1);
  }
  return '*$text*';
}

String _toggleWrap(String text, String marker) {
  if (text.length >= marker.length * 2 &&
      text.startsWith(marker) &&
      text.endsWith(marker)) {
    return text.substring(marker.length, text.length - marker.length);
  }
  return '$marker$text$marker';
}

/// Applies (or, if [level] is null, removes) a Markdown heading prefix
/// ("# ".."###### ") to every line touched by [selection] in [text]. Any
/// existing heading prefix on a line is replaced rather than stacked.
TextEditingValue applyHeading(
    String text, TextSelection selection, int? level) {
  return _mapLines(text, selection, (line) {
    final stripped = line.replaceFirst(RegExp(r'^#{1,6} '), '');
    return level == null ? stripped : '${'#' * level} $stripped';
  });
}

/// Toggles a "- " bullet prefix on every line touched by [selection]. If
/// every touched line already has the prefix, it's removed from all of
/// them; otherwise it's added to whichever lines are missing it.
TextEditingValue toggleBulletList(String text, TextSelection selection) {
  final allBulleted = _linesIn(text, selection).every((l) => l.startsWith('- '));
  return _mapLines(
      text,
      selection,
      (line) => allBulleted
          ? line.substring(2)
          : (line.startsWith('- ') ? line : '- $line'));
}

List<String> _linesIn(String text, TextSelection selection) {
  final bounds = _lineBounds(text, selection);
  return text.substring(bounds.$1, bounds.$2).split('\n');
}

(int, int) _lineBounds(String text, TextSelection selection) {
  var start = selection.start;
  while (start > 0 && text[start - 1] != '\n') {
    start--;
  }
  var end = selection.end;
  while (end < text.length && text[end] != '\n') {
    end++;
  }
  return (start, end);
}

TextEditingValue _mapLines(
    String text, TextSelection selection, String Function(String) fn) {
  final bounds = _lineBounds(text, selection);
  final (start, end) = bounds;
  final newBlock = text.substring(start, end).split('\n').map(fn).join('\n');
  return TextEditingValue(
    text: text.replaceRange(start, end, newBlock),
    selection: TextSelection(baseOffset: start, extentOffset: start + newBlock.length),
  );
}
