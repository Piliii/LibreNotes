import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../sync/note_crypto.dart';
import 'database.dart';

/// Thrown when the local at-rest DEK can't be read from the platform keyring
/// and there is already encrypted content on disk that a freshly generated
/// DEK would permanently orphan (it can never decrypt ciphertext written
/// under a different key).
class LocalKeyStorageException implements Exception {
  final String message;
  const LocalKeyStorageException(this.message);
  @override
  String toString() => message;
}

/// Owns the single raw DEK persisted in the platform keyring that protects
/// notes at rest locally. Once sync is configured, this is the *same* DEK
/// wrapped into the server keystore — local and remote ciphertext share one
/// key, so connecting sync never requires re-encrypting existing local notes
/// (see [NoteCrypto.wrap]).
class LocalKeyManager {
  LocalKeyManager._();

  static const _storage = FlutterSecureStorage();
  static const kRawDek = 'ks.rawDek';

  /// Read-or-generate: always safe to call, because it's only ever used where
  /// nothing is at risk of being orphaned — during database creation (empty
  /// table) or while migrating a legacy plaintext table to ciphertext for the
  /// first time (nothing was encrypted under a lost key yet).
  static Future<NoteCrypto> ensure() async {
    final existing = await _read();
    if (existing != null) return NoteCrypto.fromDek(existing);
    final crypto = await NoteCrypto.generateLocal();
    await persist(crypto);
    return crypto;
  }

  /// Steady-state boot resolution. The keyring should already hold a DEK by
  /// this point (guaranteed by [ensure] having run during this same database's
  /// creation/migration). If it's missing and the notes table is non-empty,
  /// this is the platform keyring having been cleared or become unreadable
  /// out from under already-encrypted notes — refuses to silently mint a new,
  /// unrelated DEK (which would just make every note fail to decrypt).
  /// Callers should offer passphrase-based recovery (if sync is configured)
  /// or an explicit reset.
  static Future<NoteCrypto> resolve(AppDatabase db) async {
    final existing = await _read();
    if (existing != null) return NoteCrypto.fromDek(existing);

    final hasContent = await db.notesRowCount() > 0;
    if (hasContent) {
      throw const LocalKeyStorageException(
        "Couldn't read the local encryption key from the system keyring. "
        'Your notes are still safely encrypted on disk, but they cannot be '
        'opened until keyring access is restored.',
      );
    }
    final crypto = await NoteCrypto.generateLocal();
    await persist(crypto);
    return crypto;
  }

  /// Reads the raw DEK bytes, if any. Treats a keyring that can't be reached
  /// at all (no platform channel, transient OS error) the same as "empty" —
  /// callers already handle "empty" safely (never orphaning existing
  /// ciphertext), so collapsing the two cases avoids a crash on top of an
  /// already-degraded keyring.
  static Future<List<int>?> _read() async {
    try {
      final existing = await _storage.read(key: kRawDek);
      return existing == null ? null : base64Decode(existing);
    } catch (_) {
      return null;
    }
  }

  /// Best-effort: a failed write just means the next boot will need
  /// passphrase-based recovery (or, for local-only use, will find nothing to
  /// orphan and generate fresh) rather than crashing whatever operation
  /// triggered the persist.
  static Future<void> persist(NoteCrypto crypto) async {
    try {
      final dekBytes = await crypto.extractDekBytes();
      await _storage.write(key: kRawDek, value: base64Encode(dekBytes));
    } catch (_) {
      // Keyring unavailable — no-op.
    }
  }
}
