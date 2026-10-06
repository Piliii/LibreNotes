import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/line_diff.dart';

void main() {
  test('diffLines marks only-local as removed, only-server as added', () {
    final d = diffLines('a\nb\nc', 'a\nB\nc');
    expect(d.map((l) => l.op), [
      DiffOp.same, DiffOp.removed, DiffOp.added, DiffOp.same,
    ]);
    expect(d[1].text, 'b');
    expect(d[2].text, 'B');
  });

  test('identical and empty inputs', () {
    expect(diffLines('x', 'x').single.op, DiffOp.same);
    expect(diffLines('', '').isEmpty, isTrue);
    expect(diffLines('', 'n').single.op, DiffOp.added);
  });

  test('mergeWithMarkers keeps shared lines, wraps hunks, detects markers', () {
    final m = mergeWithMarkers('a\nb\nc', 'a\nB\nc');
    expect(m, 'a\n<<<<<<< this device\nb\n=======\nB\n>>>>>>> server\nc');
    expect(hasConflictMarkers(m), isTrue);
    expect(hasConflictMarkers('a\nB\nc'), isFalse);
    expect(mergeWithMarkers('same', 'same'), 'same');
  });
}
