import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../sync/sync_service.dart';
import '../theme.dart';
import 'conflicts_page.dart';

/// Connect/unlock screen: server URL, bearer token, and passphrase.
class SyncSettingsPage extends StatefulWidget {
  const SyncSettingsPage({super.key, required this.service});

  final SyncService service;

  @override
  State<SyncSettingsPage> createState() => _SyncSettingsPageState();
}

class _SyncSettingsPageState extends State<SyncSettingsPage> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _prefill();
  }

  Future<void> _prefill() async {
    final url = await widget.service.savedBaseUrl;
    final token = await widget.service.savedToken;
    if (!mounted) return;
    setState(() {
      if (url != null) _url.text = url;
      if (token != null) _token.text = token;
    });
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      await widget.service.connect(
        baseUrl: _url.text.trim(),
        token: _token.text.trim(),
        passphrase: _pass.text,
      );
    } catch (_) {
      // Status notifier already carries the human-readable reason.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NotallyColors.background,
      appBar: AppBar(
        backgroundColor: NotallyColors.background,
        elevation: 0,
        title: const Text('Sync', style: TextStyle(color: NotallyColors.textBright)),
        iconTheme: const IconThemeData(color: NotallyColors.textPrimary),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _StatusBanner(service: widget.service),
            const SizedBox(height: 20),
            _field(_url, 'Server URL', hint: 'http://<home-server>:8787'),
            const SizedBox(height: 14),
            _field(_token, 'Bearer token',
                hint: 'from the server’s data/token file'),
            const SizedBox(height: 14),
            _field(
              _pass,
              'Passphrase',
              hint: 'unlocks your encrypted notes',
              obscure: _obscure,
              trailing: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
                    color: NotallyColors.textFaint, size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'The passphrase never leaves this device — the server only stores '
              'ciphertext. Use the same passphrase on every device.',
              style: TextStyle(color: NotallyColors.textFaint, fontSize: 12),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _connect,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: _busy
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Connect & sync'),
              ),
            ),
            const SizedBox(height: 16),
            _ConflictsLink(service: widget.service),
            const SizedBox(height: 32),
            const _VersionLabel(),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? hint,
    bool obscure = false,
    Widget? trailing,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      style: const TextStyle(color: NotallyColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: NotallyColors.textMuted),
        hintText: hint,
        hintStyle: const TextStyle(color: NotallyColors.textFaint),
        suffixIcon: trailing,
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: NotallyColors.border),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: NotallyColors.accent),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.service});
  final SyncService service;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: service.status,
      builder: (_, s, __) => ValueListenableBuilder<int>(
        valueListenable: service.pending,
        builder: (_, pending, __) {
          final (icon, color, text) = _describe(s);
          final details = _details(s, pending);
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: NotallyColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: NotallyColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(text,
                          style: const TextStyle(
                              color: NotallyColors.textPrimary, fontSize: 14)),
                      if (details.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(details.join('\n'),
                              style: const TextStyle(
                                  color: NotallyColors.textFaint,
                                  fontSize: 12,
                                  height: 1.5)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  (IconData, Color, String) _describe(SyncStatus s) {
    switch (s.state) {
      case SyncState.notConfigured:
        return (Icons.cloud_off, NotallyColors.textFaint, 'Not connected yet.');
      case SyncState.locked:
        return (Icons.lock_outline, NotallyColors.accent,
            'Locked — enter your passphrase to sync.');
      case SyncState.syncing:
        return (Icons.sync, NotallyColors.accent, s.message ?? 'Syncing…');
      case SyncState.ok:
        return (Icons.cloud_done, const Color(0xFF4CAF50), 'Up to date');
      case SyncState.offline:
        return (Icons.cloud_off, NotallyColors.textMuted,
            'Offline — can’t reach the server. Your notes are safe on this '
                'device and will sync when it’s back.');
      case SyncState.error:
        return (Icons.error_outline, NotallyColors.accent,
            s.message ?? 'Something went wrong.');
    }
  }

  /// Secondary lines: last-synced time and pending edits.
  static List<String> _details(SyncStatus s, int pending) {
    if (s.state == SyncState.notConfigured || s.state == SyncState.locked) {
      return const [];
    }
    return [
      if (s.state == SyncState.offline && s.message != null) s.message!,
      if (s.lastSyncedAt != null)
        'Last synced ${_ago(s.lastSyncedAt!)}'
      else if (s.state != SyncState.syncing)
        'Not synced yet this session',
      if (pending > 0)
        '$pending change${pending == 1 ? '' : 's'} waiting to sync',
    ];
  }

  static String _ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 30) return 'just now';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

}

class _ConflictsLink extends StatelessWidget {
  const _ConflictsLink({required this.service});
  final SyncService service;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<SyncConflict>>(
      valueListenable: service.conflicts,
      builder: (_, conflicts, __) {
        if (conflicts.isEmpty) return const SizedBox.shrink();
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: NotallyColors.accent,
            side: const BorderSide(color: NotallyColors.accent),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => ConflictsPage(service: service)),
          ),
          icon: const Icon(Icons.merge_type),
          label: Text('Resolve ${conflicts.length} conflict(s)'),
        );
      },
    );
  }
}

/// App version, read from the build itself (pubspec `version:`) so there is
/// no separate constant to keep in sync on release.
class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snap) {
        final info = snap.data;
        if (info == null) return const SizedBox.shrink();
        return Center(
          child: SelectableText(
            'LibreNotes ${info.version} (${info.buildNumber})',
            style: const TextStyle(color: NotallyColors.textFaint, fontSize: 12),
          ),
        );
      },
    );
  }
}
