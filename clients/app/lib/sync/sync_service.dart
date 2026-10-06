import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart' show SecretBoxAuthenticationError;
import 'package:flutter/foundation.dart';
import 'package:notally_core/notally_core.dart';

import '../data/local_key_manager.dart';
import '../data/notes_repository.dart';
import 'note_crypto.dart';
import 'sync_api.dart';

enum SyncState { notConfigured, locked, syncing, ok, offline, error }

class SyncStatus {
  final SyncState state;
  final String? message;
  final DateTime? lastSyncedAt;
  const SyncStatus(this.state, {this.message, this.lastSyncedAt});
}

/// The server's version of a note that diverged from ours.
class RemoteNote {
  final String title;
  final String body;
  final bool pinned;
  final String color;
  final int createdAt;
  final int updatedAt;
  final int rev;
  final int seq;
  final bool deleted;
  final bool archived;
  final int? expiresAt;
  const RemoteNote({
    required this.title,
    required this.body,
    required this.pinned,
    required this.color,
    required this.createdAt,
    required this.updatedAt,
    required this.rev,
    required this.seq,
    required this.deleted,
    this.archived = false,
    this.expiresAt,
  });
}

/// A note edited on two devices: the user picks which side wins.
class SyncConflict {
  final NoteRow local;
  final RemoteNote remote;
  const SyncConflict(this.local, this.remote);
  String get id => local.id;
}

/// Owns sync end-to-end: keystore bootstrap/unlock, the pull+push round, and
/// conflict bookkeeping. All crypto happens here on the client; the server only
/// ever sees ciphertext.
class SyncService {
  SyncService(this._repo);

  final NotesRepository _repo;

  SyncApi? _api;
  Timer? _auto;
  Timer? _nudge;

  final ValueNotifier<SyncStatus> status =
      ValueNotifier(const SyncStatus(SyncState.notConfigured));
  final ValueNotifier<List<SyncConflict>> conflicts = ValueNotifier(const []);

  /// Local edits not yet accepted by the server (excludes blank never-synced
  /// notes, which are never pushed). Kept current on every edit and sync round.
  final ValueNotifier<int> pending = ValueNotifier(0);

  static const _kBaseUrl = 'baseUrl';
  static const _kToken = 'token';
  static const _kSeq = 'lastSeq';
  static const _kWrapped = 'ks.wrapped';
  static const _kSalt = 'ks.salt';
  static const _kMem = 'ks.mem';
  static const _kIter = 'ks.iter';
  static const _kPar = 'ks.par';

  /// Notes' at-rest DEK is resolved once at app boot (see `LocalKeyManager`),
  /// well before sync exists — so "unlocked" here means "sync is actively
  /// connected", not "crypto is available" (it always is).
  bool get isUnlocked => _api != null;

  /// Called at startup: figure out whether sync is configured, and if so,
  /// resume it using the already-resolved local DEK (see `main.dart`) without
  /// prompting the user for their passphrase.
  ///
  /// [waitForFirstSync] false lets the caller (app startup) proceed without
  /// waiting on the network: the first sync runs in the background and its
  /// outcome lands in [status]. An unreachable server must never hold up the
  /// UI of an offline-first app.
  Future<void> init({bool waitForFirstSync = true}) async {
    final baseUrl = await _repo.kvGet(_kBaseUrl);
    final token = await _repo.kvGet(_kToken);
    final configured = baseUrl != null && await _repo.kvGet(_kWrapped) != null;
    if (!configured) {
      status.value = const SyncStatus(SyncState.notConfigured);
      return;
    }
    if (token == null) {
      status.value = const SyncStatus(SyncState.locked);
      return;
    }
    _api = SyncApi(baseUrl: baseUrl, token: token);
    if (waitForFirstSync) {
      await syncNow();
      _startAuto();
    } else {
      _startAuto();
      unawaited(syncNow());
    }
  }

  Future<String?> get savedBaseUrl => _repo.kvGet(_kBaseUrl);
  Future<String?> get savedToken => _repo.kvGet(_kToken);

  /// Polls the server every 10s once unlocked. Cheap on a LAN; conflicts and
  /// local edits both get reconciled on the next tick.
  void _startAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(const Duration(seconds: 10), (_) {
      if (isUnlocked && status.value.state != SyncState.syncing) syncNow();
    });
  }

  /// Requests a sync shortly after a local edit, so the change reaches other
  /// devices in ~1s instead of waiting out the poll. Debounced so a burst of
  /// keystrokes collapses into one push.
  void nudge() {
    unawaited(refreshPending());
    _nudge?.cancel();
    _nudge = Timer(const Duration(milliseconds: 1200), () {
      if (isUnlocked && status.value.state != SyncState.syncing) syncNow();
    });
  }

  static bool _isBlank(NoteRow n) =>
      n.title.trim().isEmpty && n.body.trim().isEmpty;

  /// Recounts local edits waiting to be pushed.
  Future<void> refreshPending() async {
    final dirty = await _repo.dirtyNotes();
    pending.value =
        dirty.where((n) => !(n.rev == 0 && (n.deleted || _isBlank(n)))).length;
  }

  void dispose() {
    _auto?.cancel();
    _nudge?.cancel();
    _api?.close();
  }

  /// First-time setup or reconfiguration: verify the server, bootstrap or
  /// unlock the keystore, persist config, then run a first sync.
  Future<void> connect({
    required String baseUrl,
    required String token,
    required String passphrase,
  }) async {
    status.value = const SyncStatus(SyncState.syncing, message: 'Connecting…');
    final api = SyncApi(baseUrl: baseUrl, token: token);
    try {
      await api.checkApiVersion();
      var ks = await api.getKeystore();
      if (ks == null) {
        // First device ever: wrap this device's *existing* local DEK (rather
        // than generating a new one) and upload it, so already-encrypted
        // local notes stay valid — nothing needs re-encrypting.
        const params = KdfParams();
        final dekBytes = await _repo.crypto.extractDekBytes();
        final wrapped = await NoteCrypto.wrap(dekBytes, passphrase, params: params);
        ks = Keystore(
          wrappedDek: wrapped.wrappedDek,
          salt: wrapped.salt,
          kdfMemory: params.memory,
          kdfIterations: params.iterations,
          kdfParallelism: params.parallelism,
        );
        await api.putKeystore(ks);
      } else {
        // Existing account (e.g. a second device): the server's DEK may
        // differ from whatever this device generated for itself locally —
        // adopt it, re-encrypting any local notes under the account's key.
        final crypto = await NoteCrypto.unlock(
          passphrase,
          ks.wrappedDek,
          ks.salt,
          KdfParams(
            memory: ks.kdfMemory,
            iterations: ks.kdfIterations,
            parallelism: ks.kdfParallelism,
          ),
        );
        await _repo.adoptCrypto(crypto);
      }
      await _persist(baseUrl, token, ks);
      _api = api;
      unawaited(LocalKeyManager.persist(_repo.crypto));
      await syncNow();
      _startAuto();
    } catch (e) {
      status.value = SyncStatus(SyncState.error, message: _human(e));
      rethrow;
    }
  }

  /// Explicit re-derivation of the account DEK from the passphrase — used to
  /// recover if the local keyring copy was lost or to verify the passphrase
  /// against the locally-cached keystore without a server round-trip.
  Future<void> unlock(String passphrase) async {
    final baseUrl = await _repo.kvGet(_kBaseUrl);
    final token = await _repo.kvGet(_kToken);
    final ks = await _loadLocalKeystore();
    if (baseUrl == null || token == null || ks == null) {
      throw StateError('Not configured');
    }
    final crypto = await NoteCrypto.unlock(
      passphrase,
      ks.wrappedDek,
      ks.salt,
      KdfParams(
        memory: ks.kdfMemory,
        iterations: ks.kdfIterations,
        parallelism: ks.kdfParallelism,
      ),
    );
    await _repo.adoptCrypto(crypto);
    _api = SyncApi(baseUrl: baseUrl, token: token);
    unawaited(LocalKeyManager.persist(_repo.crypto));
    await syncNow();
    _startAuto();
  }

  /// One sync round: pull changes, then push local edits. Divergences land in
  /// [conflicts] for the user to resolve.
  Future<void> syncNow() async {
    final api = _api;
    if (api == null) return;
    final crypto = _repo.crypto;

    // Carried through offline/error states so the UI can say how stale we are.
    final last = status.value.lastSyncedAt;
    status.value =
        SyncStatus(SyncState.syncing, message: 'Syncing…', lastSyncedAt: last);
    try {
      // 1) Pull
      var lastSeq = int.tryParse(await _repo.kvGet(_kSeq) ?? '0') ?? 0;
      final resp = await api.changes(lastSeq);
      for (final note in resp.notes) {
        // Purge beats everything: hard-delete locally regardless of local state.
        if (note.purged) {
          await _repo.purge(note.id);
          continue;
        }

        final local = await _repo.getNote(note.id);
        if (local != null && local.dirty) {
          // We have an unpushed edit based on local.rev. A higher remote rev
          // means another device advanced the note — a real conflict. An equal
          // rev is just our own base coming back (e.g. our prior push, which
          // doesn't move the pull cursor); leave the dirty edit for the push
          // phase to send rather than clobbering it.
          // Exception: if local is pending-purge, let the push phase handle it.
          if (note.rev > local.rev && !local.purged) {
            _putConflict(local, await _toRemote(note, crypto));
          }
        } else {
          await _applyRemote(note, crypto);
        }
      }
      await _repo.kvSet(_kSeq, resp.latestSeq.toString());

      // 2) Push
      for (final note in await _repo.dirtyNotes()) {
        if (_hasConflict(note.id)) continue;

        if (note.purged) {
          // Permanent trash delete: push purge to server (so other devices
          // hard-delete), then hard-delete locally.
          if (note.rev > 0) {
            try {
              await api.purgeNote(note.id);
            } catch (_) {
              // Best-effort: still hard-delete locally even if server call fails.
            }
          }
          await _repo.purge(note.id);
          continue;
        }

        if (note.deleted && note.rev == 0) {
          await _repo.purge(note.id); // never reached the server
          continue;
        }

        if (!note.deleted && note.rev == 0 && _isBlank(note)) {
          // Never-synced blank note (e.g. the auto-opened editor on startup) —
          // don't push it until it actually has content.
          continue;
        }

        final PushResult result;
        if (note.deleted) {
          result = await api.deleteNote(note.id, note.rev);
        } else {
          final enc = await crypto.encrypt(_payloadOf(note));
          result = await api.push(
            note.id,
            PushRequest(
              ciphertext: enc.ciphertext,
              nonce: enc.nonce,
              baseRev: note.rev,
            ),
          );
        }
        if (result.status == PushStatus.applied) {
          await _repo.markSynced(note.id,
              rev: result.note.rev, seq: result.note.seq);
        } else {
          _putConflict(note, await _toRemote(result.note, crypto));
        }
      }

      status.value = SyncStatus(
        conflicts.value.isEmpty ? SyncState.ok : SyncState.error,
        message: conflicts.value.isEmpty
            ? null
            : '${conflicts.value.length} conflict(s) to resolve',
        lastSyncedAt: DateTime.now(),
      );
    } on VersionMismatchException catch (e) {
      status.value = SyncStatus(SyncState.error,
          message: _human(e), lastSyncedAt: status.value.lastSyncedAt);
    } on SyncException catch (e) {
      status.value = SyncStatus(SyncState.error,
          message: _human(e), lastSyncedAt: status.value.lastSyncedAt);
    } catch (e) {
      status.value = SyncStatus(SyncState.offline,
          message: _human(e), lastSyncedAt: status.value.lastSyncedAt);
    } finally {
      await refreshPending();
    }
  }

  // ---- Conflict resolution -------------------------------------------------

  Future<void> keepRemote(String id) async {
    final c = _conflictFor(id);
    if (c == null) return;
    final r = c.remote;
    await _repo.applyRemote(
      id: id,
      title: r.title,
      body: r.body,
      pinned: r.pinned,
      color: r.color,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      rev: r.rev,
      seq: r.seq,
      deleted: r.deleted,
      archived: r.archived,
      expiresAt: r.expiresAt,
    );
    final lastSeq = int.tryParse(await _repo.kvGet(_kSeq) ?? '0') ?? 0;
    if (r.seq > lastSeq) await _repo.kvSet(_kSeq, r.seq.toString());
    _removeConflict(id);
  }

  /// Manual merge: store [title]/[body] as this device's version, then push
  /// it over the server's current rev exactly like [keepLocal].
  Future<void> keepMerged(String id, {required String title, required String body}) async {
    await _repo.updateContent(id, title: title, body: body);
    await keepLocal(id);
  }

  Future<void> keepLocal(String id) async {
    final c = _conflictFor(id);
    final api = _api;
    if (c == null || api == null) return;
    final crypto = _repo.crypto;

    final local = await _repo.getNote(id);
    if (local == null) return;

    // Re-push from the server's current rev so our version wins.
    final PushResult result;
    if (local.deleted) {
      result = await api.deleteNote(id, c.remote.rev);
    } else {
      final enc = await crypto.encrypt(_payloadOf(local));
      result = await api.push(
        id,
        PushRequest(
          ciphertext: enc.ciphertext,
          nonce: enc.nonce,
          baseRev: c.remote.rev,
        ),
      );
    }
    if (result.status == PushStatus.applied) {
      await _repo.markSynced(id, rev: result.note.rev, seq: result.note.seq);
      _removeConflict(id);
    } else {
      // Server moved again; refresh the conflict with the newer remote.
      _putConflict(local, await _toRemote(result.note, crypto));
    }
  }

  // ---- Helpers -------------------------------------------------------------

  Future<void> _applyRemote(EncryptedNote note, NoteCrypto crypto) async {
    if (note.deleted) {
      final existing = await _repo.getNote(note.id);
      // If this note was never on this device, skip the tombstone entirely —
      // there is nothing to tell the user was deleted, and we don't want phantom
      // rows appearing in the local trash.
      if (existing == null) return;
      // Update only sync metadata; preserve local title/body so the trash page
      // can still display the note's content.
      await _repo.applyTombstone(
        note.id,
        rev: note.rev,
        seq: note.seq,
        updatedAt: note.updatedAt,
      );
      return;
    }
    final p = await crypto.decrypt(note.ciphertext, note.nonce);
    await _repo.applyRemote(
      id: note.id,
      title: p['title'] as String? ?? '',
      body: p['body'] as String? ?? '',
      pinned: p['pinned'] as bool? ?? false,
      color: p['color'] as String? ?? '#2a2a2a',
      createdAt: p['createdAt'] as int? ?? note.updatedAt,
      updatedAt: p['updatedAt'] as int? ?? note.updatedAt,
      rev: note.rev,
      seq: note.seq,
      deleted: false,
      archived: p['archived'] as bool? ?? false,
      expiresAt: p['expiresAt'] as int?,
    );
  }

  Future<RemoteNote> _toRemote(EncryptedNote note, NoteCrypto crypto) async {
    if (note.deleted) {
      return RemoteNote(
        title: '',
        body: '',
        pinned: false,
        color: '#2a2a2a',
        createdAt: note.updatedAt,
        updatedAt: note.updatedAt,
        rev: note.rev,
        seq: note.seq,
        deleted: true,
      );
    }
    final p = await crypto.decrypt(note.ciphertext, note.nonce);
    return RemoteNote(
      title: p['title'] as String? ?? '',
      body: p['body'] as String? ?? '',
      pinned: p['pinned'] as bool? ?? false,
      color: p['color'] as String? ?? '#2a2a2a',
      createdAt: p['createdAt'] as int? ?? note.updatedAt,
      updatedAt: p['updatedAt'] as int? ?? note.updatedAt,
      rev: note.rev,
      seq: note.seq,
      deleted: false,
      archived: p['archived'] as bool? ?? false,
      expiresAt: p['expiresAt'] as int?,
    );
  }

  Map<String, dynamic> _payloadOf(NoteRow n) => {
        'title': n.title,
        'body': n.body,
        'pinned': n.pinned,
        'color': n.color,
        'createdAt': n.createdAt,
        'updatedAt': n.updatedAt,
        'archived': n.archived,
        'expiresAt': n.expiresAt,
      };

  bool _hasConflict(String id) => conflicts.value.any((c) => c.id == id);

  SyncConflict? _conflictFor(String id) {
    for (final c in conflicts.value) {
      if (c.id == id) return c;
    }
    return null;
  }

  void _putConflict(NoteRow local, RemoteNote remote) {
    final next = [
      ...conflicts.value.where((c) => c.id != local.id),
      SyncConflict(local, remote),
    ];
    conflicts.value = next;
  }

  void _removeConflict(String id) {
    conflicts.value = conflicts.value.where((c) => c.id != id).toList();
    unawaited(refreshPending());
    if (conflicts.value.isEmpty && status.value.state == SyncState.error) {
      status.value = SyncStatus(SyncState.ok,
          lastSyncedAt: status.value.lastSyncedAt);
    }
  }

  Future<void> _persist(String baseUrl, String token, Keystore ks) async {
    await _repo.kvSet(_kBaseUrl, baseUrl);
    await _repo.kvSet(_kToken, token);
    await _repo.kvSet(_kWrapped, base64Encode(ks.wrappedDek));
    await _repo.kvSet(_kSalt, base64Encode(ks.salt));
    await _repo.kvSet(_kMem, ks.kdfMemory.toString());
    await _repo.kvSet(_kIter, ks.kdfIterations.toString());
    await _repo.kvSet(_kPar, ks.kdfParallelism.toString());
  }

  Future<Keystore?> _loadLocalKeystore() async {
    final wrapped = await _repo.kvGet(_kWrapped);
    final salt = await _repo.kvGet(_kSalt);
    if (wrapped == null || salt == null) return null;
    return Keystore(
      wrappedDek: Uint8List.fromList(base64Decode(wrapped)),
      salt: Uint8List.fromList(base64Decode(salt)),
      kdfMemory: int.parse(await _repo.kvGet(_kMem) ?? '19456'),
      kdfIterations: int.parse(await _repo.kvGet(_kIter) ?? '2'),
      kdfParallelism: int.parse(await _repo.kvGet(_kPar) ?? '1'),
    );
  }

  String _human(Object e) {
    if (e is SecretBoxAuthenticationError) return 'Wrong passphrase';
    if (e is VersionMismatchException) {
      return 'Server API v${e.serverVersion} requires a newer version of LibreNotes. Please update the app.';
    }
    final s = e.toString();
    return s.length > 140 ? '${s.substring(0, 140)}…' : s;
  }
}
