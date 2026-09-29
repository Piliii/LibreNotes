import 'dart:async';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../sync/note_crypto.dart';
import 'database.dart';

/// A note with its content decrypted — the shape every UI/sync caller works
/// with. [NotesRepository] is the only place that ever touches
/// [LocalNoteRow]'s raw `contentCiphertext`/`contentNonce` blobs.
class NoteRow {
  final String id;
  final String title;
  final String body;
  final bool pinned;
  final String color;
  final int createdAt;
  final int updatedAt;
  final int rev;
  final int seq;
  final bool deleted;
  final bool purged;
  final bool dirty;
  final bool archived;
  final int? expiresAt;

  const NoteRow({
    required this.id,
    required this.title,
    required this.body,
    required this.pinned,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.rev,
    required this.seq,
    required this.deleted,
    required this.purged,
    required this.dirty,
    required this.archived,
    this.expiresAt,
  });
}

/// How long a note stays in the trash before [NotesRepository.sweepTrash]
/// permanently deletes it.
const trashRetention = Duration(days: 30);

/// CRUD over the local notes table. Everything the UI does goes through here so
/// that adding sync later (mark dirty, push/pull) is a change in one place.
///
/// Also the sole boundary for local at-rest encryption: `title`/`body` are
/// stored on disk only as ciphertext, decrypted here on the way out and
/// encrypted here on the way in, using [crypto] — the same DEK that protects
/// notes in transit to the sync server.
class NotesRepository {
  NotesRepository(this._db, NoteCrypto crypto) : _crypto = crypto;

  final AppDatabase _db;
  NoteCrypto _crypto;
  static const _uuid = Uuid();
  Timer? _sweepTimer;

  NoteCrypto get crypto => _crypto;

  /// Re-encrypts every local note's content under [newCrypto] and adopts it
  /// as the repository's active key. Used when sync unlocks a keystore whose
  /// DEK differs from the one this device was using locally — e.g. a second
  /// device joining an account that already has notes on another device.
  /// A no-op if the DEK is already the same.
  Future<void> adoptCrypto(NoteCrypto newCrypto) async {
    final oldBytes = await _crypto.extractDekBytes();
    final newBytes = await newCrypto.extractDekBytes();
    if (_bytesEqual(oldBytes, newBytes)) {
      _crypto = newCrypto;
      return;
    }
    final rows = await _db.select(_db.notes).get();
    for (final row in rows) {
      final payload = await _crypto.decrypt(row.contentCiphertext, row.contentNonce);
      final enc = await newCrypto.encrypt(payload);
      await (_db.update(_db.notes)..where((t) => t.id.equals(row.id))).write(
        NotesCompanion(
          contentCiphertext: Value(enc.ciphertext),
          contentNonce: Value(enc.nonce),
        ),
      );
    }
    _crypto = newCrypto;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<NoteRow> _decrypt(LocalNoteRow row) async {
    final p = await _crypto.decrypt(row.contentCiphertext, row.contentNonce);
    return NoteRow(
      id: row.id,
      title: p['title'] as String? ?? '',
      body: p['body'] as String? ?? '',
      pinned: row.pinned,
      color: row.color,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      rev: row.rev,
      seq: row.seq,
      deleted: row.deleted,
      purged: row.purged,
      dirty: row.dirty,
      archived: row.archived,
      expiresAt: row.expiresAt,
    );
  }

  Future<List<NoteRow>> _decryptAll(List<LocalNoteRow> rows) =>
      Future.wait(rows.map(_decrypt));

  Future<({Uint8List ciphertext, Uint8List nonce})> _encryptContent(
    String title,
    String body,
  ) =>
      _crypto.encrypt({'title': title, 'body': body});

  /// All non-deleted notes (active + archived), for one-shot bulk export.
  /// Trashed notes are excluded — exporting content on its way out feels
  /// wrong as a default.
  Future<List<NoteRow>> getAllForExport() async {
    final rows =
        await (_db.select(_db.notes)..where((t) => t.deleted.equals(false))).get();
    return _decryptAll(rows);
  }

  /// Live list of non-deleted, non-archived notes: pinned first, then most
  /// recently edited. Drift re-emits automatically whenever the table changes.
  Stream<List<NoteRow>> watchNotes() {
    return (_db.select(_db.notes)
          ..where((t) => t.deleted.equals(false) & t.archived.equals(false))
          ..orderBy([
            (t) => OrderingTerm(expression: t.pinned, mode: OrderingMode.desc),
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .asyncMap(_decryptAll);
  }

  /// Live list of archived notes, most recently edited first.
  Stream<List<NoteRow>> watchArchive() {
    return (_db.select(_db.notes)
          ..where((t) => t.archived.equals(true) & t.deleted.equals(false))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
          ]))
        .watch()
        .asyncMap(_decryptAll);
  }

  /// Moves a note to the archive. Reversible via [unarchiveNote].
  Future<void> archiveNote(String id) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      const NotesCompanion(
        archived: Value(true),
        dirty: Value(true),
      ),
    );
  }

  /// Restores a note from the archive back to the main list.
  Future<void> unarchiveNote(String id) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      const NotesCompanion(
        archived: Value(false),
        dirty: Value(true),
      ),
    );
  }

  Stream<NoteRow?> watchNote(String id) {
    return (_db.select(_db.notes)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .asyncMap((row) => row == null ? null : _decrypt(row));
  }

  Future<NoteRow?> getNote(String id) async {
    final row = await (_db.select(_db.notes)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _decrypt(row);
  }

  /// Creates a blank note and returns its id.
  Future<String> createNote() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = _uuid.v4();
    final enc = await _encryptContent('', '');
    await _db.into(_db.notes).insert(
          NotesCompanion.insert(
            id: id,
            contentCiphertext: Value(enc.ciphertext),
            contentNonce: Value(enc.nonce),
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
    // title/body share one ciphertext blob, so a change to either requires
    // re-encrypting the full current pair — fetch it first when needed.
    final textChanged = title != null || body != null;
    Value<Uint8List> contentCiphertext = const Value.absent();
    Value<Uint8List> contentNonce = const Value.absent();
    if (textChanged) {
      final current = await getNote(id);
      final enc = await _encryptContent(
        title ?? current?.title ?? '',
        body ?? current?.body ?? '',
      );
      contentCiphertext = Value(enc.ciphertext);
      contentNonce = Value(enc.nonce);
    }

    // Only bump updatedAt (which drives sort order) when text changes.
    // Color and pin changes are synced via dirty=true but don't reorder notes.
    await (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        contentCiphertext: contentCiphertext,
        contentNonce: contentNonce,
        pinned: pinned == null ? const Value.absent() : Value(pinned),
        color: color == null ? const Value.absent() : Value(color),
        updatedAt: textChanged
            ? Value(DateTime.now().millisecondsSinceEpoch)
            : const Value.absent(),
        dirty: const Value(true),
      ),
    );
  }

  /// Sets or clears a note's self-destruct timestamp (ms since epoch; null
  /// disables it). Enforcement happens client-side via [sweepExpiredNotes].
  Future<void> setExpiry(String id, int? expiresAt) {
    return (_db.update(_db.notes)..where((t) => t.id.equals(id))).write(
      NotesCompanion(
        expiresAt: Value(expiresAt),
        dirty: const Value(true),
      ),
    );
  }

  /// Tombstones any non-deleted note whose [Notes.expiresAt] has passed, using
  /// the same soft-delete path as a manual trash delete so the deletion
  /// propagates to other devices normally.
  Future<void> sweepExpiredNotes() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final expired = await (_db.select(_db.notes)
          ..where((t) =>
              t.deleted.equals(false) &
              t.expiresAt.isNotNull() &
              t.expiresAt.isSmallerOrEqualValue(now)))
        .get();
    for (final note in expired) {
      await deleteNote(note.id);
    }
  }

  /// Permanently deletes notes that have sat in the trash longer than
  /// [retention], through the same path as the user's "Delete permanently"
  /// ([markForPurge]) so the purge propagates to other devices via the server.
  /// A note's trash age is its `updatedAt`, which is stamped when it is
  /// trashed (locally, or from the server's tombstone) and doesn't change
  /// while it stays there.
  Future<void> sweepTrash({Duration retention = trashRetention}) async {
    final cutoff = DateTime.now().subtract(retention).millisecondsSinceEpoch;
    final stale = await (_db.select(_db.notes)
          ..where((t) =>
              t.deleted.equals(true) &
              t.purged.equals(false) &
              t.updatedAt.isSmallerOrEqualValue(cutoff)))
        .get();
    for (final note in stale) {
      await markForPurge(note.id);
    }
  }

  /// Starts the periodic client-side housekeeping: tombstones expired
  /// (self-destructing) notes and purges notes that outlived their time in
  /// the trash. Runs once immediately, then every [period]. Call once at app
  /// startup; the timer lives for the app's lifetime.
  void startSweeps({Duration period = const Duration(minutes: 1)}) {
    _sweepTimer?.cancel();
    Future<void> sweep() async {
      await sweepExpiredNotes();
      await sweepTrash();
    }

    sweep();
    _sweepTimer = Timer.periodic(period, (_) => sweep());
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
        .watch()
        .asyncMap(_decryptAll);
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
  Future<List<NoteRow>> dirtyNotes() async {
    final rows = await (_db.select(_db.notes)..where((t) => t.dirty.equals(true))).get();
    return _decryptAll(rows);
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
    bool archived = false,
    int? expiresAt,
  }) async {
    final enc = await _encryptContent(title, body);
    await _db.into(_db.notes).insertOnConflictUpdate(
          NotesCompanion.insert(
            id: id,
            contentCiphertext: Value(enc.ciphertext),
            contentNonce: Value(enc.nonce),
            pinned: Value(pinned),
            color: Value(color),
            createdAt: createdAt,
            updatedAt: updatedAt,
            rev: Value(rev),
            seq: Value(seq),
            deleted: Value(deleted),
            archived: Value(archived),
            expiresAt: Value(expiresAt),
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
