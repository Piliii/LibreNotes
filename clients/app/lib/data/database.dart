import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'local_key_manager.dart';

part 'database.g.dart';

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
          // v1 → v2: dirty flag + sync key/value table.
          if (from < 2) {
            await m.addColumn(notes, notes.dirty);
            await m.createTable(syncKv);
          }
          // v2 → v3: purged flag for propagating permanent trash deletes.
          if (from < 3) {
            await m.addColumn(notes, notes.purged);
          }
          // v3 → v4: archived flag (client-side, part of encrypted payload).
          if (from < 4) {
            await m.addColumn(notes, notes.archived);
          }
          // v4 → v5: optional self-destruct timestamp.
          if (from < 5) {
            await m.addColumn(notes, notes.expiresAt);
          }
          // v5 → v6: encrypt title/body at rest. Existing rows still have the
          // plaintext `title`/`body` columns at this point — add the new blob
          // columns, encrypt each row's content into them using the local DEK
          // (reusing one from a previously configured sync account if this
          // device has one; generating+persisting a fresh one otherwise, safe
          // since nothing has ever been encrypted locally before this step),
          // then drop the now-redundant plaintext columns entirely.
          if (from < 6) {
            await m.addColumn(notes, notes.contentCiphertext);
            await m.addColumn(notes, notes.contentNonce);
            final crypto = await LocalKeyManager.ensure();
            final rows =
                await m.database.customSelect('SELECT id, title, body FROM notes').get();
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
