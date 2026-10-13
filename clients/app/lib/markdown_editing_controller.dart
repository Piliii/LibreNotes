import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
        backgroundColor: Colors.white.withValues(alpha: 0.06),
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
