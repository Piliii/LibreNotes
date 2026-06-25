/// Shared models and sync DTOs for Notally.
///
/// This package is the single source of truth for the wire format used between
/// the Flutter clients and the Dart sync server. It is deliberately free of
/// third-party dependencies and crypto: the server is end-to-end-encryption
/// *blind* (it only ever sees ciphertext), and the plaintext model lives here
/// only so clients can reuse it.
library;

export 'src/encrypted_note.dart';
export 'src/note.dart';
export 'src/sync.dart';
