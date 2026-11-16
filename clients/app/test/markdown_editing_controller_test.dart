import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/markdown_editing_controller.dart';

void main() {
  testWidgets('spans always concatenate to the exact buffer text', (t) async {
    const samples = [
      '# H1\n## H2 with **bold**',
      '> quote *it*\n- [ ] todo\n- [x] done\n1. one\n---',
      '```dart\nvar a = **not bold**;\n```\nafter',
      '| a | b |\n|---|---|\n| 1 | 2 |',
      'a `code` ~~gone~~ ==mark==^orange [l](http://x) ![i](y.png) **b *i* b**',
      '**unclosed and * lone _ markers ``',
    ];
    late BuildContext ctx;
    await t.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    for (final s in samples) {
      final text = s;
      final c = MarkdownEditingController(text: text);
      final span =
          c.buildTextSpan(context: ctx, withComposing: false, style: const TextStyle());
      expect(span.toPlainText(), text, reason: s);
    }
  });

  testWidgets('snake_case and escapes are not styled as emphasis', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    }));
    bool anyItalic(String text) {
      final span = MarkdownEditingController(text: text).buildTextSpan(
          context: ctx, withComposing: false, style: const TextStyle());
      var found = false;
      span.visitChildren((s) {
        if (s is TextSpan && s.style?.fontStyle == FontStyle.italic) found = true;
        return true;
      });
      return found;
    }

    expect(anyItalic('use snake_case_name here'), isFalse);
    expect(anyItalic(r'\*not italic\*'), isFalse);
    expect(anyItalic('_real_ emphasis'), isTrue);
  });

  group('MarkdownListContinuation', () {
    String enter(String before) {
      final f = MarkdownListContinuation();
      final old = TextEditingValue(
          text: before, selection: TextSelection.collapsed(offset: before.length));
      final typed = TextEditingValue(
          text: '$before\n', selection: TextSelection.collapsed(offset: before.length + 1));
      return f.formatEditUpdate(old, typed).text;
    }

    test('continues bullets, numbers and tasks', () {
      expect(enter('- a'), '- a\n- ');
      expect(enter('2. a'), '2. a\n3. ');
      expect(enter('- [x] done'), '- [x] done\n- [ ] ');
    });

    test('empty item ends the list; plain lines untouched', () {
      expect(enter('- a\n- '), '- a\n');
      expect(enter('hello'), 'hello\n');
    });
  });

  group('checklists', () {
    String toggle(String text, [int? from, int? to]) {
      final c = MarkdownEditingController(text: text)
        ..selection = TextSelection(
            baseOffset: from ?? text.length, extentOffset: to ?? text.length);
      c.toggleChecklist();
      return c.text;
    }

    test('toggleChecklist adds and removes task markers', () {
      expect(toggle(''), '- [ ] ');
      expect(toggle('a\nmilk'), 'a\n- [ ] milk');
      expect(toggle('  - milk'), '  - [ ] milk');
      expect(toggle('- [x] milk'), 'milk');
      // Mixed selection: everything becomes a task, blank lines untouched.
      expect(toggle('- [ ] a\n\nb', 0), '- [ ] a\n\n- [ ] b');
      expect(toggle('- [ ] a\n- [x] b', 0), 'a\nb');
    });

    test('taskBoxOffsets finds tasks outside code fences', () {
      const text = '- [ ] a\n```\n- [ ] code\n```\n> 1. [x] b\n- [] no';
      final at = taskBoxOffsets(text);
      expect(at.map((i) => text[i]), [' ', 'x']);
      expect(at.first, 3);
    });
  });
}
