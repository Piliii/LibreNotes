import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librenotes/data/database.dart';
import 'package:librenotes/data/notes_repository.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotesRepository(db);
  });

  tearDown(() => db.close());

  test('setExpiry stores the timestamp and marks the note dirty', () async {
    final id = await repo.createNote();
    await repo.markSynced(id, rev: 1, seq: 1); // clear the initial dirty=true

    final future = DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch;
    await repo.setExpiry(id, future);

    final note = await repo.getNote(id);
    expect(note!.expiresAt, future);
    expect(note.dirty, isTrue);
  });

  test('setExpiry(null) clears a previously set timer', () async {
    final id = await repo.createNote();
    await repo.setExpiry(
        id, DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch);

    await repo.setExpiry(id, null);

    final note = await repo.getNote(id);
    expect(note!.expiresAt, isNull);
  });

  test('sweepExpiredNotes tombstones only notes past their expiry', () async {
    final expired = await repo.createNote();
    await repo.setExpiry(
        expired, DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch);

    final notYet = await repo.createNote();
    await repo.setExpiry(
        notYet, DateTime.now().add(const Duration(days: 1)).millisecondsSinceEpoch);

    final noTimer = await repo.createNote();

    await repo.sweepExpiredNotes();

    expect((await repo.getNote(expired))!.deleted, isTrue);
    expect((await repo.getNote(notYet))!.deleted, isFalse);
    expect((await repo.getNote(noTimer))!.deleted, isFalse);
  });

  test('sweepExpiredNotes does not re-tombstone an already-deleted note', () async {
    final id = await repo.createNote();
    await repo.setExpiry(
        id, DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch);
    await repo.deleteNote(id);
    await repo.markSynced(id, rev: 1, seq: 1);

    await repo.sweepExpiredNotes();

    // No-op: the note was already tombstoned and clean, sweeping shouldn't
    // touch it again (e.g. re-dirty it) since it's not re-selected.
    final note = await repo.getNote(id);
    expect(note!.dirty, isFalse);
  });
}
