import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/database.dart';
import '../data/local_key_manager.dart';
import '../sync/note_crypto.dart';

typedef _LocalKeystore = ({
  Uint8List wrappedDek,
  Uint8List salt,
  int mem,
  int iter,
  int par,
});

/// Shown at startup instead of the normal app when the platform keyring
/// can't supply the local at-rest DEK (see [LocalKeyManager.resolve]) — e.g.
/// it was cleared outside the app. Notes on disk are still safely encrypted;
/// this screen is the only way back in.
///
/// If sync was ever configured on this device, the user's passphrase can
/// re-derive the same DEK from the locally-cached wrapped keystore (no
/// network round-trip needed). Otherwise there is no passphrase to recover
/// with, and the only way forward is an explicit, confirmed local reset.
class LockedRecoveryScreen extends StatefulWidget {
  const LockedRecoveryScreen({
    super.key,
    required this.db,
    required this.onRecovered,
  });

  final AppDatabase db;
  final ValueChanged<NoteCrypto> onRecovered;

  @override
  State<LockedRecoveryScreen> createState() => _LockedRecoveryScreenState();
}

class _LockedRecoveryScreenState extends State<LockedRecoveryScreen> {
  final _pass = TextEditingController();
  Future<_LocalKeystore?>? _keystore;
  String? _error;
  bool _busy = false;
  bool _confirmingReset = false;

  @override
  void initState() {
    super.initState();
    _keystore = _readKeystore();
  }

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  Future<String?> _kv(String key) async {
    final row = await (widget.db.select(widget.db.syncKv)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<_LocalKeystore?> _readKeystore() async {
    final wrapped = await _kv('ks.wrapped');
    final salt = await _kv('ks.salt');
    if (wrapped == null || salt == null) return null;
    return (
      wrappedDek: base64Decode(wrapped),
      salt: base64Decode(salt),
      mem: int.parse(await _kv('ks.mem') ?? '19456'),
      iter: int.parse(await _kv('ks.iter') ?? '2'),
      par: int.parse(await _kv('ks.par') ?? '1'),
    );
  }

  Future<void> _tryUnlock(_LocalKeystore ks) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final crypto = await NoteCrypto.unlock(
        _pass.text,
        ks.wrappedDek,
        ks.salt,
        KdfParams(memory: ks.mem, iterations: ks.iter, parallelism: ks.par),
      );
      await LocalKeyManager.persist(crypto);
      widget.onRecovered(crypto);
    } catch (_) {
      setState(() => _error = 'Wrong passphrase.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetLocalData() async {
    setState(() => _busy = true);
    await widget.db.delete(widget.db.notes).go();
    await widget.db.delete(widget.db.syncKv).go();
    final crypto = await NoteCrypto.generateLocal();
    await LocalKeyManager.persist(crypto);
    widget.onRecovered(crypto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff1a1a1a),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: FutureBuilder<_LocalKeystore?>(
              future: _keystore,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xffff6900)),
                  );
                }
                final ks = snapshot.data;
                return ks != null ? _passphraseView(ks) : _deadEndView();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _passphraseView(_LocalKeystore ks) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_outline, color: Color(0xffff6900), size: 40),
        const SizedBox(height: 16),
        const Text(
          "Couldn't read the local encryption key",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your notes are still safely encrypted on disk. The system keyring '
          "that normally unlocks them automatically is unavailable — enter "
          'your sync passphrase to unlock them again on this device.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _pass,
          obscureText: true,
          style: const TextStyle(color: Colors.white),
          onSubmitted: (_) => _busy ? null : _tryUnlock(ks),
          decoration: InputDecoration(
            labelText: 'Passphrase',
            labelStyle: const TextStyle(color: Colors.white54),
            errorText: _error,
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: Color(0xffff6900)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : () => _tryUnlock(ks),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xffff6900)),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Unlock'),
        ),
      ],
    );
  }

  Widget _deadEndView() {
    if (_confirmingReset) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This permanently erases every local note. There is no passphrase '
            'to recover them with since sync was never set up on this device. '
            'Are you sure?',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _resetLocalData,
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            child: const Text('Erase local notes and start over'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _confirmingReset = false),
            child: const Text('Cancel'),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_outline, color: Color(0xffff6900), size: 40),
        const SizedBox(height: 16),
        const Text(
          "Couldn't read the local encryption key",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Your notes are still safely encrypted on disk, but the system '
          "keyring that protects them is unavailable and there's no sync "
          'passphrase on this device to recover with. This usually means the '
          "keyring was reset outside the app. If it comes back, reopen the "
          'app and your notes will be readable again.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: _busy ? null : () => setState(() => _confirmingReset = true),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red.shade300),
          child: const Text('Erase local notes and start over'),
        ),
      ],
    );
  }
}
