import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'data/database.dart';
import 'data/notes_repository.dart';
import 'sync/sync_service.dart';
import 'theme.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  final repo = NotesRepository(db);
  final sync = SyncService(repo);
  await sync.init();
  runApp(NotallyApp(repo: repo, sync: sync));
}

class NotallyApp extends StatelessWidget {
  const NotallyApp({super.key, required this.repo, required this.sync});

  final NotesRepository repo;
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notally',
      debugShowCheckedModeBanner: false,
      theme: buildNotallyTheme(),
      home: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyQ, control: true): _quit,
          const SingleActivator(LogicalKeyboardKey.keyW, control: true): _quit,
        },
        child: Focus(
          autofocus: true,
          child: HomeScreen(repo: repo, sync: sync),
        ),
      ),
    );
  }

  static void _quit() {
    if (!kIsWeb && Platform.isLinux) exit(0);
  }
}
