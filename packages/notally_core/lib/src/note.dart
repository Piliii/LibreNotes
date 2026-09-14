/// The plaintext note, used only on the client side.
///
/// Fields mirror the original prototype (`title`, `body`, `pinned`, `color`,
/// timestamps) plus the sync metadata each device caches locally. Before
/// upload, clients encrypt [toPayload] into [EncryptedNote.ciphertext]; the
/// sync metadata ([id], [rev], [seq], [deleted]) travels in the clear because
/// the server needs it.
class Note {
  final String id; // UUID
  String title;
  String body; // markdown
  bool pinned;
  String color; // hex, e.g. "#2a2a2a"
  int createdAt; // ms since epoch
  int updatedAt; // ms since epoch

  /// Optional self-destruct timestamp (ms since epoch). When set and in the
  /// past, the client tombstones the note the same way a manual trash delete
  /// does. Lives in the encrypted payload, like [pinned]/[color]/[archived].
  int? expiresAt;

  // Sync metadata cached from the server.
  int rev;
  int seq;
  bool deleted;

  Note({
    required this.id,
    this.title = '',
    this.body = '',
    this.pinned = false,
    this.color = '#2a2a2a',
    required this.createdAt,
    required this.updatedAt,
    this.expiresAt,
    this.rev = 0,
    this.seq = 0,
    this.deleted = false,
  });

  /// The plaintext payload that gets encrypted. Only user content lives here;
  /// sync metadata stays outside so the server can route it.
  Map<String, dynamic> toPayload() => {
    'title': title,
    'body': body,
    'pinned': pinned,
    'color': color,
    'createdAt': createdAt,
    'expiresAt': expiresAt,
  };

  factory Note.fromPayload(
    Map<String, dynamic> p, {
    required String id,
    required int rev,
    required int seq,
    required bool deleted,
    required int updatedAt,
  }) => Note(
    id: id,
    title: p['title'] as String? ?? '',
    body: p['body'] as String? ?? '',
    pinned: p['pinned'] as bool? ?? false,
    color: p['color'] as String? ?? '#2a2a2a',
    createdAt: p['createdAt'] as int? ?? updatedAt,
    updatedAt: updatedAt,
    expiresAt: p['expiresAt'] as int?,
    rev: rev,
    seq: seq,
    deleted: deleted,
  );
}
