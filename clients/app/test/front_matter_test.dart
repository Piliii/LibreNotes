import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/ui/import_export_page.dart';

void main() {
  test('front matter round-trips folder and tags', () {
    final raw = '${frontMatter('Work stuff', ['a', 'b c'])}# Title\n\nbody';
    final p = parseFrontMatter(raw);
    expect(p.folder, 'Work stuff');
    expect(p.tags, ['a', 'b c']);
    expect(p.rest, '# Title\n\nbody');
  });

  test('plain markdown passes through untouched', () {
    expect(frontMatter('', const []), '');
    final p = parseFrontMatter('# Hi\n---\nnot front matter');
    expect(p.folder, '');
    expect(p.tags, isEmpty);
    expect(p.rest, '# Hi\n---\nnot front matter');
  });
}
