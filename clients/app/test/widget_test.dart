import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librenotes/data/database.dart';
import 'package:librenotes/data/notes_repository.dart';
import 'package:librenotes/main.dart';
import 'package:librenotes/sync/sync_service.dart';

void main() {
  // ---- Repository (the real local-store logic) ----------------------------

  group('NotesRepository', () {
    late AppDatabase db;
    late NotesRepository repo;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = NotesRepository(db);
    });
    tearDown(() => db.close());

    test('createNote then edit surfaces in the live list', () async {
      final id = await repo.createNote();
      await repo.updateContent(id, title: 'Hello', body: 'world');

      final notes = await repo.watchNotes().first;
      expect(notes.single.title, 'Hello');
      expect(notes.single.body, 'world');
      expect(notes.single.deleted, isFalse);
    });

    test('deleteNote tombstones and hides it from the list', () async {
      final id = await repo.createNote();
      await repo.deleteNote(id);

      expect(await repo.watchNotes().first, isEmpty);
      // The row still exists (tombstone) so the delete can sync later.
      expect((await repo.getNote(id))!.deleted, isTrue);
    });

    test('watchTrash returns only deleted notes', () async {
      final a = await repo.createNote();
      await repo.createNote(); // b — kept active
      await repo.deleteNote(a);

      expect(await repo.watchNotes().first, hasLength(1)); // b only
      final trash = await repo.watchTrash().first;
      expect(trash.single.id, a);
    });

    test('restoreNote moves a note back to the active list', () async {
      final id = await repo.createNote();
      await repo.deleteNote(id);
      await repo.restoreNote(id);

      expect(await repo.watchNotes().first, hasLength(1));
      expect(await repo.watchTrash().first, isEmpty);
    });

    test('emptyTrash marks all trashed notes for purge and hides them from trash view', () async {
      final a = await repo.createNote();
      final b = await repo.createNote();
      await repo.deleteNote(a);
      await repo.deleteNote(b);
      await repo.emptyTrash();

      // Trash view is empty (watchTrash excludes purge-pending rows).
      expect(await repo.watchTrash().first, isEmpty);
      // Rows still exist locally with purged=true until the next sync pushes
      // the purge to the server and receives confirmation.
      expect((await repo.getNote(a))!.purged, isTrue);
      expect((await repo.getNote(b))!.purged, isTrue);
    });

    test('pinned notes sort ahead of unpinned', () async {
      final a = await repo.createNote();
      await repo.updateContent(a, title: 'plain');
      final b = await repo.createNote();
      await repo.updateContent(b, title: 'pinned', pinned: true);

      final notes = await repo.watchNotes().first;
      expect(notes.first.title, 'pinned');
    });
  });

  // ---- Widget smoke test (no spinner → safe to pump) ----------------------

  testWidgets('renders the desktop shell', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = NotesRepository(db);
    final sync = SyncService(repo);
    addTearDown(db.close);
    addTearDown(sync.dispose);

    await tester.pumpWidget(NotallyApp(repo: repo, sync: sync));
    await tester.pump(); // build
    await tester.pump(const Duration(milliseconds: 50)); // first stream emit

    expect(find.text('Notes'), findsOneWidget);
    expect(find.text('+ New Note'), findsOneWidget);

    // Unmount so drift's query-stream subscription is cancelled — that schedules
    // an internal cache-cleanup Timer — then pump to let it fire, so it isn't
    // still pending when the framework checks invariants at end of test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
