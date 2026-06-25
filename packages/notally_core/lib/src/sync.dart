import 'dart:convert';
import 'dart:typed_data';

import 'encrypted_note.dart';

/// Response to `GET /changes?since=<seq>`: every note that changed after the
/// client's cursor, plus the new high-water mark to store for next time.
class ChangesResponse {
  final List<EncryptedNote> notes;
  final int latestSeq;

  const ChangesResponse({required this.notes, required this.latestSeq});

  Map<String, dynamic> toJson() => {
    'notes': notes.map((n) => n.toJson()).toList(),
    'latestSeq': latestSeq,
  };

  factory ChangesResponse.fromJson(Map<String, dynamic> j) => ChangesResponse(
    notes: (j['notes'] as List)
        .map((e) => EncryptedNote.fromJson(e as Map<String, dynamic>))
        .toList(),
    latestSeq: j['latestSeq'] as int,
  );
}

/// Body of `PUT /notes/<id>`: the new ciphertext plus the [baseRev] the client
/// started editing from. [baseRev] == 0 means "this is a brand-new note".
class PushRequest {
  final Uint8List ciphertext;
  final Uint8List nonce;
  final int baseRev;

  const PushRequest({
    required this.ciphertext,
    required this.nonce,
    required this.baseRev,
  });

  Map<String, dynamic> toJson() => {
    'ciphertext': base64Encode(ciphertext),
    'nonce': base64Encode(nonce),
    'baseRev': baseRev,
  };

  factory PushRequest.fromJson(Map<String, dynamic> j) => PushRequest(
    ciphertext: base64Decode(j['ciphertext'] as String),
    nonce: base64Decode(j['nonce'] as String),
    baseRev: j['baseRev'] as int,
  );
}

enum PushStatus { applied, conflict }

/// Result of a push. On [PushStatus.applied], [note] is the freshly stored
/// version (new rev/seq). On [PushStatus.conflict] (HTTP 409), [note] is the
/// server's current version — the client shows both and lets the user pick.
class PushResult {
  final PushStatus status;
  final EncryptedNote note;

  const PushResult({required this.status, required this.note});

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'note': note.toJson(),
  };

  factory PushResult.fromJson(Map<String, dynamic> j) => PushResult(
    status: PushStatus.values.byName(j['status'] as String),
    note: EncryptedNote.fromJson(j['note'] as Map<String, dynamic>),
  );
}

/// The encrypted key bundle, stored once on the server. The data-encryption key
/// (DEK) is wrapped by a key derived from the user's passphrase via Argon2id
/// ([salt] + the kdf params). The server stores this opaque blob so a new
/// device only needs the passphrase to unwrap the DEK — the server never sees
/// either key.
class Keystore {
  final Uint8List wrappedDek;
  final Uint8List salt;
  final int kdfMemory; // KiB
  final int kdfIterations;
  final int kdfParallelism;

  const Keystore({
    required this.wrappedDek,
    required this.salt,
    required this.kdfMemory,
    required this.kdfIterations,
    required this.kdfParallelism,
  });

  Map<String, dynamic> toJson() => {
    'wrappedDek': base64Encode(wrappedDek),
    'salt': base64Encode(salt),
    'kdfMemory': kdfMemory,
    'kdfIterations': kdfIterations,
    'kdfParallelism': kdfParallelism,
  };

  factory Keystore.fromJson(Map<String, dynamic> j) => Keystore(
    wrappedDek: base64Decode(j['wrappedDek'] as String),
    salt: base64Decode(j['salt'] as String),
    kdfMemory: j['kdfMemory'] as int,
    kdfIterations: j['kdfIterations'] as int,
    kdfParallelism: j['kdfParallelism'] as int,
  );
}
