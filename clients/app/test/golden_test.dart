import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librenotes/data/database.dart';
import 'package:librenotes/data/notes_repository.dart';
import 'package:librenotes/sync/note_crypto.dart';
import 'package:librenotes/sync/sync_service.dart';
import 'package:librenotes/theme.dart';
import 'package:librenotes/ui/home_screen.dart';

// Regenerate with: flutter test --update-goldens test/golden_test.dart
// Fonts come from the Flutter SDK cache (FLUTTER_ROOT, set by `flutter test`),
// so goldens are only stable on the same SDK version.
Future<void> _loadFonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts';
  for (final (family, file) in [
    ('Roboto', 'Roboto-Regular.ttf'),
    ('MaterialIcons', 'MaterialIcons-Regular.otf'),
  ]) {
    final bytes = File('$dir/$file').readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

void main() {
  setUpAll(_loadFonts);

  Future<void> shoot(WidgetTester tester, Size size, String name,
      {Brightness brightness = Brightness.dark}) async {
    NotallyColors.use(brightness);
    // flutter_test draws shadows as solid black outlines by default, which
    // vanish on dark but show as thick rings on the light theme.
    if (brightness == Brightness.light) debugDisableShadows = false;
    addTearDown(() => NotallyColors.use(Brightness.dark));
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final repo = NotesRepository(db, await NoteCrypto.generateLocal());
    final sync = SyncService(repo);
    await tester.runAsync(() async {
      await repo.kvSet('notice.trashPurge', '1'); // skip the one-time dialog
      for (final n in [
        ('Groceries', '- milk\n- eggs\n- coffee'),
        ('', 'A note with no title, so only the body preview shows up here.'),
        ('Ideas', 'Offline-first sync with a **self-hosted** server.\n\nMore text.'),
        ('Meeting', 'Agenda:\n1. Release\n2. Windows build\n3. Folders'),
      ]) {
        final id = await repo.createNote();
        await repo.updateContent(id, title: n.$1, body: n.$2);
      }
      await sync.init();
    });

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildNotallyTheme().copyWith(
        textTheme: buildNotallyTheme().textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: HomeScreen(repo: repo, sync: sync),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // card enter animations

    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
    debugDisableShadows = true; // checked before tearDown runs

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(() async {
      sync.dispose();
      await db.close();
    });
  }

  testWidgets('home desktop', (t) => shoot(t, const Size(1100, 700), 'home_desktop'));
  testWidgets('home mobile', (t) => shoot(t, const Size(400, 800), 'home_mobile'));
  testWidgets('home desktop light', (t) => shoot(t, const Size(1100, 700),
      'home_desktop_light', brightness: Brightness.light));
  testWidgets('home mobile light', (t) => shoot(t, const Size(400, 800),
      'home_mobile_light', brightness: Brightness.light));
}
