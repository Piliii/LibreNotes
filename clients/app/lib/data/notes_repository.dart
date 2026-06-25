import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'database.dart';

/// CRUD over the local notes table. Everything the UI does goes through here so
/// that adding sync later (mark dirty, push/pull) is a change in one place.
class NotesRepository {
  NotesRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  /// Live list of non-deleted notes: pinned first, then most recently edited.
  /// Drift re-emits automatically whenever the table changes.
  Stream<List<NoteRow>> watchNotes() {
    return (_db.select(_db.notes)
          ..where((t) => t.deleted.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.pinned, mode: OrderingMode.desc),
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  Stream<NoteRow?> watchNote(String id) {
    return (_db.select(_db.notes)..where((t) => t.id.equals(id)))
        .watchSingleOrNull();
  }

  Future<NoteRow?> getNote(String id) {
    return (_db.select(_db.notes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Creates a blank note and returns its id.
  Future<String> createNote() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    await _db.into(_db.notes).insert(
          NotesCompanion.insert(
            id: id,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  Future<void> updateContent(
    String id, {
    String? title,
    String? body,
    bool? pinned,
    String? color,
  }) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        title: title == null ? const Value.absent() : Value(title),
        body: body == null ? const Value.absent() : Value(body),
        pinned: pinned == null ? const Value.absent() : Value(pinned),
        color: color == null ? const Value.absent() : Value(color),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        dirty: const Value(true),
      ),
    );
  }

  /// Live list of trashed (soft-deleted) notes, most recently deleted first.
  /// Excludes pending-purge notes (purged=true) so they vanish from the UI
  /// the moment the user permanently deletes them, even before the next sync.
  Stream<List<NoteRow>> watchTrash() {
    return (_db.select(_db.notes)
          ..where((t) => t.deleted.equals(true) & t.purged.equals(false))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch();
  }

  /// Restores a trashed note back to the active list.
  Future<void> restoreNote(String id) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deleted: const Value(false),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        dirty: const Value(true),
      ),
    );
  }

  /// Marks a note for permanent deletion. Keeps the row (purged=true, dirty=true)
  /// so the next sync can push the purge to the server and propagate it to all
  /// other devices before the local row is hard-deleted.
  Future<void> markForPurge(String id) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      const NotesCompanion(
        purged: Value(true),
        dirty: Value(true),
      ),
    );
  }

  /// Marks every trashed note for purge — triggers sync propagation to all devices.
  Future<void> emptyTrash() async {
    final trashed = await watchTrash().first;
    for (final note in trashed) {
      await markForPurge(note.id);
    }
  }

  /// Soft-deletes (tombstone) so the deletion can propagate once sync lands.
  Future<void> deleteNote(String id) async {
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deleted: const Value(true),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
        dirty: const Value(true),
      ),
    );
  }

  // ---- Sync support --------------------------------------------------------

  /// Notes with un-pushed local edits.
  Future<List<NoteRow>> dirtyNotes() {
    return (_db.select(_db.notes)..where((t) => t.dirty.equals(true))).get();
  }

  /// Hard-removes a row (used for deleting a note that never reached the
  /// server, so there is nothing to tombstone remotely).
  Future<void> purge(String id) {
    return (_db.delete(_db.notes)..where((t) => t.id.equals(id))).go();
  }

  /// Records that a local note was accepted by the server at [rev]/[seq].
  Future<void> markSynced(String id, {required int rev, required int seq}) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        rev: Value(rev),
        seq: Value(seq),
        dirty: const Value(false),
      ),
    );
  }

  /// Marks a locally-known note as tombstoned by the server without touching
  /// the local title/body, so the trash page can still display them.
  Future<void> applyTombstone(
    String id, {
    required int rev,
    required int seq,
    required int updatedAt,
  }) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        deleted: const Value(true),
        rev: Value(rev),
        seq: Value(seq),
        updatedAt: Value(updatedAt),
        dirty: const Value(false),
      ),
    );
  }

  /// Upserts a note received (and decrypted) from the server. Marks it clean
  /// since it now matches the server exactly.
  Future<void> applyRemote({
    required String id,
    required String title,
    required String body,
    required bool pinned,
    required String color,
    required int createdAt,
    required int updatedAt,
    required int rev,
    required int seq,
    required bool deleted,
  }) {
    return _db.into(_db.notes).insertOnConflictUpdate(
          NotesCompanion.insert(
            id: id,
            title: Value(title),
            body: Value(body),
            pinned: Value(pinned),
            color: Value(color),
            createdAt: createdAt,
            updatedAt: updatedAt,
            rev: Value(rev),
            seq: Value(seq),
            deleted: Value(deleted),
            dirty: const Value(false),
          ),
        );
  }

  // ---- Key/value sync state ------------------------------------------------

  Future<String?> kvGet(String key) async {
    final row = await (_db.select(_db.syncKv)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> kvSet(String key, String value) {
    return _db.into(_db.syncKv).insertOnConflictUpdate(
          SyncKvCompanion.insert(key: key, value: value),
        );
  }

  Future<void> kvDelete(String key) {
    return (_db.delete(_db.syncKv)..where((t) => t.key.equals(key))).go();
  }
}
