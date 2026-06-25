import 'dart:convert';
import 'dart:typed_data';

/// A note as it exists on the wire and at rest on the server.
///
/// The server is E2EE-blind: [ciphertext] holds the encrypted note payload
/// (title, body, pinned, color, createdAt — see [Note.toPayload]) and the
/// server never has the key to read it. Everything else is sync metadata the
/// server needs to do its job:
///
///  * [rev] — per-note revision, bumped on every accepted write. Conflict
///    detection compares the client's base rev against this.
///  * [seq] — global, server-assigned, monotonically increasing change cursor.
///    Clients pull deltas with `GET /changes?since=<seq>`.
///  * [deleted] — tombstone so deletions propagate to other devices.
class EncryptedNote {
  final String id; // UUID, generated client-side so offline creates work.
  final Uint8List ciphertext;
  final Uint8List nonce;
  final int rev;
  final int seq;
  final bool deleted;
  /// True when the user permanently deleted this note from their trash.
  /// Propagates via pull so all devices hard-delete the local row.
  final bool purged;
  final int updatedAt; // ms since epoch, server clock.

  const EncryptedNote({
    required this.id,
    required this.ciphertext,
    required this.nonce,
    required this.rev,
    required this.seq,
    required this.deleted,
    this.purged = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'ciphertext': base64Encode(ciphertext),
    'nonce': base64Encode(nonce),
    'rev': rev,
    'seq': seq,
    'deleted': deleted,
    'purged': purged,
    'updatedAt': updatedAt,
  };

  factory EncryptedNote.fromJson(Map<String, dynamic> j) => EncryptedNote(
    id: j['id'] as String,
    ciphertext: base64Decode(j['ciphertext'] as String),
    nonce: base64Decode(j['nonce'] as String),
    rev: j['rev'] as int,
    seq: j['seq'] as int,
    deleted: j['deleted'] as bool,
    purged: j['purged'] as bool? ?? false,
    updatedAt: j['updatedAt'] as int,
  );
}
