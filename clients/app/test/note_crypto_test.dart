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

  test('wrong passphrase fails to unlock', () async {
    final setup = await NoteCrypto.create('right', params: fast);
    expect(
      () => NoteCrypto.unlock('wrong', setup.wrappedDek, setup.salt, fast),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });
}
