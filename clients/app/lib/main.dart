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

class NotallyApp extends StatefulWidget {
  const NotallyApp({super.key, required this.repo, required this.sync});

  final NotesRepository repo;
  final SyncService sync;

  @override
  State<NotallyApp> createState() => _NotallyAppState();
}

class _NotallyAppState extends State<NotallyApp> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && Platform.isLinux) {
      HardwareKeyboard.instance.addHandler(_handleKey);
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && Platform.isLinux) {
      HardwareKeyboard.instance.removeHandler(_handleKey);
    }
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isControlPressed) return false;
    if (event.logicalKey == LogicalKeyboardKey.keyQ ||
        event.logicalKey == LogicalKeyboardKey.keyW) {
      exit(0);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibreNotes',
      debugShowCheckedModeBanner: false,
      theme: buildNotallyTheme(),
      home: HomeScreen(repo: widget.repo, sync: widget.sync),
    );
  }
}
