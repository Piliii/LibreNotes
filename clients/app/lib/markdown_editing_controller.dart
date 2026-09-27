import 'package:flutter/material.dart';

import 'markdown_highlight.dart';

/// A [TextEditingController] that renders its own text styled as it would
/// look formatted — bold actually bold, headings actually big, highlights
/// actually colored — instead of raw Markdown syntax, while the underlying
/// [text] stays plain Markdown the whole time (unchanged, fully editable,
/// nothing removed from the buffer). It's directly editable at all times —
/// there's no separate raw/preview mode to switch out of first.
///
/// Syntax markers (`**`, `#`, `==...==^color`, `- `) are real characters, not
/// stripped — removing them from the buffer while keeping them out of the
/// visible layout would desync cursor/tap hit-testing from the actual text.
/// Instead, on any line the cursor *isn't* currently on (or when the field
/// isn't focused at all), markers are shrunk to a near-invisible sliver so
/// the line reads as clean formatted text with no visible syntax; on the
/// line the cursor *is* on, they're shown small-and-faded instead, so you
/// can actually see and edit the syntax you're in the middle of typing.
/// (Same idea as Obsidian/Typora's "live preview" editing mode.)
///
/// This only covers what [markdown_format.dart] can apply from the
/// text-selection toolbar (heading, bold, italic, bullet list, highlight) —
/// richer Markdown (links, code blocks, blockquotes, tables, images) still
/// renders as literal text here; the full-fidelity "Preview" toggle (the
/// complete flutter_markdown renderer) still exists for that.
class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  static final _headingRe = RegExp(r'^#{1,6} ');
  static final _bulletRe = RegExp(r'^- ');
  static final _highlightRe = RegExp(r'^==(.+?)==\^(\w+)');
  static final _boldRe = RegExp(r'^\*\*(.+?)\*\*');
  static final _italicRe = RegExp(r'^\*(?!\*)(.+?)\*');

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
    var offset = 0;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final lineEnd = offset + line.length;
      // Only reveal the active line's markers when the field is actually
      // focused (`withComposing` doubles as that signal) — an unfocused
      // note always reads as fully clean, regardless of stale selection.
      final revealMarkers = withComposing && _cursorTouches(offset, lineEnd);
      spans.addAll(_lineSpans(line, base, revealMarkers));
      offset = lineEnd + 1; // +1 for the '\n' joining this line to the next.
      if (i != lines.length - 1) spans.add(TextSpan(text: '\n', style: base));
    }
    return TextSpan(style: base, children: spans);
  }

  bool _cursorTouches(int lineStart, int lineEnd) {
    if (!selection.isValid) return false;
    return selection.start <= lineEnd && selection.end >= lineStart;
  }

  /// Small and faded — used for markers on the line the cursor is on, so
  /// they're visible enough to edit precisely.
  TextStyle _revealed(TextStyle base) => base.copyWith(
        color: (base.color ?? Colors.white).withValues(alpha: 0.35),
        fontSize: (base.fontSize ?? 16) * 0.85,
      );

  /// Shrunk to a sliver and transparent — used everywhere else, so the line
  /// reads as clean formatted text with no visible syntax. The marker stays
  /// a real character (for correct cursor/tap positioning); it just doesn't
  /// occupy meaningful visual space.
  TextStyle _hidden(TextStyle base) => base.copyWith(
        color: Colors.transparent,
        fontSize: 1,
        letterSpacing: -1,
      );

  List<InlineSpan> _lineSpans(String line, TextStyle base, bool reveal) {
    final markerStyle = reveal ? _revealed(base) : _hidden(base);
    final heading = _headingRe.matchAsPrefix(line);
    if (heading != null) {
      final level = heading.group(0)!.trim().length;
      final headingStyle = base.copyWith(
        fontSize: _headingSizes[level - 1],
        fontWeight: FontWeight.w700,
      );
      return [
        TextSpan(text: heading.group(0), style: markerStyle),
        ..._inlineSpans(line.substring(heading.end), headingStyle, reveal),
      ];
    }
    final bullet = _bulletRe.matchAsPrefix(line);
    if (bullet != null) {
      return [
        TextSpan(text: '- ', style: markerStyle),
        ..._inlineSpans(line.substring(2), base, reveal),
      ];
    }
    return _inlineSpans(line, base, reveal);
  }

  List<InlineSpan> _inlineSpans(String content, TextStyle base, bool reveal) {
    final markerStyle = reveal ? _revealed(base) : _hidden(base);
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();
    void flush() {
      if (buffer.isEmpty) return;
      spans.add(TextSpan(text: buffer.toString(), style: base));
      buffer.clear();
    }

    var i = 0;
    while (i < content.length) {
      final rest = content.substring(i);
      final highlight = _highlightRe.matchAsPrefix(rest);
      final bold = _boldRe.matchAsPrefix(rest);
      final italic = _italicRe.matchAsPrefix(rest);

      if (highlight != null) {
        flush();
        final bg = kHighlightColors[highlight.group(2)] ??
            kHighlightColors.values.first;
        spans.add(TextSpan(text: '==', style: markerStyle));
        spans.add(TextSpan(
          text: highlight.group(1),
          style: base.copyWith(backgroundColor: bg, color: Colors.black87),
        ));
        spans.add(TextSpan(text: '==^${highlight.group(2)}', style: markerStyle));
        i += highlight.group(0)!.length;
      } else if (bold != null) {
        flush();
        spans.add(TextSpan(text: '**', style: markerStyle));
        spans.add(TextSpan(
            text: bold.group(1),
            style: base.copyWith(fontWeight: FontWeight.bold)));
        spans.add(TextSpan(text: '**', style: markerStyle));
        i += bold.group(0)!.length;
      } else if (italic != null) {
        flush();
        spans.add(TextSpan(text: '*', style: markerStyle));
        spans.add(TextSpan(
            text: italic.group(1),
            style: base.copyWith(fontStyle: FontStyle.italic)));
        spans.add(TextSpan(text: '*', style: markerStyle));
        i += italic.group(0)!.length;
      } else {
        buffer.write(content[i]);
        i++;
      }
    }
    flush();
    return spans;
  }
}
