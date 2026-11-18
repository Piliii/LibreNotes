import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librenotes/data/database.dart';
import 'package:librenotes/data/notes_repository.dart';
import 'package:librenotes/sync/note_crypto.dart';
import 'package:librenotes/ui/attachment_image.dart';
import 'package:librenotes/ui/note_editor.dart';

/// Regression tests for the editor save/refresh behaviour that caused
/// cross-device data loss and "phantom" conflicts: opening a note used to
/// re-save it (bumping updatedAt + rev), and a remote edit arriving while the
/// editor was open was masked by a stale snapshot and then overwritten.
void main() {
  late AppDatabase db;
  late NotesRepository repo;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotesRepository(db, await NoteCrypto.generateLocal());
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

  testWidgets('tapping a Preview checkbox toggles that task in the body',
      (tester) async {
    final id = await repo.createNote();
    await repo.updateContent(id, body: '- [ ] milk\n- [ ] eggs\n- [x] tea');
    await openEditor(tester, id);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_box_outline_blank).at(1));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.check_box).last);
    await tester.pump(const Duration(milliseconds: 600)); // past debounce

    expect((await repo.getNote(id))!.body, '- [ ] milk\n- [x] eggs\n- [ ] tea');
    await closeEditor(tester);
  });

  testWidgets('an embedded image sits below the title, not over it',
      (tester) async {
    final id = await repo.createNote();
    // Not on this device and no server: renders the 72px placeholder,
    // which is taller than a text line, so it exercises line growth.
    await repo.updateContent(id,
        title: 'Cow', body: '![](attachment:missing-1.png)\nafter');
    await openEditor(tester, id);
    await tester.pump(const Duration(milliseconds: 50));

    final title = tester.getRect(find.byType(TextField).first);
    final image = tester.getRect(find.byType(AttachmentImage));
    expect(image.top, greaterThanOrEqualTo(title.bottom));
    expect(image.height, greaterThan(60));
    await closeEditor(tester);
  });

  testWidgets('a file that is not an image shows a message, not a crash',
      (tester) async {
    final id = await repo.createNote();
    await repo.updateContent(id, title: 'T', body: 'b');
    await openEditor(tester, id);

    final body = tester.widget<TextField>(find.byType(TextField).last);
    await tester.runAsync(() async {
      body.contentInsertionConfiguration!.onContentInserted(
          const KeyboardInsertedContent(
              mimeType: 'image/png', uri: 'content://x', data: null));
      await Future<void>.delayed(const Duration(milliseconds: 50));
      body.contentInsertionConfiguration!.onContentInserted(
          KeyboardInsertedContent(
              mimeType: 'image/png',
              uri: 'content://y',
              data: Uint8List.fromList([1, 2, 3])));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await tester.pump();
    expect(find.textContaining("Couldn't add"), findsWidgets);
    expect((await repo.getNote(id))!.body, 'b', reason: 'nothing inserted');
    await closeEditor(tester);
  });
}
