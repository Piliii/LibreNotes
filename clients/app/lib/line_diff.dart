/// Line-level diff (LCS) used by the conflict screen. Notes are small, so the
/// O(n*m) table is fine; a ponytail: swap for Myers if notes ever reach
/// tens of thousands of lines.
enum DiffOp { same, removed, added }

class DiffLine {
  const DiffLine(this.op, this.text);
  final DiffOp op;
  final String text;
}

/// Diff of [a] (e.g. this device) to [b] (e.g. server): `removed` lines are
/// only in [a], `added` lines only in [b].
List<DiffLine> diffLines(String a, String b) {
  final x = a.isEmpty ? <String>[] : a.split('\n');
  final y = b.isEmpty ? <String>[] : b.split('\n');
  final n = x.length, m = y.length;
  final t = List.generate(n + 1, (_) => List.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      t[i][j] = x[i] == y[j]
          ? t[i + 1][j + 1] + 1
          : (t[i + 1][j] >= t[i][j + 1] ? t[i + 1][j] : t[i][j + 1]);
    }
  }
  final out = <DiffLine>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (x[i] == y[j]) {
      out.add(DiffLine(DiffOp.same, x[i]));
      i++;
      j++;
    } else if (t[i + 1][j] >= t[i][j + 1]) {
      out.add(DiffLine(DiffOp.removed, x[i++]));
    } else {
      out.add(DiffLine(DiffOp.added, y[j++]));
    }
  }
  while (i < n) {
    out.add(DiffLine(DiffOp.removed, x[i++]));
  }
  while (j < m) {
    out.add(DiffLine(DiffOp.added, y[j++]));
  }
  return out;
}

/// Starting text for the manual-merge editor: shared lines once, each
/// differing hunk wrapped in git-style markers for the user to resolve.
String mergeWithMarkers(String local, String remote) {
  final out = <String>[];
  final mine = <String>[], theirs = <String>[];
  void flush() {
    if (mine.isEmpty && theirs.isEmpty) return;
    out
      ..add('<<<<<<< this device')
      ..addAll(mine)
      ..add('=======')
      ..addAll(theirs)
      ..add('>>>>>>> server');
    mine.clear();
    theirs.clear();
  }

  for (final d in diffLines(local, remote)) {
    switch (d.op) {
      case DiffOp.same:
        flush();
        out.add(d.text);
      case DiffOp.removed:
        mine.add(d.text);
      case DiffOp.added:
        theirs.add(d.text);
    }
  }
  flush();
  return out.join('\n');
}

/// True while [text] still contains an unresolved marker line.
bool hasConflictMarkers(String text) => text
    .split('\n')
    .any((l) => l.startsWith('<<<<<<< ') || l == '=======' || l.startsWith('>>>>>>> '));
