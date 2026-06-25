import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Local note table. Mirrors the shared `Note` model plus the sync metadata
/// each device caches (`rev`, `seq`, `deleted`) — unused while local-only, but
/// already here so wiring sync later is additive, not a migration.
@DataClassName('NoteRow')
class Notes extends Table {
  TextColumn get id => text()(); // UUID, client-generated
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get body => text().withDefault(const Constant(''))();
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
  int get schemaVersion => 3;

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
        },
      );

  static QueryExecutor _open() => driftDatabase(name: 'notally');
}
