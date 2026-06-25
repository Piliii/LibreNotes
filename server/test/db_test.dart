import 'dart:typed_data';

import 'package:notally_core/notally_core.dart';
import 'package:notally_server/db.dart';
import 'package:test/test.dart';

Uint8List _bytes(String s) => Uint8List.fromList(s.codeUnits);

void main() {
  late NotesDb db;

  setUp(() => db = NotesDb.open(':memory:'));
  tearDown(() => db.close());

  test('create assigns rev 1 and seq 1', () {
    final r = db.push('n1', _bytes('cipher'), _bytes('nonce'), 0);
    expect(r.status, PushStatus.applied);
    expect(r.note.rev, 1);
    expect(r.note.seq, 1);
    expect(r.note.deleted, isFalse);
  });

  test('update with correct baseRev bumps rev and seq', () {
    db.push('n1', _bytes('a'), _bytes('x'), 0);
    final r = db.push('n1', _bytes('b'), _bytes('y'), 1);
    expect(r.status, PushStatus.applied);
    expect(r.note.rev, 2);
    expect(r.note.seq, 2);
  });

  test('stale baseRev is a conflict and returns the server version', () {
    db.push('n1', _bytes('a'), _bytes('x'), 0); // rev 1
    db.push('n1', _bytes('b'), _bytes('y'), 1); // rev 2 (e.g. from phone)

    final r = db.push('n1', _bytes('c'), _bytes('z'), 1); // laptop, stale
    expect(r.status, PushStatus.conflict);
    expect(r.note.rev, 2);
    expect(r.note.ciphertext, _bytes('b')); // server kept its version
  });

  test('changesSince returns only newer notes', () {
    db.push('a', _bytes('1'), _bytes('n'), 0); // seq 1
    db.push('b', _bytes('2'), _bytes('n'), 0); // seq 2

    expect(db.changesSince(0).map((n) => n.id), ['a', 'b']);
    expect(db.changesSince(1).map((n) => n.id), ['b']);
    expect(db.changesSince(2), isEmpty);
    expect(db.latestSeq(), 2);
  });

  test('tombstone marks deleted and clears ciphertext', () {
    db.push('n1', _bytes('secret'), _bytes('x'), 0); // rev 1
    final r = db.tombstone('n1', 1);
    expect(r.status, PushStatus.applied);
    expect(r.note.deleted, isTrue);
    expect(r.note.ciphertext, isEmpty);
    expect(db.changesSince(1).single.deleted, isTrue);
  });

  test('keystore round-trips', () {
    expect(db.getKeystore(), isNull);
    final ks = Keystore(
      wrappedDek: _bytes('wrapped'),
      salt: _bytes('salt'),
      kdfMemory: 65536,
      kdfIterations: 3,
      kdfParallelism: 1,
    );
    db.setKeystore(ks);
    final got = db.getKeystore()!;
    expect(got.wrappedDek, _bytes('wrapped'));
    expect(got.kdfMemory, 65536);
    expect(got.kdfIterations, 3);
  });
}
