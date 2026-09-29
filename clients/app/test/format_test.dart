import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/format.dart';

void main() {
  group('relativeTime', () {
    int ago(Duration d) => DateTime.now().subtract(d).millisecondsSinceEpoch;

    test('very recent reads "just now"', () {
      expect(relativeTime(ago(const Duration(seconds: 10))), 'just now');
    });

    test('minutes within the hour', () {
      expect(relativeTime(ago(const Duration(minutes: 5))), '5m ago');
    });

    test('hours within the day', () {
      expect(relativeTime(ago(const Duration(hours: 3))), '3h ago');
    });

    test('days within the week', () {
      expect(relativeTime(ago(const Duration(days: 2))), '2d ago');
    });

    test('older than a week falls back to an absolute date', () {
      final then = DateTime(2024, 1, 5);
      expect(relativeTime(then.millisecondsSinceEpoch), 'Jan 5 2024');
    });
  });

  group('previewText', () {
    test('flattens newlines to a single line', () {
      expect(previewText('line one\nline two'), 'line one line two');
    });

    test('strips heading markers', () {
      expect(previewText('# Title\nbody'), 'Title body');
    });

    test('strips emphasis, code, and quote markers', () {
      expect(previewText('**bold** _em_ `code` > quote ~strike~'),
          'bold em code  quote strike');
    });

    test('turns list bullets into •', () {
      expect(previewText('- first\n- second'), '• first • second');
    });

    test('trims surrounding whitespace', () {
      expect(previewText('   padded   '), 'padded');
    });

    test('empty body stays empty', () {
      expect(previewText(''), '');
      expect(previewText('   \n  '), '');
    });
  });

  group('trashRemainingLabel', () {
    const retention = Duration(days: 30);
    final now = DateTime(2026, 9, 29, 12);
    int deleted(Duration ago) => now.subtract(ago).millisecondsSinceEpoch;
    String label(Duration ago) =>
        trashRemainingLabel(deleted(ago), retention: retention, now: now);

    test('just trashed has the full window left', () {
      expect(label(Duration.zero), '30 days left');
    });

    test('partial days round up', () {
      expect(label(const Duration(days: 10, hours: 2)), '20 days left');
    });

    test('under a day left reads as 1 day', () {
      expect(label(const Duration(days: 29, hours: 6)), '1 day left');
    });

    test('at or past the deadline reads "Deleting soon"', () {
      expect(label(const Duration(days: 30)), 'Deleting soon');
      expect(label(const Duration(days: 45)), 'Deleting soon');
    });
  });
}
