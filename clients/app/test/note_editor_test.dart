import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librenotes/data/database.dart';
import 'package:librenotes/data/notes_repository.dart';
import 'package:librenotes/ui/note_editor.dart';

/// Regression tests for the editor save/refresh behaviour that caused
/// cross-device data loss and "phantom" conflicts: opening a note used to
/// re-save it (bumping updatedAt + rev), and a remote edit arriving while the
/// editor was open was masked by a stale snapshot and then overwritten.
void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotesRepository(db);
  });
  tearDown(() => db.close());

  Future<void> openEditor(WidgetTester tester, String id,
      {VoidCallback? onEdited}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: NoteEditor(repo: repo, noteId: id, onEdited: onEdited),
      ),
    ));
    await tester.pump(); // build (loading)
    await tester.pump(const Duration(milliseconds: 50)); // first stream emit
  }

  Future<void> closeEditor(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 700)); // settle debounce/flush
  }

  testWidgets('opening and closing without typing does not re-save the note',
      (tester) async {
    final id = await repo.createNote();
    await repo.updateContent(id, title: 'Stable', body: 'content');
    await repo.markSynced(id, rev: 1, seq: 1); // now clean, like a synced note
    final before = (await repo.getNote(id))!;
    expect(before.dirty, isFalse);

    await openEditor(tester, id);
    await closeEditor(tester);

    final after = (await repo.getNote(id))!;
    expect(after.dirty, isFalse,
        reason: 'merely opening a note must not mark it dirty');
    expect(after.updatedAt, before.updatedAt,
        reason: 'updatedAt drives sort order; opening must not bump it');
    expect(after.rev, before.rev);
  });

  testWidgets('a remote edit is adopted live and not overwritten on close',
      (tester) async {
    final id = await repo.createNote();
    await repo.updateContent(id, title: 'Local', body: 'original');
    await repo.markSynced(id, rev: 1, seq: 1);
    final before = (await repo.getNote(id))!;

    await openEditor(tester, id);
    expect(find.text('original'), findsOneWidget);

    // Another device's edit lands while the editor is open and idle.
    await repo.applyRemote(
      id: id,
      title: 'Local',
      body: 'from other device',
      pinned: false,
      color: '#2a2a2a',
      createdAt: before.createdAt,
      updatedAt: before.updatedAt + 1000,
      rev: 2,
      seq: 2,
      deleted: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    // The editor shows the synced text live (no stale snapshot masking it).
    expect(find.text('from other device'), findsOneWidget);
    expect(find.text('original'), findsNothing);

    await closeEditor(tester);

    final after = (await repo.getNote(id))!;
    expect(after.body, 'from other device',
        reason: 'editor must not overwrite a synced change with its snapshot');
    expect(after.dirty, isFalse,
        reason: 'adopting a remote change is not a local edit');
  });

  testWidgets('a real edit persists and notifies onEdited', (tester) async {
    var edited = false;
    final id = await repo.createNote();
    await repo.updateContent(id, title: 'Local', body: 'original');
    await repo.markSynced(id, rev: 1, seq: 1);

    await openEditor(tester, id, onEdited: () => edited = true);

    await tester.enterText(find.byType(TextField).last, 'edited body');
    await tester.pump(const Duration(milliseconds: 600)); // past 500ms debounce

    final after = (await repo.getNote(id))!;
    expect(after.body, 'edited body');
    expect(after.dirty, isTrue);
    expect(edited, isTrue, reason: 'onEdited should fire so sync can push');

    await closeEditor(tester);
  });
}
