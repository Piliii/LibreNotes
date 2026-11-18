import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'theme.dart';

/// A [TextEditingController] that styles its own Markdown as you type:
/// headings big, **bold** bold, `code` monospace, links underlined, and so on.
/// The buffer is never touched and the emitted spans always concatenate to
/// exactly [text], so cursor, selection and tap hit-testing can't desync.
///
/// Syntax markers stay visible but faded (rather than hidden) for the same
/// reason. Covers: headings, blockquotes, bullet/numbered/task lists, rules,
/// fenced code blocks, tables (monospace), bold, italic, ~~strike~~,
/// ==highlight==, `inline code`, links and images.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  /// Builds the widget shown in place of an embedded image's link
  /// (`![](attachment:<id>)`). When set, the link text is never visible:
  /// it renders as this widget plus zero-size text (so the spans still
  /// concatenate to exactly [text]), the caret can't stop inside it, and one
  /// Backspace/Delete removes the whole link. See [_guardEmbeds].
  Widget Function(String id)? imageEmbed;

  @override
  set value(TextEditingValue newValue) {
    super.value =
        imageEmbed == null ? newValue : _guardEmbeds(super.value, newValue);
  }

  /// Keeps embedded images atomic: a deletion that cuts into a link removes
  /// the whole link, and a caret or selection end that lands inside one is
  /// moved to its edge (in the direction it was travelling).
  static TextEditingValue _guardEmbeds(
      TextEditingValue old, TextEditingValue now) {
    if (old.text != now.text) {
      final a = old.text, b = now.text;
      var p = 0;
      while (p < a.length && p < b.length && a[p] == b[p]) {
        p++;
      }
      var s = 0;
      while (s < a.length - p && s < b.length - p &&
          a[a.length - 1 - s] == b[b.length - 1 - s]) {
        s++;
      }
      var delStart = p, delEnd = a.length - s;
      if (delEnd > delStart) {
        for (final m in attachmentLinkPattern.allMatches(a)) {
          final cuts = m.start < delEnd && m.end > delStart;
          final whole = m.start >= delStart && m.end <= delEnd;
          if (cuts && !whole) {
            if (m.start < delStart) delStart = m.start;
            if (m.end > delEnd) delEnd = m.end;
          }
        }
        if (delStart != p || delEnd != a.length - s) {
          final inserted = b.substring(p, b.length - s);
          return TextEditingValue(
            text: a.replaceRange(delStart, delEnd, inserted),
            selection: TextSelection.collapsed(
                offset: delStart + inserted.length),
          );
        }
      }
    }
    final sel = now.selection;
    if (!sel.isValid) return now;
    final runs = attachmentLinkPattern.allMatches(now.text).toList();
    if (runs.isEmpty) return now;
    int snap(int off, int from) {
      for (final m in runs) {
        if (off <= m.start || off >= m.end) continue;
        if (from <= m.start) return m.end;
        if (from >= m.end) return m.start;
        return off - m.start < m.end - off ? m.start : m.end;
      }
      return off;
    }

    // The extent snaps the way it was travelling; with no known previous
    // position, a collapsed caret goes to the nearer edge and a selection
    // end grows outward.
    final moved = old.selection.isValid &&
        old.selection.extentOffset != sel.extentOffset;
    final extent = snap(
      sel.extentOffset,
      moved
          ? old.selection.extentOffset
          : sel.isCollapsed
              ? sel.extentOffset
              : (sel.extentOffset > sel.baseOffset ? -1 : now.text.length + 1),
    );
    // A selection's anchor snaps outward, so the image is fully included.
    final base = sel.isCollapsed
        ? extent
        : snap(sel.baseOffset,
            sel.baseOffset < sel.extentOffset ? now.text.length + 1 : -1);
    if (base == sel.baseOffset && extent == sel.extentOffset) return now;
    return now.copyWith(
      selection: sel.copyWith(baseOffset: base, extentOffset: extent),
      composing: TextRange.empty,
    );
  }

  static final _heading = RegExp(r'^(#{1,6})([ \t]+)');
  static final _quote = RegExp(r'^(\s*>[ \t]?)+');
  static final _task = RegExp(r'^(\s*(?:[-*+]|\d+[.)])[ \t]+)(\[[ xX]\])([ \t]+)');
  static final _list = RegExp(r'^\s*(?:[-*+]|\d+[.)])[ \t]+');
  static final _rule = RegExp(r'^\s{0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$');
  static final _fence = RegExp(r'^\s*(```+|~~~+)');
  static final _table = RegExp(r'^\s*\|.*\|?\s*$');

  // Inline tokens, tried in order at each position. Group 1 = opening marker,
  // group 2 = content, group 3 = closing marker (links/images are handled
  // separately because their tail is longer).
  static final _inline = <(RegExp, _Kind)>[
    (RegExp(r'^(`+)(.+?)\1'), _Kind.code),
    (RegExp(r'^(!?\[)([^\]\n]*)(\]\([^)\n]*\))'), _Kind.link),
    (RegExp(r'^(\*\*|__)(?=\S)(.+?)(?<=\S)\1'), _Kind.bold),
    (RegExp(r'^(~~)(?=\S)(.+?)(?<=\S)~~'), _Kind.strike),
    (RegExp(r'^(==)(?=\S)(.+?)(?<=\S)==(?:\^\w+)?'), _Kind.mark),
    (RegExp(r'^(\*)(?=[^\s*])(.+?)(?<=[^\s*])\*'), _Kind.italic),
    (RegExp(r'^(_)(?=[^\s_])(.+?)(?<=[^\s_])_(?!\w)'), _Kind.italic),
  ];

  /// Turns the selected lines (or the cursor's line) into `- [ ]` tasks, or
  /// back to plain text when every one of them already is a task.
  void toggleChecklist() {
    final sel = selection.isValid
        ? selection
        : TextSelection.collapsed(offset: text.length);
    final start = sel.start == 0 ? 0 : text.lastIndexOf('\n', sel.start - 1) + 1;
    var end = text.indexOf('\n', sel.end);
    if (end < 0) end = text.length;
    final lines = text.substring(start, end).split('\n');
    // Blank lines inside a multi-line selection are left alone.
    bool skip(String l) => lines.length > 1 && l.trim().isEmpty;
    final allTasks = lines.every((l) => skip(l) || _task.hasMatch(l));
    final out = lines.map((l) {
      if (skip(l)) return l;
      final indent = RegExp(r'^\s*').stringMatch(l)!;
      final task = _task.firstMatch(l);
      if (allTasks) return indent + l.substring(task!.end);
      if (task != null) return l;
      final list = _list.firstMatch(l);
      return list != null
          ? '${list.group(0)}[ ] ${l.substring(list.end)}'
          : '$indent- [ ] ${l.substring(indent.length)}';
    }).join('\n');
    value = TextEditingValue(
      text: text.replaceRange(start, end, out),
      selection: TextSelection.collapsed(offset: start + out.length),
    );
  }

  static const _escapable = r'\`*_{}[]()#+-.!~=|>';
  static const _headingSizes = [28.0, 24.0, 20.0, 18.0, 16.0, 16.0];

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final lines = text.split('\n');
    final spans = <InlineSpan>[];
    String? fence; // the marker that opened the current code block
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final marker = _fence.firstMatch(line)?.group(1);
      if (marker != null && (fence == null || marker[0] == fence[0])) {
        fence = fence == null ? marker : null;
        spans.add(TextSpan(text: line, style: _mono(base, faded: true)));
      } else if (fence != null) {
        spans.add(TextSpan(text: line, style: _mono(base)));
      } else {
        spans.addAll(_lineSpans(line, base));
      }
      if (i != lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
    }
    return TextSpan(style: base, children: spans);
  }

  TextStyle _faded(TextStyle base) =>
      base.copyWith(color: (base.color ?? Colors.white).withValues(alpha: 0.4));

  TextStyle _mono(TextStyle base, {bool faded = false}) => base.copyWith(
        fontFamily: 'monospace',
        fontSize: (base.fontSize ?? 16) * 0.92,
        backgroundColor: (base.color ?? Colors.white).withValues(alpha: 0.08),
        color: faded ? _faded(base).color : base.color,
      );

  List<InlineSpan> _lineSpans(String line, TextStyle base) {
    if (_rule.hasMatch(line)) {
      return [TextSpan(text: line, style: _faded(base))];
    }
    final heading = _heading.firstMatch(line);
    if (heading != null) {
      final h = base.copyWith(
        fontSize: _headingSizes[heading.group(1)!.length - 1],
        fontWeight: FontWeight.w700,
      );
      return [
        TextSpan(text: heading.group(0), style: _faded(h)),
        ..._inlineSpans(line.substring(heading.end), h),
      ];
    }
    final quote = _quote.firstMatch(line);
    if (quote != null) {
      final q = base.copyWith(
        fontStyle: FontStyle.italic,
        color: (base.color ?? Colors.white).withValues(alpha: 0.75),
      );
      return [
        TextSpan(
            text: quote.group(0),
            style: _faded(base).copyWith(color: NotallyColors.accent)),
        ..._inlineSpans(line.substring(quote.end), q),
      ];
    }
    final task = _task.firstMatch(line);
    if (task != null) {
      final done = task.group(2)!.toLowerCase() == '[x]';
      final rest = done
          ? base.copyWith(
              decoration: TextDecoration.lineThrough,
              color: _faded(base).color,
            )
          : base;
      return [
        TextSpan(text: task.group(1), style: _faded(base)),
        TextSpan(
            text: task.group(2),
            style: base.copyWith(
                color: done ? NotallyColors.accent : _faded(base).color,
                fontWeight: FontWeight.w700)),
        TextSpan(text: task.group(3), style: _faded(base)),
        ..._inlineSpans(line.substring(task.end), rest),
      ];
    }
    final list = _list.firstMatch(line);
    if (list != null) {
      return [
        TextSpan(
            text: list.group(0),
            style: base.copyWith(color: NotallyColors.accent)),
        ..._inlineSpans(line.substring(list.end), base),
      ];
    }
    if (_table.hasMatch(line)) {
      // Pipes/dashes faded, cell text monospace so columns line up.
      return [TextSpan(text: line, style: _mono(base))];
    }
    return _inlineSpans(line, base);
  }

  List<InlineSpan> _inlineSpans(String content, TextStyle base) {
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString(), style: base));
      buffer.clear();
    }

    var i = 0;
    outer:
    while (i < content.length) {
      // Only try tokens where one could start (cheap pre-filter).
      final c = content[i];
      if (c == r'\' && i + 1 < content.length && _escapable.contains(content[i + 1])) {
        buffer.write(content.substring(i, i + 2)); // escaped: literal, unstyled
        i += 2;
        continue;
      }
      // `_` inside a word (snake_case) isn't emphasis.
      final intraword = c == '_' && i > 0 && RegExp(r'\w').hasMatch(content[i - 1]);
      if (c == '!' && imageEmbed != null) {
        final m = attachmentLinkPattern.matchAsPrefix(content, i);
        if (m != null) {
          flush();
          spans.add(WidgetSpan(
            alignment: PlaceholderAlignment.bottom,
            child: imageEmbed!(m.group(1)!),
          ));
          spans.add(TextSpan(
            text: m.group(0)!.substring(1),
            style: const TextStyle(
              fontSize: 0.01,
              height: 1,
              letterSpacing: 0,
              color: Colors.transparent,
              decoration: TextDecoration.none,
            ),
          ));
          i = m.end;
          continue;
        }
      }
      if (!intraword && '`![*_~='.contains(c)) {
        final rest = content.substring(i);
        for (final (re, kind) in _inline) {
          final m = re.matchAsPrefix(rest);
          if (m == null) continue;
          flush();
          spans.addAll(_token(m, kind, base));
          i += m.group(0)!.length;
          continue outer;
        }
      }
      buffer.write(c);
      i++;
    }
    flush();
    return spans;
  }

  List<InlineSpan> _token(Match m, _Kind kind, TextStyle base) {
    final open = m.group(1)!;
    final inner = m.group(2)!;
    final marker = _faded(base);
    // Whatever follows the content: closing marker, link tail, ==^color, etc.
    final tail = m.group(0)!.substring(open.length + inner.length);
    final TextStyle body;
    switch (kind) {
      case _Kind.code:
        body = _mono(base);
      case _Kind.bold:
        body = base.copyWith(fontWeight: FontWeight.w700);
      case _Kind.italic:
        body = base.copyWith(fontStyle: FontStyle.italic);
      case _Kind.strike:
        body = base.copyWith(decoration: TextDecoration.lineThrough);
      case _Kind.mark:
        body = base.copyWith(
          backgroundColor: NotallyColors.accent.withValues(alpha: 0.35),
        );
      case _Kind.link:
        body = base.copyWith(
          color: NotallyColors.accent,
          decoration: open.startsWith('!')
              ? TextDecoration.none
              : TextDecoration.underline,
          decorationColor: NotallyColors.accent,
        );
    }
    return [
      TextSpan(text: open, style: marker),
      // Nested emphasis inside bold/italic/strike/link text.
      if (kind == _Kind.code)
        TextSpan(text: inner, style: body)
      else
        ..._inlineSpans(inner, body),
      TextSpan(text: tail, style: marker),
    ];
  }
}

enum _Kind { code, link, bold, strike, mark, italic }

/// Offset of the state character (the space or `x` inside the brackets) of
/// every task item in [text], in document order. Fenced code is skipped and
/// quoted tasks (`> - [ ] x`) count, to match what the Preview renders.
List<int> taskBoxOffsets(String text) {
  final task =
      RegExp(r'^(?:\s*>[ \t]?)*\s*(?:[-*+]|\d+[.)])[ \t]+\[([ xX])\][ \t]');
  final offsets = <int>[];
  String? fence;
  var pos = 0;
  for (final line in text.split('\n')) {
    final marker = MarkdownEditingController._fence.firstMatch(line)?.group(1);
    if (marker != null && (fence == null || marker[0] == fence[0])) {
      fence = fence == null ? marker : null;
    } else if (fence == null) {
      final m = task.firstMatch(line);
      if (m != null) offsets.add(pos + m.end - 3);
    }
    pos += line.length + 1;
  }
  return offsets;
}

/// Enter on a list line continues the list (`- `, `1. ` → next number,
/// `- [ ] ` stays an unchecked task); Enter on an empty item ends it.
class MarkdownListContinuation extends TextInputFormatter {
  static final _item =
      RegExp(r'^(\s*)((?:[-*+]|(\d+)([.)]))[ \t]+)(\[[ xX]\][ \t]+)?');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue now) {
    final pos = now.selection.baseOffset;
    if (!now.selection.isCollapsed ||
        now.text.length != old.text.length + 1 ||
        pos < 1 ||
        now.text[pos - 1] != '\n') {
      return now;
    }
    final lineStart = now.text.lastIndexOf('\n', pos - 2) + 1;
    final line = now.text.substring(lineStart, pos - 1);
    final m = _item.firstMatch(line);
    if (m == null) return now;
    if (line.substring(m.end).trim().isEmpty) {
      // Empty item: drop the marker and the newline just typed.
      final text = now.text.replaceRange(lineStart, pos, '');
      return TextEditingValue(
          text: text, selection: TextSelection.collapsed(offset: lineStart));
    }
    final number = m.group(3);
    final bullet = number == null
        ? m.group(2)!
        : '${int.parse(number) + 1}${m.group(4)}${m.group(2)!.substring(number.length + 1)}';
    final prefix = '${m.group(1)}$bullet${m.group(5) == null ? '' : '[ ] '}';
    return TextEditingValue(
      text: now.text.replaceRange(pos, pos, prefix),
      selection: TextSelection.collapsed(offset: pos + prefix.length),
    );
  }
}
