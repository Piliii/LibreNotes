import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/data/database.dart';

void main() {
  test('a v6 database gains the attachments table and becomes v7', () async {
    final dir = await Directory.systemTemp.createTemp('librenotes_v7');
    final file = File('${dir.path}/notally.sqlite');
    addTearDown(() => dir.delete(recursive: true));
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
      PRAGMA user_version = 6;
    ''']);
    expect(seed.exitCode, 0, reason: seed.stderr.toString());

    final db = AppDatabase.forTesting(NativeDatabase(file));
    await db.warmUp();
    expect(await db.select(db.attachments).get(), isEmpty);
    final v = await db.customSelect('PRAGMA user_version').getSingle();
    expect(v.read<int>('user_version'), 7);
    await db.close();
  });
}
