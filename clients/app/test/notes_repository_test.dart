import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librenotes/data/database.dart';
import 'package:librenotes/data/notes_repository.dart';
import 'package:librenotes/sync/note_crypto.dart';

void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotesRepository(db, await NoteCrypto.generateLocal());
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

  group('sweepTrash', () {
    Future<void> backdate(String id, Duration age) {
      final ms = DateTime.now().subtract(age).millisecondsSinceEpoch;
      return (db.update(db.notes)..where((t) => t.id.equals(id)))
          .write(NotesCompanion(updatedAt: Value(ms)));
    }

    test('marks only notes trashed longer than the retention for purge', () async {
      final old = await repo.createNote();
      await repo.deleteNote(old);
      await backdate(old, trashRetention + const Duration(days: 1));

      final recent = await repo.createNote();
      await repo.deleteNote(recent);
      await backdate(recent, trashRetention - const Duration(days: 1));

      final live = await repo.createNote();
      await backdate(live, trashRetention * 2); // old but not trashed

      await repo.sweepTrash();

      expect((await repo.getNote(old))!.purged, isTrue);
      expect((await repo.getNote(old))!.dirty, isTrue);
      expect((await repo.getNote(recent))!.purged, isFalse);
      expect((await repo.getNote(live))!.purged, isFalse);
      expect((await repo.getNote(live))!.deleted, isFalse);
    });

    test('ensureTrashGrace starts a one-time window that blocks the sweep',
        () async {
      final id = await repo.createNote();
      await repo.deleteNote(id);
      await backdate(id, trashRetention + const Duration(days: 1));

      await repo.ensureTrashGrace();
      final until = repo.trashGraceUntil!;
      expect(until.difference(DateTime.now()).inHours, inInclusiveRange(71, 72));

      await repo.sweepTrash();
      expect((await repo.getNote(id))!.purged, isFalse);

      // A later launch reloads the same deadline instead of restarting it.
      await repo.ensureTrashGrace();
      expect(repo.trashGraceUntil, until);
    });

    test('sweep resumes once the grace window has passed', () async {
      final id = await repo.createNote();
      await repo.deleteNote(id);
      await backdate(id, trashRetention + const Duration(days: 1));
      await repo.kvSet(
          'trash.graceUntil',
          DateTime.now()
              .subtract(const Duration(minutes: 1))
              .millisecondsSinceEpoch
              .toString());

      await repo.ensureTrashGrace();
      await repo.sweepTrash();

      expect((await repo.getNote(id))!.purged, isTrue);
    });

    test('purged notes drop out of the trash list', () async {
      final id = await repo.createNote();
      await repo.deleteNote(id);
      await backdate(id, trashRetention + const Duration(days: 1));
      expect(await repo.watchTrash().first, hasLength(1));

      await repo.sweepTrash();

      expect(await repo.watchTrash().first, isEmpty);
    });

    test('is idempotent: an already-purged note is not touched again', () async {
      final id = await repo.createNote();
      await repo.deleteNote(id);
      await backdate(id, trashRetention + const Duration(days: 1));
      await repo.sweepTrash();
      await repo.markSynced(id, rev: 1, seq: 1);

      await repo.sweepTrash();

      expect((await repo.getNote(id))!.dirty, isFalse);
    });

    test('honors a custom retention', () async {
      final id = await repo.createNote();
      await repo.deleteNote(id);
      await backdate(id, const Duration(days: 2));

      await repo.sweepTrash(retention: const Duration(days: 1));

      expect((await repo.getNote(id))!.purged, isTrue);
    });
  });

  group('searchIds (in-memory FTS5)', () {
    test('matches substrings case-insensitively across title and body, ANDs terms',
        () async {
      final a = await repo.createNote();
      await repo.updateContent(a, title: 'Grocery List', body: 'buy oatmeal');
      final b = await repo.createNote();
      await repo.updateContent(b, title: 'Work', body: 'quarterly OATMEAL report');

      expect(await repo.searchIds('oatmeal'), {a, b});
      expect(await repo.searchIds('GROCERY'), {a});
      expect(await repo.searchIds('atme'), {a, b}); // mid-word, like substring
      expect(await repo.searchIds('oatmeal report'), {b});
      expect(await repo.searchIds('nope'), isEmpty);
      // FTS syntax in user input is quoted, not interpreted.
      expect(await repo.searchIds('oat"x'), isEmpty);
    });

    test('short terms defer to the caller (null)', () async {
      expect(await repo.searchIds('ab'), isNull);
      expect(await repo.searchIds('   '), isNull);
    });

    test('index follows edits, trashing and clearSearchIndex', () async {
      final id = await repo.createNote();
      await repo.updateContent(id, body: 'alpha');
      expect(await repo.searchIds('alpha'), {id});

      await repo.updateContent(id, body: 'bravo');
      expect(await repo.searchIds('alpha'), isEmpty);
      expect(await repo.searchIds('bravo'), {id});

      await repo.clearSearchIndex();
      expect(await repo.searchIds('bravo'), {id}); // rebuilt on demand

      await repo.deleteNote(id);
      expect(await repo.searchIds('bravo'), isEmpty);
    });
  });
}
