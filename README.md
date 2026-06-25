# LibreNotes

A private, self-hosted, end-to-end encrypted note-taking app. One owner, many
devices. The server stores only ciphertext — it is encryption-blind by design.

**Platforms:** Android (F-Droid-ready), Linux desktop, web  
**License:** AGPLv3

## Features

- Markdown notes with live preview
- Dark theme, orange accent, resizable sidebar
- Offline-first: full local cache, syncs opportunistically
- End-to-end encryption (XChaCha20-Poly1305 + Argon2id key derivation)
- Conflict resolution: server detects stale writes and returns both versions; you pick the winner
- Trash bin with restore and permanent delete
- Self-hosted sync server (Shelf + SQLite, single compiled binary)

## Repository layout

```
packages/notally_core/   Shared Dart models + sync DTOs (app + server)
server/                  Sync server (Shelf + SQLite, E2EE-blind)
clients/app/             Flutter client (Android, Linux desktop, web)
assets/icon/             Source app icon
```

## Quick start

### Server

```bash
cd server
dart pub get
dart run bin/server.dart
```

The server prints a bearer token on first start and binds to `0.0.0.0:8787`.
See [server/README.md](server/README.md) for full configuration and API docs.

### Client

```bash
cd clients/app
flutter pub get
flutter run -d linux          # Linux desktop
flutter run -d chrome         # web
flutter run                   # Android (device/emulator attached)
```

The Flutter SDK must be on PATH:

```bash
export PATH="$PATH:/path/to/flutter/bin"
```

See [clients/app/README.md](clients/app/README.md) for build instructions.

## Remote access

The server is LAN-only by design. For access away from home, join devices and
the server on a Tailscale or WireGuard mesh and update the server URL in the
app — no server code change needed. Never expose the server directly to the WAN.

## Security model

- All encryption and decryption happens on the client. The server never sees
  plaintext, keys, or passphrases.
- Each note is encrypted with a random DEK (XChaCha20-Poly1305, per-write
  nonce). The DEK is wrapped with a key derived from the user's passphrase via
  Argon2id. The wrapped DEK lives on the server; the passphrase never leaves
  the device.
- Conflict detection runs on `rev` (plaintext metadata), not content.

## License

AGPLv3 — see [LICENSE](LICENSE). AGPL is intentional: this is a network server
application.
