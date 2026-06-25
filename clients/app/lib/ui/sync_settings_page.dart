import 'package:flutter/material.dart';

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
  final _url = TextEditingController(text: 'http://192.168.100.164:8787');
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
      builder: (_, s, __) {
        final (icon, color, text) = _describe(s);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: NotallyColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: NotallyColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text,
                    style: const TextStyle(
                        color: NotallyColors.textPrimary, fontSize: 14)),
              ),
            ],
          ),
        );
      },
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
        return (Icons.cloud_done, const Color(0xFF4CAF50),
            'Synced${s.lastSyncedAt != null ? ' • ${_time(s.lastSyncedAt!)}' : ''}');
      case SyncState.offline:
        return (Icons.cloud_off, NotallyColors.textMuted,
            'Offline — ${s.message ?? 'server unreachable'}');
      case SyncState.error:
        return (Icons.error_outline, NotallyColors.accent,
            s.message ?? 'Something went wrong.');
    }
  }

  static String _time(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.hour)}:${two(d.minute)}';
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
