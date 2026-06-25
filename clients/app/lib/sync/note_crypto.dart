import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Argon2id cost parameters. Defaults follow OWASP's Argon2id guidance
/// (m=19 MiB, t=2, p=1) — comfortable on phones, still strong.
class KdfParams {
  final int memory; // KiB
  final int iterations;
  final int parallelism;

  const KdfParams({
    this.memory = 19456,
    this.iterations = 2,
    this.parallelism = 1,
  });
}

/// Client-side end-to-end encryption for note payloads.
///
/// A random 256-bit **DEK** encrypts each note (XChaCha20-Poly1305, fresh nonce
/// per write). The DEK is **wrapped** by a key derived from the user's
/// passphrase via Argon2id; only the wrapped DEK + salt leave the device (into
/// the server keystore). The server never sees a key or any plaintext.
class NoteCrypto {
  NoteCrypto._(this._dek);

  final SecretKey _dek;

  static final _aead = Xchacha20.poly1305Aead();
  static const _nonceLen = 24; // XChaCha20 nonce
  static const _macLen = 16; // Poly1305 tag

  static List<int> _randomBytes(int n) {
    final rng = Random.secure();
    return List<int>.generate(n, (_) => rng.nextInt(256));
  }

  static Future<SecretKey> _deriveKek(
    String passphrase,
    List<int> salt,
    KdfParams p,
  ) {
    final kdf = Argon2id(
      memory: p.memory,
      iterations: p.iterations,
      parallelism: p.parallelism,
      hashLength: 32,
    );
    return kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }

  /// First-time setup: generate a fresh DEK and wrap it for the keystore.
  static Future<({Uint8List wrappedDek, Uint8List salt, NoteCrypto crypto})>
      create(String passphrase, {KdfParams params = const KdfParams()}) async {
    final salt = Uint8List.fromList(_randomBytes(16));
    final kek = await _deriveKek(passphrase, salt, params);
    final dek = await _aead.newSecretKey();

    final dekBytes = await dek.extractBytes();
    final box = await _aead.encrypt(
      dekBytes,
      secretKey: kek,
      nonce: _aead.newNonce(),
    );
    return (
      wrappedDek: Uint8List.fromList(box.concatenation()),
      salt: salt,
      crypto: NoteCrypto._(dek),
    );
  }

  /// Unlock an existing keystore (new device, or re-entering the passphrase).
  /// Throws [SecretBoxAuthenticationError] if the passphrase is wrong.
  static Future<NoteCrypto> unlock(
    String passphrase,
    Uint8List wrappedDek,
    Uint8List salt,
    KdfParams params,
  ) async {
    final kek = await _deriveKek(passphrase, salt, params);
    final box = SecretBox.fromConcatenation(
      wrappedDek,
      nonceLength: _nonceLen,
      macLength: _macLen,
    );
    final dekBytes = await _aead.decrypt(box, secretKey: kek);
    return NoteCrypto._(SecretKey(dekBytes));
  }

  /// Encrypts a note payload. Returns ciphertext (cipher+tag) and the nonce,
  /// matching the server's [EncryptedNote] shape.
  Future<({Uint8List ciphertext, Uint8List nonce})> encrypt(
    Map<String, dynamic> payload,
  ) async {
    final nonce = _aead.newNonce();
    final box = await _aead.encrypt(
      utf8.encode(jsonEncode(payload)),
      secretKey: _dek,
      nonce: nonce,
    );
    return (
      ciphertext: Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
      nonce: Uint8List.fromList(nonce),
    );
  }

  Future<Map<String, dynamic>> decrypt(
    Uint8List ciphertext,
    Uint8List nonce,
  ) async {
    final split = ciphertext.length - _macLen;
    final box = SecretBox(
      ciphertext.sublist(0, split),
      nonce: nonce,
      mac: Mac(ciphertext.sublist(split)),
    );
    final clear = await _aead.decrypt(box, secretKey: _dek);
    return jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
  }
}
