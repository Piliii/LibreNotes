import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/notes_repository.dart';
import '../ui/note_editor.dart';

/// Registers LibreNotes as an Android share target: text/links shared from
/// any other app (via the system share sheet's `ACTION_SEND`) become a new
/// note, which is then opened directly in the editor.
///
/// The native side lives in `MainActivity.kt`, which exposes a single method
/// channel (`dev.librenotes.app/share`): `getInitialSharedText` answers a
/// cold start launched by a share, and `onSharedText` is pushed for a share
/// that arrives while the app is already running (`singleTop` launch mode
/// routes it through `onNewIntent` instead of a fresh process).
class ShareIntentService {
  ShareIntentService(this._repo, this._navigatorKey);

  final NotesRepository _repo;
  final GlobalKey<NavigatorState> _navigatorKey;

  static const _channel = MethodChannel('dev.librenotes.app/share');

  static bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<void> init() async {
    if (!_supported) return;
    _channel.setMethodCallHandler(_handleCall);
    final initial =
        await _channel.invokeMethod<String>('getInitialSharedText');
    if (initial != null) await _createNoteFrom(initial);
  }

  Future<void> _handleCall(MethodCall call) async {
    if (call.method == 'onSharedText') {
      final text = call.arguments as String?;
      if (text != null) await _createNoteFrom(text);
    }
  }

  Future<void> _createNoteFrom(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final id = await _repo.createNote();
    await _repo.updateContent(id, body: trimmed);
    _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => NoteEditorPage(repo: _repo, noteId: id),
      ),
    );
  }
}
