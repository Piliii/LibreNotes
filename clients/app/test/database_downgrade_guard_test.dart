import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/data/database.dart';

// A stale app binary opening a database that a newer install already
// migrated further must refuse to touch it, rather than let drift's
// migrator run a no-op upgrade and silently stamp its own (lower) version
// number over the real one — see the 2026-09-27 db repair notes in
// database.dart. This reproduces that scenario directly against a real
// sqlite file, not just the schema-shape assertions covered elsewhere.
void main() {
  test('opening a database with a newer on-disk schema throws and leaves '
      'user_version untouched', () async {
    final dir = await Directory.systemTemp.createTemp('librenotes_downgrade');
    final file = File('${dir.path}/notally.sqlite');
    addTearDown(() => dir.delete(recursive: true));

    // Seed a file via the sqlite3 CLI that looks like it was already
    // migrated by some future schema version well beyond anything this
    // binary knows about.
    final seed = await Process.run('sqlite3', [file.path, '''
      CREATE TABLE notes (
        id TEXT NOT NULL PRIMARY KEY,
        pinned INTEGER NOT NULL DEFAULT 0,
        color TEXT NOT NULL DEFAULT '#2a2a2a',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        rev INTEGER NOT NULL DEFAULT 0,
        seq INTEGER NOT NULL DEFAULT 0,
        deleted INTEGER NOT NULL DEFAULT 0,
        purged INTEGER NOT NULL DEFAULT 0,
        dirty INTEGER NOT NULL DEFAULT 1,
        archived INTEGER NOT NULL DEFAULT 0,
        expires_at INTEGER,
        content_ciphertext BLOB NOT NULL DEFAULT x'',
        content_nonce BLOB NOT NULL DEFAULT x''
      );
      CREATE TABLE sync_kv (key TEXT NOT NULL PRIMARY KEY, value TEXT NOT NULL);
      PRAGMA user_version = 99;
    ''']);
    expect(seed.exitCode, 0, reason: seed.stderr.toString());

    final db = AppDatabase.forTesting(NativeDatabase(file));
    await expectLater(
      db.warmUp(),
      throwsA(isA<DatabaseTooNewException>()
          .having((e) => e.onDisk, 'onDisk', 99)
          .having((e) => e.supported, 'supported', db.schemaVersion)),
    );
    await db.close();

    final check =
        await Process.run('sqlite3', [file.path, 'PRAGMA user_version;']);
    expect(check.exitCode, 0, reason: check.stderr.toString());
    final version = int.parse((check.stdout as String).trim());
    expect(version, 99, reason: 'refusing to migrate must not touch user_version');
  });
}
