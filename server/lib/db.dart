import 'dart:typed_data';

import 'package:notally_core/notally_core.dart';
import 'package:sqlite3/sqlite3.dart';

/// Thin data layer over SQLite. The server is content-blind: it stores
/// ciphertext blobs and the sync metadata needed for delta pulls
/// (`seq`) and conflict detection (`rev`).
class NotesDb {
  final Database _db;

  NotesDb._(this._db);

  /// Opens (and migrates) the database at [path]. Use ':memory:' for tests.
  factory NotesDb.open(String path) {
    final db = sqlite3.open(path);
    db.execute('PRAGMA journal_mode = WAL;');
    db.execute('PRAGMA foreign_keys = ON;');
    db.execute('''
      CREATE TABLE IF NOT EXISTS notes (
        id         TEXT    PRIMARY KEY,
        ciphertext BLOB    NOT NULL,
        nonce      BLOB    NOT NULL,
        rev        INTEGER NOT NULL,
        seq        INTEGER NOT NULL,
        deleted    INTEGER NOT NULL DEFAULT 0,
        purged     INTEGER NOT NULL DEFAULT 0,
        updated_at INTEGER NOT NULL
      );
    ''');
    // Migration: add purged column to existing databases.
    try {
      db.execute('ALTER TABLE notes ADD COLUMN purged INTEGER NOT NULL DEFAULT 0;');
    } catch (_) {} // column already exists on a fresh or already-migrated db
    db.execute('CREATE INDEX IF NOT EXISTS idx_notes_seq ON notes(seq);');
    db.execute('''
      CREATE TABLE IF NOT EXISTS meta (
        key   TEXT    PRIMARY KEY,
        value INTEGER NOT NULL
      );
    ''');
    db.execute(
      "INSERT OR IGNORE INTO meta(key, value) VALUES ('last_seq', 0);",
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS keystore (
        id           INTEGER PRIMARY KEY CHECK (id = 1),
        wrapped_dek  BLOB    NOT NULL,
        salt         BLOB    NOT NULL,
        kdf_memory   INTEGER NOT NULL,
        kdf_iter     INTEGER NOT NULL,
        kdf_par      INTEGER NOT NULL
      );
    ''');
    return NotesDb._(db);
  }

  void close() => _db.dispose();

  int latestSeq() {
    final r = _db.select("SELECT value FROM meta WHERE key = 'last_seq';");
    return r.first['value'] as int;
  }

  /// Reserves and returns the next global change sequence. Caller must already
  /// be inside a transaction.
  int _nextSeq() {
    _db.execute("UPDATE meta SET value = value + 1 WHERE key = 'last_seq';");
    return latestSeq();
  }

  EncryptedNote? getNote(String id) {
    final r = _db.select('SELECT * FROM notes WHERE id = ?;', [id]);
    if (r.isEmpty) return null;
    return _rowToNote(r.first);
  }

  /// All notes (including tombstones) changed after [sinceSeq], oldest first.
  List<EncryptedNote> changesSince(int sinceSeq) {
    final r = _db.select(
      'SELECT * FROM notes WHERE seq > ? ORDER BY seq ASC;',
      [sinceSeq],
    );
    return r.map(_rowToNote).toList();
  }

  /// Applies a create/update. Returns [PushStatus.conflict] (with the server's
  /// current note) when the client's [baseRev] is stale.
  PushResult push(
    String id,
    Uint8List ciphertext,
    Uint8List nonce,
    int baseRev,
  ) {
    return _inTransaction(() {
      final existing = getNote(id);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (existing == null) {
        // New note. A non-zero baseRev means the client edited a note the
        // server no longer has (e.g. purged) — treat as a fresh create.
        final seq = _nextSeq();
        _db.execute(
          'INSERT INTO notes(id, ciphertext, nonce, rev, seq, deleted, '
          'updated_at) VALUES (?, ?, ?, 1, ?, 0, ?);',
          [id, ciphertext, nonce, seq, now],
        );
        return PushResult(
          status: PushStatus.applied,
          note: EncryptedNote(
            id: id,
            ciphertext: ciphertext,
            nonce: nonce,
            rev: 1,
            seq: seq,
            deleted: false,
            updatedAt: now,
          ),
        );
      }

      if (existing.rev != baseRev) {
        return PushResult(status: PushStatus.conflict, note: existing);
      }

      final newRev = baseRev + 1;
      final seq = _nextSeq();
      _db.execute(
        'UPDATE notes SET ciphertext = ?, nonce = ?, rev = ?, seq = ?, '
        'deleted = 0, purged = 0, updated_at = ? WHERE id = ?;',
        [ciphertext, nonce, newRev, seq, now, id],
      );
      return PushResult(
        status: PushStatus.applied,
        note: EncryptedNote(
          id: id,
          ciphertext: ciphertext,
          nonce: nonce,
          rev: newRev,
          seq: seq,
          deleted: false,
          updatedAt: now,
        ),
      );
    });
  }

  /// Tombstones a note. Same conflict rules as [push]; the ciphertext is
  /// cleared because there is nothing left to decrypt.
  PushResult tombstone(String id, int baseRev) {
    return _inTransaction(() {
      final existing = getNote(id);
      if (existing == null) {
        // Already gone; report conflict so the client can reconcile.
        return PushResult(
          status: PushStatus.conflict,
          note: EncryptedNote(
            id: id,
            ciphertext: Uint8List(0),
            nonce: Uint8List(0),
            rev: 0,
            seq: latestSeq(),
            deleted: true,
            updatedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      if (existing.rev != baseRev) {
        return PushResult(status: PushStatus.conflict, note: existing);
      }
      final newRev = baseRev + 1;
      final seq = _nextSeq();
      final now = DateTime.now().millisecondsSinceEpoch;
      _db.execute(
        'UPDATE notes SET ciphertext = ?, nonce = ?, rev = ?, seq = ?, '
        'deleted = 1, purged = 0, updated_at = ? WHERE id = ?;',
        [Uint8List(0), Uint8List(0), newRev, seq, now, id],
      );
      return PushResult(
        status: PushStatus.applied,
        note: EncryptedNote(
          id: id,
          ciphertext: Uint8List(0),
          nonce: Uint8List(0),
          rev: newRev,
          seq: seq,
          deleted: true,
          updatedAt: now,
        ),
      );
    });
  }

  /// Permanently purges a note. Sets purged=1 so other devices hard-delete the
  /// local row on next pull. No conflict check — once the user empties their
  /// trash, the intent is unambiguous.
  void purge(String id) {
    _inTransaction(() {
      final existing = getNote(id);
      final seq = _nextSeq();
      final now = DateTime.now().millisecondsSinceEpoch;
      if (existing == null) {
        _db.execute(
          'INSERT INTO notes(id, ciphertext, nonce, rev, seq, deleted, purged, '
          'updated_at) VALUES (?, ?, ?, 1, ?, 1, 1, ?);',
          [id, Uint8List(0), Uint8List(0), seq, now],
        );
      } else {
        _db.execute(
          'UPDATE notes SET ciphertext = ?, nonce = ?, rev = ?, seq = ?, '
          'deleted = 1, purged = 1, updated_at = ? WHERE id = ?;',
          [Uint8List(0), Uint8List(0), existing.rev + 1, seq, now, id],
        );
      }
    });
  }

  Keystore? getKeystore() {
    final r = _db.select('SELECT * FROM keystore WHERE id = 1;');
    if (r.isEmpty) return null;
    final row = r.first;
    return Keystore(
      wrappedDek: row['wrapped_dek'] as Uint8List,
      salt: row['salt'] as Uint8List,
      kdfMemory: row['kdf_memory'] as int,
      kdfIterations: row['kdf_iter'] as int,
      kdfParallelism: row['kdf_par'] as int,
    );
  }

  void setKeystore(Keystore ks) {
    _db.execute(
      'INSERT INTO keystore(id, wrapped_dek, salt, kdf_memory, kdf_iter, '
      'kdf_par) VALUES (1, ?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET wrapped_dek = excluded.wrapped_dek, '
      'salt = excluded.salt, kdf_memory = excluded.kdf_memory, '
      'kdf_iter = excluded.kdf_iter, kdf_par = excluded.kdf_par;',
      [ks.wrappedDek, ks.salt, ks.kdfMemory, ks.kdfIterations, ks.kdfParallelism],
    );
  }

  T _inTransaction<T>(T Function() body) {
    _db.execute('BEGIN IMMEDIATE;');
    try {
      final result = body();
      _db.execute('COMMIT;');
      return result;
    } catch (_) {
      _db.execute('ROLLBACK;');
      rethrow;
    }
  }

  EncryptedNote _rowToNote(Row row) => EncryptedNote(
    id: row['id'] as String,
    ciphertext: row['ciphertext'] as Uint8List,
    nonce: row['nonce'] as Uint8List,
    rev: row['rev'] as int,
    seq: row['seq'] as int,
    deleted: (row['deleted'] as int) == 1,
    purged: (row['purged'] as int) == 1,
    updatedAt: row['updated_at'] as int,
  );
}
