import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:librenotes/sync/note_crypto.dart';

// The vectors documented in PROTOCOL.md. If this fails, update the doc.
Uint8List unhex(String s) => Uint8List.fromList(
    [for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16)]);

void main() {
  const wrapped =
      '404142434445464748494a4b4c4d4e4f5051525354555657fe63fad0b9f2f83416d3f00c1b96bfb585cea535246d7d2d7a5ab1fa01601af4bb57eb4d881f1dc1c1f86d168f3366f3';
  const ciphertext =
      '9305344ff11dfee39023dd6a7ecd40bb5bcece7a0d9cfb5c4275568856f1a0ab01e1147f4fd540007cde4602b4d12a70b58165402ff057d13d7289970aece1b227805afd6967b67f481d7f41127835de4540a69fc3bd6fd59ea27398b24da35e9ee89afc87fde8adc54d6569b22325659bf1324b5e49cc113af241315ffaaa22eb9515d4561aa4411e40fff77dddcbdb01eb850d5c0dc99fd4fe3b4d30b38a5133777905f0c7eb';

  test('PROTOCOL.md vectors: unwrap the DEK, then decrypt the note', () async {
    final crypto = await NoteCrypto.unlock(
      'correct horse battery staple',
      unhex(wrapped),
      Uint8List.fromList(List.generate(16, (i) => i)),
      const KdfParams(), // 19456 KiB, t=2, p=1
    );
    expect(await crypto.extractDekBytes(), List.generate(32, (i) => 0x20 + i));

    final p = await crypto.decrypt(
        unhex(ciphertext), Uint8List.fromList(List.generate(24, (i) => 0x60 + i)));
    expect(p['title'], 'Hello');
    expect(p['body'], 'World');
    expect(p['createdAt'], 1700000000000);
  });
}
