import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../data/notes_repository.dart';
import '../theme.dart';

/// Global-hotkey quick capture for Linux desktop: Ctrl+Alt+N from anywhere
/// (even with LibreNotes unfocused or minimized) shrinks the app window into
/// a small floating capture box, focuses a text field, and creates a note on
/// Enter — then restores the window to exactly how it was before.
///
/// Requires the `keybinder-3.0` system library on Linux (the hotkey_manager
/// plugin's runtime dependency for registering an OS-wide shortcut).
///
/// **Known limitation:** `keybinder-3.0` registers the shortcut via X11's
/// `XGrabKey`, which only works when the app runs under X11 or XWayland. On
/// a native-Wayland GTK session (GDK's default backend when available —
/// common on current GNOME/KDE) the registration call succeeds but the
/// shortcut never fires; GDK logs `Binding '<Primary><Alt>n' failed!` and
/// there is no error surfaced to Dart. Wayland compositors deliberately
/// don't let clients grab arbitrary global shortcuts for security reasons —
/// the correct fix is the `xdg-desktop-portal` GlobalShortcuts portal, which
/// is a materially different (and compositor-support-dependent) integration,
/// not a hotkey_manager option. Until that's built, this feature only works
/// out of the box on X11 sessions; Wayland users can work around it by
/// launching LibreNotes with `GDK_BACKEND=x11` (forces XWayland).
class QuickCaptureController {
  QuickCaptureController(this._repo, this._navigatorKey);

  final NotesRepository _repo;
  final GlobalKey<NavigatorState> _navigatorKey;

  static const _captureSize = Size(480, 220);
  static final _hotKey = HotKey(
    key: PhysicalKeyboardKey.keyN,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  bool _busy = false;
  Rect? _savedBounds;
  bool _wasVisible = true;

  static bool get _supported => !kIsWeb && Platform.isLinux;

  Future<void> init() async {
    if (!_supported) return;
    await windowManager.ensureInitialized();
    await hotKeyManager.unregisterAll(); // guards against stale hot-reload state
    await hotKeyManager.register(_hotKey, keyDownHandler: (_) => _trigger());
  }

  Future<void> teardown() async {
    if (!_supported) return;
    await hotKeyManager.unregister(_hotKey);
  }

  Future<void> _trigger() async {
    if (_busy) return;
    _busy = true;
    _wasVisible = await windowManager.isVisible();
    _savedBounds = await windowManager.getBounds();
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSize(_captureSize);
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
    await _navigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => QuickCaptureScreen(
          onSubmit: _submit,
          onCancel: _cancel,
        ),
      ),
    );
    _busy = false;
  }

  Future<void> _submit(String text) async {
    final trimmed = text.trim();
    if (trimmed.isNotEmpty) {
      final id = await _repo.createNote();
      await _repo.updateContent(id, body: trimmed);
    }
    await _restoreWindow();
    _navigatorKey.currentState?.pop();
  }

  Future<void> _cancel() async {
    await _restoreWindow();
    _navigatorKey.currentState?.pop();
  }

  Future<void> _restoreWindow() async {
    await windowManager.setAlwaysOnTop(false);
    final bounds = _savedBounds;
    if (bounds != null) await windowManager.setBounds(bounds);
    if (!_wasVisible) await windowManager.hide();
  }
}

/// The floating capture UI itself: a single text field, Enter to save,
/// Escape to discard. Deliberately minimal — this is meant to be gone again
/// in a couple of seconds.
class QuickCaptureScreen extends StatefulWidget {
  const QuickCaptureScreen({
    super.key,
    required this.onSubmit,
    required this.onCancel,
  });

  final Future<void> Function(String text) onSubmit;
  final Future<void> Function() onCancel;

  @override
  State<QuickCaptureScreen> createState() => _QuickCaptureScreenState();
}

class _QuickCaptureScreenState extends State<QuickCaptureScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _submitting) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onCancel();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter &&
        !HardwareKeyboard.instance.isShiftPressed) {
      _submit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await widget.onSubmit(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NotallyColors.surface,
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bolt, size: 16, color: NotallyColors.accent),
                  SizedBox(width: 6),
                  Text(
                    'Quick capture',
                    style: TextStyle(
                      color: NotallyColors.textBright,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  autofocus: true,
                  enabled: !_submitting,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                      color: NotallyColors.textPrimary, fontSize: 15),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type a note…',
                    hintStyle: TextStyle(color: NotallyColors.textFaint),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Enter to save · Esc to discard',
                style: TextStyle(color: NotallyColors.textFaint, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
