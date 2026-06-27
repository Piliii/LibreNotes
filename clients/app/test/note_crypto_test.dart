import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:librenotes/sync/note_crypto.dart';

void main() {
  // Fast params so the test isn't slow; production uses the OWASP defaults.
  const fast = KdfParams(memory: 1024, iterations: 1, parallelism: 1);

  test('encrypt → decrypt round-trips a payload', () async {
    final setup = await NoteCrypto.create('correct horse', params: fast);
    final payload = {'title': 'Hi', 'body': '# heading\n**bold**', 'pinned': true};

    final enc = await setup.crypto.encrypt(payload);
    final dec = await setup.crypto.decrypt(enc.ciphertext, enc.nonce);

    expect(dec, payload);
    // Ciphertext must not leak plaintext.
    expect(String.fromCharCodes(enc.ciphertext).contains('heading'), isFalse);
  });

  test('a second device unlocks with the same passphrase', () async {
    final setup = await NoteCrypto.create('s3cret', params: fast);
    final enc = await setup.crypto.encrypt({'body': 'across devices'});

    // Simulate a new device: only the wrapped DEK + salt travel via the server.
    final device2 =
        await NoteCrypto.unlock('s3cret', setup.wrappedDek, setup.salt, fast);
    final dec = await device2.decrypt(enc.ciphertext, enc.nonce);

    expect(dec['body'], 'across devices');
  });

  test('fromDek re-creates a working crypto from extracted DEK bytes', () async {
    final setup = await NoteCrypto.create('passphrase', params: fast);
    final payload = {'title': 'Secret', 'body': 'keyring path'};
    final enc = await setup.crypto.encrypt(payload);

    // Simulate what the keyring does: extract raw bytes, store them, restore.
    final dekBytes = await setup.crypto.extractDekBytes();
    final restored = NoteCrypto.fromDek(dekBytes);

    // The restored instance must decrypt what the original encrypted.
    final dec = await restored.decrypt(enc.ciphertext, enc.nonce);
    expect(dec, payload);

    // And vice-versa: the original must decrypt what the restored encrypted.
    final enc2 = await restored.encrypt({'body': 'round-trip'});
    final dec2 = await setup.crypto.decrypt(enc2.ciphertext, enc2.nonce);
    expect(dec2['body'], 'round-trip');
  });

  test('wrong passphrase fails to unlock', () async {
    final setup = await NoteCrypto.create('right', params: fast);
    expect(
      () => NoteCrypto.unlock('wrong', setup.wrappedDek, setup.salt, fast),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
