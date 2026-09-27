import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'local_key_manager.dart';

part 'database.g.dart';

/// Thrown when the schema already on disk is newer than this binary
/// understands ([AppDatabase.schemaVersion]) — i.e. a different, newer
/// install already migrated this database further than this build knows
/// about. There's nothing safe to do here: migrating "downward" isn't a
/// real operation, and letting drift's migrator no-op through would corrupt
/// `PRAGMA user_version` (see the guard in [AppDatabase.migration]). The
/// caller should stop and tell the user to update instead.
class DatabaseTooNewException implements Exception {
  DatabaseTooNewException(this.onDisk, this.supported);

  /// The schema version found in the database file.
  final int onDisk;

  /// The schema version this binary is built to understand.
  final int supported;

  @override
  String toString() =>
      'DatabaseTooNewException: database is at schema $onDisk, this app '
      'build only supports up to $supported. Update the app.';
}

/// Local note table. Mirrors the shared `Note` model plus the sync metadata
/// each device caches (`rev`, `seq`, `deleted`) — unused while local-only, but
/// already here so wiring sync later is additive, not a migration.
///
/// `title`/`body` are *not* plaintext columns: they're encrypted together
/// (as `{title, body}`) into [contentCiphertext]/[contentNonce] using the
/// same DEK that protects notes in transit to the server (see
/// `NotesRepository`, which is the only place that ever sees the decrypted
/// pair). Everything else here stays plaintext locally because the app
/// itself needs to sort/filter on it (pinned, timestamps, archived, ...) —
/// only the free-text content is sensitive enough, and expensive enough to
/// query encrypted, to warrant this split.
@DataClassName('LocalNoteRow')
class Notes extends Table {
  TextColumn get id => text()(); // UUID, client-generated
  BlobColumn get contentCiphertext =>
      blob().withDefault(Constant(Uint8List(0)))();
  BlobColumn get contentNonce => blob().withDefault(Constant(Uint8List(0)))();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  TextColumn get color => text().withDefault(const Constant('#2a2a2a'))();
  IntColumn get createdAt => integer()(); // ms since epoch
  IntColumn get updatedAt => integer()();
  IntColumn get rev => integer().withDefault(const Constant(0))();
  IntColumn get seq => integer().withDefault(const Constant(0))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))();

  /// True when the user permanently deleted this note from trash. Kept as a
  /// row (dirty=true) until the purge is pushed to the server, then the row
  /// is hard-deleted locally. This propagates via the server so other devices
  /// also hard-delete.
  BoolColumn get purged => boolean().withDefault(const Constant(false))();

  /// True when the note has local edits not yet pushed to the server. Set on
  /// every local write, cleared once the push is accepted.
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  /// True when the user has archived this note. Archived notes are hidden from
  /// the main list but not deleted. Part of the encrypted payload so it syncs
  /// across devices; the server never sees it.
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// Optional self-destruct timestamp (ms since epoch). Null means the note
  /// never expires. Part of the encrypted payload so it syncs across devices;
  /// the server never sees it. Enforced client-side by a periodic sweep that
  /// tombstones expired notes via the normal delete path.
  IntColumn get expiresAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Simple key/value store for sync state (server URL, bearer token, the `seq`
/// cursor, and the wrapped keystore). One row per key.
class SyncKv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Notes, SyncKv])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_open());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Drift calls this same callback for downgrades too (from > to) —
          // e.g. an out-of-date app binary opening a database a newer
          // install already migrated further. Below, every step is guarded
          // by `if (from < N)`, so a downgrade would just run zero steps and
          // return successfully — and drift stamps `user_version` with
          // *this build's* (lower) schemaVersion right after onUpgrade
          // returns, regardless of whether it actually changed anything
          // (see drift's `_runMigrations`). That silently rewrites the
          // version number backward while the table shape stays exactly as
          // the newer install left it, corrupting the version bookkeeping
          // for every future launch. Refuse instead of letting that happen.
          // This happened for real: a stale AUR package (v1.2.0) kept
          // undoing schema-version fixes made against the current source
          // tree. See db repair on 2026-09-27.
          if (from > to) {
            throw DatabaseTooNewException(from, to);
          }
          // Each step below bumps `user_version` on disk as soon as it
          // completes, instead of relying on drift to do it once at the very
          // end. If the process dies partway through this function (hot
          // restart, a slow/failing step further down, a killed process),
          // the already-applied ALTER TABLEs stay committed (SQLite
          // auto-commits DDL) but the version number would otherwise be
          // stuck behind — causing every future launch to re-run completed
          // steps and crash-loop on "duplicate column". See db repair on
          // 2026-09-27 (and 2026-09-06, 2026-09-24 — same failure mode hit
          // this exact dev database three times before this fix).
          // v1 → v2: dirty flag + sync key/value table.
          if (from < 2) {
            await m.addColumn(notes, notes.dirty);
            await m.createTable(syncKv);
            await m.database.customStatement('PRAGMA user_version = 2');
          }
          // v2 → v3: purged flag for propagating permanent trash deletes.
          if (from < 3) {
            await m.addColumn(notes, notes.purged);
            await m.database.customStatement('PRAGMA user_version = 3');
          }
          // v3 → v4: archived flag (client-side, part of encrypted payload).
          if (from < 4) {
            await m.addColumn(notes, notes.archived);
            await m.database.customStatement('PRAGMA user_version = 4');
          }
          // v4 → v5: optional self-destruct timestamp.
          if (from < 5) {
            await m.addColumn(notes, notes.expiresAt);
            await m.database.customStatement('PRAGMA user_version = 5');
          }
          // v5 → v6: encrypt title/body at rest. Existing rows still have the
          // plaintext `title`/`body` columns at this point — add the new blob
          // columns, encrypt each row's content into them using the local DEK
          // (reusing one from a previously configured sync account if this
          // device has one; generating+persisting a fresh one otherwise, safe
          // since nothing has ever been encrypted locally before this step),
          // then drop the now-redundant plaintext columns entirely.
          if (from < 6) {
            final columns = await m.database
                .customSelect("SELECT name FROM pragma_table_info('notes')")
                .get();
            final columnNames =
                columns.map((r) => r.read<String>('name')).toSet();
            if (!columnNames.contains('content_ciphertext')) {
              await m.addColumn(notes, notes.contentCiphertext);
            }
            if (!columnNames.contains('content_nonce')) {
              await m.addColumn(notes, notes.contentNonce);
            }
            // `title`/`body` are only dropped once every row has been
            // encrypted, so their presence is what tells a resumed migration
            // whether the encrypt loop below still needs to run — the row
            // selection itself (rows with empty ciphertext) makes the loop
            // safe to redo from scratch.
            if (columnNames.contains('title') || columnNames.contains('body')) {
              final crypto = await LocalKeyManager.ensure();
              final rows = await m.database
                  .customSelect(
                    'SELECT id, title, body FROM notes '
                    'WHERE length(content_ciphertext) = 0',
                  )
                  .get();
              for (final row in rows) {
                final id = row.read<String>('id');
                final title = row.read<String>('title');
                final body = row.read<String>('body');
                final enc = await crypto.encrypt({'title': title, 'body': body});
                await m.database.customStatement(
                  'UPDATE notes SET content_ciphertext = ?, content_nonce = ? WHERE id = ?',
                  [enc.ciphertext, enc.nonce, id],
                );
              }
              await m.database.customStatement('ALTER TABLE notes DROP COLUMN title');
              await m.database.customStatement('ALTER TABLE notes DROP COLUMN body');
            }
            await m.database.customStatement('PRAGMA user_version = 6');
          }
        },
      );

  /// Forces the (possibly pending) `onCreate`/`onUpgrade` migration to run
  /// before returning, so callers can rely on the local DEK already being in
  /// the keyring by the time this completes (see [LocalKeyManager.resolve]).
  Future<void> warmUp() => customSelect('SELECT 1').get();

  Future<int> notesRowCount() async {
    final row = await customSelect('SELECT COUNT(*) AS c FROM notes').getSingle();
    return row.read<int>('c');
  }

  static QueryExecutor _open() => driftDatabase(name: 'notally');
}
