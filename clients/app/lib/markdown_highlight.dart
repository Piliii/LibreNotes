import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;

/// Preset text-highlight colors. Pastel on purpose — like a physical
/// highlighter over paper, they read as highlighted regardless of the app's
/// dark theme, so the mark stays legible whichever color is picked.
const kHighlightColors = <String, Color>{
  'yellow': Color(0xFFFFE066),
  'green': Color(0xFFB2F2BB),
  'blue': Color(0xFFA5D8FF),
  'pink': Color(0xFFFFC9DE),
  'orange': Color(0xFFFFD8A8),
};

/// `==highlighted text==^colorkey` — an inline highlight span in the raw
/// markdown body. `colorkey` (a [kHighlightColors] key) is always present so
/// one delimiter pair can carry any preset color without a per-color syntax.
const _highlightSource = r'==(.+?)==\^(\w+)';

/// Anchored variant used to check whether a whole selected substring is
/// *exactly* one highlight span (start to end, nothing extra either side) —
/// that's how the text-selection toolbar decides whether to offer "Remove
/// highlight" instead of "Highlight".
final _exactHighlightPattern = RegExp('^$_highlightSource\$');

String wrapHighlight(String text, String colorKey) => '==$text==^$colorKey';

/// If [selectedText] is exactly one highlight span, returns its color key and
/// inner (un-highlighted) text; otherwise null.
({String colorKey, String inner})? matchExactHighlight(String selectedText) {
  final m = _exactHighlightPattern.firstMatch(selectedText);
  if (m == null) return null;
  return (colorKey: m.group(2)!, inner: m.group(1)!);
}

/// Parses [_highlightSource] into a `mark` element carrying the color key as
/// an attribute, so [HighlightBuilder] can render each span in its own color.
class HighlightSyntax extends md.InlineSyntax {
  HighlightSyntax() : super(_highlightSource);

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final element = md.Element.text('mark', match[1]!);
    element.attributes['color'] = match[2]!;
    parser.addNode(element);
    return true;
  }
}

/// Renders a `mark` element (see [HighlightSyntax]) as a rounded, colored
/// background behind its text — inline, so it sits within the surrounding
/// paragraph like a real highlighter stroke.
class HighlightBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final bg = kHighlightColors[element.attributes['color']] ??
        kHighlightColors.values.first;
    final base = preferredStyle ?? parentStyle ?? const TextStyle();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(element.textContent, style: base.copyWith(color: Colors.black87)),
    );
  }
}
