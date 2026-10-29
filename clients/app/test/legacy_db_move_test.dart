import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/data/database.dart';

void main() {
  late Directory root, oldDir, newDir;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('librenotes_move');
    oldDir = await Directory('${root.path}/old').create();
    newDir = Directory('${root.path}/new/nested'); // doesn't exist yet
    addTearDown(() => root.delete(recursive: true));
  });

  String read(Directory d, String f) => File('${d.path}/$f').readAsStringSync();
  bool has(Directory d, String f) => File('${d.path}/$f').existsSync();

  test('moves db and sidecars, creating the new dir', () async {
    File('${oldDir.path}/notally.sqlite').writeAsStringSync('db');
    File('${oldDir.path}/notally.sqlite-wal').writeAsStringSync('wal');
    await moveLegacyDb(oldDir.path, newDir.path);
    expect(read(newDir, 'notally.sqlite'), 'db');
    expect(read(newDir, 'notally.sqlite-wal'), 'wal');
    expect(has(oldDir, 'notally.sqlite'), isFalse);
    expect(has(oldDir, 'notally.sqlite-wal'), isFalse);
  });

  test('never overwrites an existing new db', () async {
    newDir.createSync(recursive: true);
    File('${oldDir.path}/notally.sqlite').writeAsStringSync('old');
    File('${newDir.path}/notally.sqlite').writeAsStringSync('new');
    await moveLegacyDb(oldDir.path, newDir.path);
    expect(read(newDir, 'notally.sqlite'), 'new');
    expect(read(oldDir, 'notally.sqlite'), 'old');
  });

  test('fresh install is a no-op', () async {
    await moveLegacyDb(oldDir.path, newDir.path);
    expect(has(newDir, 'notally.sqlite'), isFalse);
  });
}
