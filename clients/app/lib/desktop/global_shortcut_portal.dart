import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart' show debugPrint;

/// Registers one system-wide shortcut through the freedesktop
/// `org.freedesktop.portal.GlobalShortcuts` portal — the only way a Wayland
/// app can get a global hotkey (X11 key grabs never fire there). The desktop
/// (KDE, GNOME 48+, Hyprland) shows the shortcut in its own settings and lets
/// the user rebind it; [preferredTrigger] is only a suggestion.
///
/// Fails soft: if there's no portal, no GlobalShortcuts interface, or the user
/// declines, [start] returns false and the caller falls back to other means.
class GlobalShortcutPortal {
  GlobalShortcutPortal({
    required this.id,
    required this.description,
    required this.preferredTrigger,
    required this.onActivated,
  });

  final String id;
  final String description;

  /// XDG shortcuts syntax, e.g. `CTRL+ALT+n`.
  final String preferredTrigger;
  final void Function() onActivated;

  /// Must match the installed `.desktop` file's name (the GTK application id).
  static const appId = 'dev.librenotes.app';
  static const _bus = 'org.freedesktop.portal.Desktop';
  static const _path = '/org/freedesktop/portal/desktop';
  static const _iface = 'org.freedesktop.portal.GlobalShortcuts';

  DBusClient? _client;
  StreamSubscription<DBusSignal>? _activatedSub;

  /// The Request object path the portal will answer on for [token]
  /// (spec: `/…/request/<sender with ':' dropped, '.' → '_'>/<token>`).
  static String requestPath(String uniqueName, String token) {
    final sender = uniqueName.substring(1).replaceAll('.', '_');
    return '$_path/request/$sender/$token';
  }

  Future<bool> start() async {
    try {
      final client = _client = DBusClient.session();
      await client.ping(); // connects; uniqueName is empty until then
      // Unsandboxed apps must tell the portal who they are first (portal
      // >= 1.19); sandboxed/Flatpak apps already have an id, so errors are fine.
      try {
        await DBusRemoteObject(client,
                name: 'org.freedesktop.portal.Desktop',
                path: DBusObjectPath(_path))
            .callMethod('org.freedesktop.host.portal.Registry', 'Register',
                [DBusString(appId), DBusDict.stringVariant({})]);
      } on DBusMethodResponseException catch (e) {
        debugPrint('Portal app-id registration skipped: ${e.errorName}');
      }
      final portal = DBusRemoteObject(client,
          name: _bus, path: DBusObjectPath(_path));

      final created = await _request(client, portal, 'CreateSession', 'ln_create',
          (token) => [
                DBusDict.stringVariant({
                  'handle_token': DBusString(token),
                  'session_handle_token': const DBusString('ln_session'),
                }),
              ]);
      final session = created?['session_handle']?.asString();
      if (session == null) return false;

      _activatedSub = DBusRemoteObjectSignalStream(
        object: portal,
        interface: _iface,
        name: 'Activated',
      ).listen((s) {
        if (s.values.length > 1 && s.values[1].asString() == id) onActivated();
      });

      final bound = await _request(
        client,
        portal,
        'BindShortcuts',
        'ln_bind',
        (token) => [
          DBusObjectPath(session),
          DBusArray(DBusSignature('(sa{sv})'), [
            DBusStruct([
              DBusString(id),
              DBusDict.stringVariant({
                'description': DBusString(description),
                'preferred_trigger': DBusString(preferredTrigger),
              }),
            ]),
          ]),
          const DBusString(''), // parent window: none
          DBusDict.stringVariant({'handle_token': DBusString(token)}),
        ],
        // The first bind may pop a "choose a shortcut" dialog.
        timeout: const Duration(minutes: 2),
      );
      if (bound == null) await stop();
      return bound != null;
    } catch (e) {
      debugPrint('GlobalShortcuts portal unavailable: $e');
      await stop();
      return false;
    }
  }

  /// Calls a portal method that answers asynchronously via a Request
  /// `Response` signal, subscribing *before* the call so it can't be missed.
  /// Returns the response's result dict, or null if refused/cancelled/timed out.
  Future<Map<String, DBusValue>?> _request(
    DBusClient client,
    DBusRemoteObject portal,
    String method,
    String token,
    List<DBusValue> Function(String token) args, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final response = DBusRemoteObjectSignalStream(
      object: DBusRemoteObject(client,
          name: _bus,
          path: DBusObjectPath(requestPath(client.uniqueName, token))),
      interface: 'org.freedesktop.portal.Request',
      name: 'Response',
    ).first.timeout(timeout);
    await portal.callMethod(_iface, method, args(token),
        replySignature: DBusSignature('o'));
    final signal = await response;
    if (signal.values[0].asUint32() != 0) return null;
    return signal.values[1].asStringVariantDict();
  }

  Future<void> stop() async {
    await _activatedSub?.cancel();
    _activatedSub = null;
    await _client?.close();
    _client = null;
  }
}
