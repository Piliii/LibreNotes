import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'android/share_intent.dart';
import 'data/database.dart';
import 'data/local_key_manager.dart';
import 'data/notes_repository.dart';
import 'desktop/quick_capture.dart';
import 'sync/note_crypto.dart';
import 'sync/sync_service.dart';
import 'theme.dart';
import 'ui/home_screen.dart';
import 'ui/locked_recovery_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = AppDatabase();
  // Forces any pending schema migration to run now, so the local DEK is
  // guaranteed to be in the keyring (or we already know it can't be) before
  // deciding whether to boot straight into the app or into recovery.
  await db.warmUp();

  try {
    final crypto = await LocalKeyManager.resolve(db);
    await _launch(db, crypto);
  } on LocalKeyStorageException {
    runApp(_RecoveryApp(db: db));
  }
}

/// Builds the real app once the local at-rest DEK is resolved. Also the
/// target of [LockedRecoveryScreen.onRecovered], so recovering swaps the
/// recovery screen out for the normal app without needing a process restart.
Future<void> _launch(AppDatabase db, NoteCrypto crypto) async {
  final repo = NotesRepository(db, crypto);
  repo.startExpirySweep();
  final sync = SyncService(repo);
  await sync.init();
  final navigatorKey = GlobalKey<NavigatorState>();
  final quickCapture = QuickCaptureController(repo, navigatorKey);
  await quickCapture.init();
  final shareIntent = ShareIntentService(repo, navigatorKey);
  runApp(NotallyApp(
    repo: repo,
    sync: sync,
    navigatorKey: navigatorKey,
    quickCapture: quickCapture,
  ));
  // Deferred until after the first frame: a cold start via the share sheet
  // needs `navigatorKey.currentState` mounted before it can push the editor
  // route, which isn't true yet synchronously after `runApp`.
  WidgetsBinding.instance.addPostFrameCallback((_) => shareIntent.init());
}

class _RecoveryApp extends StatelessWidget {
  const _RecoveryApp({required this.db});

  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LibreNotes',
      debugShowCheckedModeBanner: false,
      theme: buildNotallyTheme(),
      home: LockedRecoveryScreen(
        db: db,
        onRecovered: (crypto) => _launch(db, crypto),
      ),
    );
  }
}

class NotallyApp extends StatefulWidget {
  NotallyApp({
    super.key,
    required this.repo,
    required this.sync,
    GlobalKey<NavigatorState>? navigatorKey,
    this.quickCapture,
  }) : navigatorKey = navigatorKey ?? GlobalKey<NavigatorState>();

  final NotesRepository repo;
  final SyncService sync;
  final GlobalKey<NavigatorState> navigatorKey;

  /// Null in contexts that don't need the Linux quick-capture hotkey (e.g.
  /// widget tests); [_NotallyAppState.dispose] skips teardown when absent.
  final QuickCaptureController? quickCapture;

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
      widget.quickCapture?.teardown();
    }
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (!HardwareKeyboard.instance.isControlPressed) return false;
    // Ctrl+W is intentionally omitted: GTK consumes it at the IME level for
    // "delete word" in TextFields, so Flutter only sees the orphaned KeyUp
    // event and emits keyboard-state warnings. Ctrl+Q is the quit shortcut.
    if (event.logicalKey == LogicalKeyboardKey.keyQ) {
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
      navigatorKey: widget.navigatorKey,
      home: HomeScreen(repo: widget.repo, sync: widget.sync),
    );
  }
}
