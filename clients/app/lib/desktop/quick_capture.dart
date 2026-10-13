import 'dart:async';
import 'dart:io' show Platform, ProcessSignal;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../data/notes_repository.dart';
import '../theme.dart';
import 'global_shortcut_portal.dart';

/// Global-hotkey quick capture for Linux and Windows desktop: Ctrl+Alt+N from anywhere
/// (even with LibreNotes unfocused or minimized) shrinks the app window into
/// a small floating capture box, focuses a text field, and creates a note on
/// Enter — then restores the window to exactly how it was before.
///
/// Requires the `keybinder-3.0` system library on Linux (the hotkey_manager
/// plugin's runtime dependency for registering an OS-wide shortcut).
///
/// On Wayland the shortcut is registered through the xdg-desktop-portal
/// GlobalShortcuts portal ([GlobalShortcutPortal]); the desktop owns and can
/// rebind it. What follows is the fallback path when no portal is available.
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
/// out of the box on X11 sessions. On Wayland, bind any key in the compositor/
/// DE settings to the command `pkill -USR1 -x librenotes`; SIGUSR1 opens the
/// capture box exactly like the hotkey. Separately, the Linux runner
/// (`linux/runner/main.cc`) sets `GDK_BACKEND=x11` itself when `DISPLAY` is
/// available (XWayland), unless the user already set `GDK_BACKEND`, which
/// sidesteps native-Wayland key-handling bugs but does not make the grab work.
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

  StreamSubscription<ProcessSignal>? _signalSub;
  GlobalShortcutPortal? _portal;
  bool _busy = false;
  Rect? _savedBounds;
  bool _wasVisible = true;

  static bool get _supported =>
      !kIsWeb && (Platform.isLinux || Platform.isWindows);

  Future<void> init() async {
    if (!_supported) return;
    await windowManager.ensureInitialized();
    // Wayland: the portal is the only route to a real global shortcut.
    if (Platform.isLinux &&
        Platform.environment['XDG_SESSION_TYPE'] == 'wayland') {
      final portal = GlobalShortcutPortal(
        id: 'quick-capture',
        description: 'LibreNotes: quick capture note',
        preferredTrigger: 'CTRL+ALT+n',
        onActivated: _trigger,
      );
      if (await portal.start()) _portal = portal;
    }
    await hotKeyManager.unregisterAll(); // guards against stale hot-reload state
    if (_portal == null) {
      await hotKeyManager.register(_hotKey, keyDownHandler: (_) => _trigger());
    }
    // Wayland compositors never deliver global keys to X11/XWayland clients,
    // so the hotkey above can't fire there. Instead, let the compositor / DE
    // own the shortcut and have it run `pkill -USR1 -x librenotes`.
    if (Platform.isLinux) {
      _signalSub = ProcessSignal.sigusr1.watch().listen((_) => _trigger());
    }
  }

  Future<void> teardown() async {
    if (!_supported) return;
    await _signalSub?.cancel();
    await _portal?.stop();
    await hotKeyManager.unregister(_hotKey);
  }

  Future<void> _trigger() async {
    if (_busy) return;
    _busy = true;
    _wasVisible = await windowManager.isVisible();
    _savedBounds = await windowManager.getBounds();
    // Put the capture screen on top *before* resizing/showing, so the window
    // never flashes the full app (squeezed into the small size) first.
    final pushed = _navigatorKey.currentState?.push(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero, // no slide-in while resizing
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => QuickCaptureScreen(
          onSubmit: _submit,
          onCancel: _cancel,
        ),
      ),
    );
    // A hidden window may not render frames, so don't wait on it forever.
    await WidgetsBinding.instance.endOfFrame
        .timeout(const Duration(milliseconds: 200), onTimeout: () {});
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSize(_captureSize);
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
    await pushed;
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
