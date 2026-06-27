# LibreNotes

Personal, cross-device note-taking app with a **self-hosted sync server**. One
user (the owner), many devices. Privacy-first: the server is end-to-end-
encryption-blind and lives on a home LAN, never the public internet.

App name: **LibreNotes**. Android package ID: `dev.librenotes.app`.  
Internal Dart package names are still `notally_core` / `notally_server` — don't
rename those, they're just library identifiers.

## Product shape

- **Clients (all Flutter/Dart, one codebase):** website, native Linux desktop,
  native Android. **No Windows, no Electron** (the owner refuses Electron on
  privacy grounds — don't propose it).
- **Notes:** markdown text. Desktop = notes list on the left, editor on the
  right. Mobile = 2-up grid of cards (title + truncated preview ending in "…").
- **Design DNA** (from the original prototype): dark theme (`#1a1a1a` /
  `#242424`), **orange accent `#ff6900`**, resizable sidebar, ~500 ms debounced
  autosave, local cache for instant load.
- **Offline-first:** every client has a local store and works fully offline;
  it syncs opportunistically whenever the home server is reachable.

## Sync model (no CRDT)

A global changelog plus per-note revisions:

- Each note has `rev` (bumped per accepted write) and `seq` (global, server-
  assigned, monotonic).
- **Pull:** `GET /changes?since=<seq>` returns everything newer + the new cursor.
- **Push:** client sends `baseRev` (the rev it edited from). If the server's
  note still has that rev → accept and bump; otherwise **409 conflict**,
  returning the server's version. The client shows both and **the user picks
  the winner** (chosen conflict policy — not auto-merge).
- Deletes are tombstones so they propagate.
- Permanent deletes (trash purge) use a `purged` flag that propagates via
  `DELETE /notes/<id>/purge`. The client keeps the row until the server acks,
  then hard-deletes it locally.

## Encryption (E2EE, v1)

The server only ever stores ciphertext.

- A random 256-bit **DEK** encrypts each note payload (`{title, body, pinned,
  color, createdAt}`) with a per-write nonce (AEAD, XChaCha20-Poly1305).
- The DEK is **wrapped** by a key derived from the user's passphrase via
  **Argon2id** (`salt` + KDF params). The wrapped DEK + salt/params live in the
  server `keystore`; the server never sees any key. A new device only needs the
  passphrase to unwrap the DEK.
- Conflict detection still works because it runs on `rev` (plaintext), not
  content. Crypto is **client-side only** — keep it out of the server.

## Remote access

LAN-only today. To sync away from home later, put devices + server on a
**Tailscale/WireGuard** mesh — that's only a client base-URL change, no server
code change. Never expose the server to the WAN.

## Repository layout

```
LibreNotes/
├── assets/icon/             Source app icon (librenotes.jpg)
├── metadata/                F-Droid build recipe (dev.librenotes.app.yml) for fdroiddata PR.
├── packages/notally_core/   Shared Dart models + sync DTOs (app + server).
│                            Dependency-free & crypto-free on purpose.
│   └── lib/src/             encrypted_note.dart, note.dart, sync.dart
├── server/                  Sync server: shelf + sqlite3, E2EE-blind.
│   ├── bin/server.dart      Entry point (env config, token, graceful stop).
│   ├── lib/db.dart          SQLite data layer + conflict logic.
│   ├── lib/api.dart         HTTP routes + bearer-token auth.
│   └── test/db_test.dart    Core sync/conflict tests (in-memory db).
└── clients/app/             Flutter client (desktop + Android + web, one codebase).
    ├── lib/main.dart        Wires AppDatabase → NotesRepository → SyncService → UI.
    ├── lib/data/            Drift local store (database.dart) + notes_repository.dart.
    ├── lib/sync/            sync_service.dart (pull/push loop), sync_api.dart,
    │                        note_crypto.dart (Argon2id + XChaCha20-Poly1305, client-only).
    ├── lib/ui/              home_screen, note_editor, conflicts_page, sync_settings_page,
    │                        trash_page.dart.
    ├── fastlane/            F-Droid metadata (title, description, changelogs).
    └── test/                sync_e2e (real in-process server), note_editor regression, etc.
```

The server is **shelf**, not dart_frog: dependency-light, no global CLI,
`dart compile exe` → one auditable binary for systemd.

## Toolchain

Dart/Flutter is **not on PATH**; it ships in the Flutter SDK. Prefix shells with:

```bash
export PATH="$PATH:/path/to/flutter/bin"
```

## Common commands

```bash
# Server (run from server/)
dart pub get                 # install deps
dart test                    # run the sync/conflict tests
dart run bin/server.dart     # start the server (prints token + bind addr); binds
                             # 0.0.0.0 so LAN devices (e.g. the phone) can reach it

# Client (run from clients/app/)
flutter test                 # repo + sync e2e + editor regression tests
flutter run -d linux         # desktop dev; -d <device> for Android, -d chrome for web
flutter build apk --release --target-platform android-arm64   # release APK (arm64-only)
```

## Licensing & distribution

- **License: AGPLv3** (`LICENSE` at repo root, canonical text) — covers client,
  server, and `notally_core`. AGPL is deliberate: it's a network server app.
- **Android is F-Droid-ready:** all deps are FOSS (drift/sqlite3/cryptography/
  http/uuid/markdown), no Google Play Services / Firebase / trackers, talks only
  to the self-hosted server. Release builds are **arm64-v8a only** (`ndk
  abiFilters` in `android/app/build.gradle.kts`) and ship **release, not debug**.
  The `INTERNET` permission is declared in the *main* manifest (not just debug),
  or release sync silently fails. Release still uses the debug signing config —
  F-Droid re-signs, so fine for F-Droid; set a real keystore for direct APKs.
- **F-Droid status:** submitted. Fastlane metadata + screenshots in
  `clients/app/fastlane/metadata/android/en-US/`, build recipe in
  `metadata/dev.librenotes.app.yml`, MR open at
  `https://gitlab.com/fdroid/fdroiddata/-/merge_requests/41300`.
  Repo is public at `https://github.com/Piliii/LibreNotes`, tagged `v1.0.1`.

## Status / roadmap

1. **Dart sync server + SQLite** — DONE: CRUD, `/changes`, conflict 409s,
   keystore, auth, tests.
2. **Flutter app, local-only** — DONE: Drift store, dark-theme UI (list+editor on
   desktop, card grid on mobile), debounced autosave, offline-first cache.
3. **Wire in sync** — DONE: pull/push loop, client-side E2EE crypto, conflict
   screen. Polls every 10s + nudges ~1.2s after a local edit (no WebSockets).
   Verified end-to-end across desktop ↔ Android; server confirmed content-blind.
4. **Release prep** — DONE: AGPLv3 license, arm64-only release builds, INTERNET
   permission, F-Droid dependency audit (clean).
5. **Trash bin** — DONE: soft-delete tombstones, Trash page with restore +
   permanent delete, empty-trash, purge sync propagated cross-device via
   `purged` flag + `/notes/<id>/purge` server endpoint.
6. **Rename + GitHub/F-Droid prep** — DONE: app renamed to LibreNotes
   (`dev.librenotes.app`), root README, fastlane metadata, icons regenerated,
   F-Droid dependency audit clean.
7. **F-Droid submission** — DONE: screenshots added, build recipe written, MR
   submitted to `fdroid/fdroiddata` (MR #41300). Repo public on GitHub. Current
   release: `v1.1.0`.
8. **UI polish + color picker** — DONE: note color picker implemented; mobile
   UI has had a first polish pass but still needs more work.
9. **Linux distribution** — DONE: AppImage + tarball (attached to GitHub release
   v1.1.0), AUR (`librenotes-bin`) live, Flatpak manifest repo at
   `github.com/Piliii/dev.librenotes.app` (manual install only — not submitted to
   Flathub; Flathub bans AI-assisted code and this project does not qualify).
   Packaging scripts: `scripts/package-linux.sh`, `scripts/package-server.sh`.
10. **Marketing website** — DONE: Next.js + Tailwind static export in `website/`.
    Sections: hero, Android screenshots, features, live demo (React/localStorage),
    download, server setup (3-step), footer. Deployed to Vercel + Cloudflare at
    `https://librenotes.ayopili.com`. Short redirects via `website/vercel.json`
    (`/dl/server`, `/dl/apk`, `/github`). Bunny Fonts, lucide-react + simple-icons,
    react-markdown + remark-gfm + react-syntax-highlighter in the live demo.
11. **TODO — remaining before "good to go":**
    - **Docker server distribution**: add `server/Dockerfile` (debian-slim base,
      copy compiled binary, expose port 7070, volume for `/data`), a
      `docker-compose.yml` at repo root, and a GitHub Actions workflow that builds
      and pushes to GHCR (`ghcr.io/piliii/librenotes-server`) on every release tag.
      Update the website server setup section to show Docker as an alternative to
      the binary install. Image should be tiny (~20 MB on debian-slim).
    - **Linux .deb/.rpm packages**: add `fpm` to `scripts/package-linux.sh` to
      produce `.deb` (Debian/Ubuntu) and `.rpm` (Fedora/openSUSE) from the same
      Flutter bundle. Install to `/opt/librenotes/` + wrapper at `/usr/bin/librenotes`,
      desktop entry, icon, appdata in standard XDG paths. Distribute via GitHub
      releases alongside AppImage + tarball. Dependency: `gtk3`/`libgtk-3-0`.
    - **Seamless re-unlock via platform keyring**: after first passphrase entry,
      store the unwrapped DEK in `flutter_secure_storage` (Android Keystore /
      iOS Keychain / Linux GNOME Keyring). On subsequent app restarts, retrieve
      it silently so the user isn't prompted for their passphrase again on a
      trusted device. Fall back to passphrase if the keyring is unavailable or
      cleared. This is how Bitwarden handles vault key caching.
    - **UI polish** (mobile still needs more work).
    - **Wayland + multi-DE support**: verify the Linux desktop build runs correctly under Wayland (GTK backend), GNOME, KDE, and other compositors. Add `--ozone-platform=wayland` launch flag to the `.desktop` file or wrapper as appropriate.
    - **Version mismatch handling**: gracefully handle mismatched API versions between client and server (e.g. a version header on responses, a human-readable error when the client is too old).
    - Server optional WebSocket push (instead of polling every 10s).
    - **Flathub**: not pursuing — policy bans AI-assisted code.

## Conventions

- Wire format and models are defined **once** in `notally_core` and shared by
  both server and clients. Don't duplicate models — extend the shared package.
- Keep all cryptography on the client. The server must remain content-blind.
- Never commit `server/data/` (holds the db and the auth token).
- Both `clients/app/pubspec.lock` and `server/pubspec.lock` are tracked — keep
  them committed for reproducible builds (F-Droid requirement).
