import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librenotes/data/database.dart';
import 'package:librenotes/data/notes_repository.dart';
import 'package:librenotes/sync/note_crypto.dart';
import 'package:librenotes/ui/loading_screen.dart';
import 'package:librenotes/ui/trash_page.dart';

void main() {
  testWidgets('loading screen shows the logo and app name', (tester) async {
    await tester.pumpWidget(const LoadingApp());
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('LibreNotes'), findsOneWidget);
  });

  testWidgets('trash page shows the retention hint and days left', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = NotesRepository(db, await NoteCrypto.generateLocal());

    final id = await tester.runAsync(() async {
      final id = await repo.createNote();
      await repo.updateContent(id, title: 'Old news', body: 'body');
      await repo.deleteNote(id);
      return id;
    });
    expect(id, isNotNull);

    await tester.pumpWidget(MaterialApp(home: TrashPage(repo: repo)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();

    expect(find.textContaining('permanently deleted after 30 days'), findsOneWidget);
    expect(find.text('Old news'), findsOneWidget);
    expect(find.textContaining('30 days left'), findsOneWidget);

    // Drift's stream cancel schedules a zero-duration timer: unmount, let it
    // fire under the fake clock, then close the db on the real clock (closing
    // it under fake async never completes).
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(db.close);
  });
}
