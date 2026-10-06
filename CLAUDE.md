# LibreNotes

Personal, cross-device note-taking app with a **self-hosted sync server**. One
user (the owner), many devices. Privacy-first: the server is end-to-end-
encryption-blind and lives on a home LAN, never the public internet.

App name: **LibreNotes**. Android package ID: `dev.librenotes.app`.  
Internal Dart package names are still `notally_core` / `notally_server` — don't
rename those, they're just library identifiers.

## Product shape

- **Clients (all Flutter/Dart, one codebase):** website, native Linux desktop,
  native Android. **No Electron** (the owner refuses Electron on privacy
  grounds — don't propose it). Native Windows desktop support is in progress (see
  `clients/app/windows/`) — Flutter's Windows target is a native Win32 build, not
  Electron, so it doesn't conflict with that rule.
- **Notes:** markdown text. Desktop = notes list on the left, editor on the
  right. Mobile = staggered 2-column masonry grid of cards (body preview only
  when no title; title + body when title exists, variable height).
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
  color, createdAt, archived}`) with a per-write nonce (AEAD, XChaCha20-Poly1305).
  The `archived` field lives entirely in the ciphertext — the server never sees
  archive state.
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
├── assets/icon/             Source app icon (librenotes.jpg — squircle PNG, 457×457)
├── metadata/                F-Droid build recipe (dev.librenotes.app.yml) for fdroiddata PR.
├── packages/notally_core/   Shared Dart models + sync DTOs (app + server).
│                            Dependency-free & crypto-free on purpose.
│   └── lib/src/             encrypted_note.dart, note.dart, sync.dart
├── server/                  Sync server: shelf + sqlite3, E2EE-blind.
│   ├── bin/server.dart      Entry point (env config, token, graceful stop).
│   ├── lib/db.dart          SQLite data layer + conflict logic.
│   ├── lib/api.dart         HTTP routes + bearer-token auth.
│   ├── test/db_test.dart    Core sync/conflict tests (in-memory db).
│   └── Dockerfile           Server image (published to GHCR by docker.yml).
├── scripts/                 package-linux.sh (AppImage + tarball, then calls
│                            package-linux-deb-rpm.sh for .deb/.rpm via fpm),
│                            package-server.sh (server tarball + install.sh/backup.sh),
│                            bump-version.sh.
├── website/                 Next.js + Tailwind static export (marketing site, changelog
│                            page, live demo); deployed via Vercel, redirects in vercel.json.
├── .github/                 workflows/ (ci.yml: analyze + tests on push/PR; release.yml:
│                            tag-push + manual-dispatch release build; docker.yml),
│                            ISSUE_TEMPLATE/.
├── docker-compose.yml       Server deployment.
├── HISTORY.md               Completed-work log (numbered items), split out of this file.
├── CHANGELOG.md, CONTRIBUTING.md, SECURITY.md, CODE_OF_CONDUCT.md, LICENSE, README.md
└── clients/app/             Flutter client (desktop + Android + web, one codebase).
    ├── lib/main.dart        Wires AppDatabase → NotesRepository → SyncService → UI.
    ├── lib/data/            Drift local store (database.dart), notes_repository.dart
    │                        (the plaintext/ciphertext boundary), local_key_manager.dart.
    ├── lib/sync/            sync_service.dart (pull/push loop), sync_api.dart,
    │                        note_crypto.dart (Argon2id + XChaCha20-Poly1305, client-only).
    ├── lib/ui/              home_screen, note_editor, conflicts_page, sync_settings_page,
    │                        archive_page, trash_page, import_export_page,
    │                        locked_recovery_screen, outdated_app_screen, loading_screen.
    ├── lib/desktop/         quick_capture.dart (global hotkey, Linux).
    ├── lib/android/         share_intent.dart (share-sheet target).
    ├── lib/                 theme.dart, format.dart, markdown_editing_controller.dart,
    │                        markdown_format.dart, markdown_highlight.dart.
    ├── fastlane/            F-Droid metadata (title, description, changelogs).
    └── test/                sync_e2e (real in-process server), note_editor regression,
                             repository/crypto/format tests, database_downgrade_guard,
                             sync_api_version.
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
  or release sync silently fails. Release builds are signed with a real,
  persisted keystore when `android/key.properties` exists (GitHub Release CI
  decodes it from the `ANDROID_KEYSTORE_BASE64` secret — see HISTORY.md item 26); without
  it (F-Droid's from-source build, or a contributor without the key) the build
  falls back to the debug signing config. That fallback is harmless for
  F-Droid itself, since F-Droid always builds from source and re-signs with
  its own repo key regardless of what signs the build. **F-Droid-signed and
  GitHub-signed builds still have permanently different signers**, so a phone
  with LibreNotes installed from a GitHub Release APK will never show F-Droid
  updates as installable (F-Droid's client falls back to a plain "Open" button
  and reports "no versions with compatible signer", confirmed 2026-09-28
  against a real device), and vice versa; the only fix is uninstall +
  reinstall from the desired source. Direct-APK-to-direct-APK upgrades work
  in place from the first release built with the persisted keystore onward;
  APKs from before it were each signed with a different throwaway debug key.
- **F-Droid status:** LIVE. App is published in the official F-Droid repo at
  `https://f-droid.org/packages/dev.librenotes.app/` — installable via the
  F-Droid client, no manual APK download needed. Fastlane metadata +
  screenshots in `clients/app/fastlane/metadata/android/en-US/`, build recipe
  in `metadata/dev.librenotes.app.yml`. Got here via MR
  `https://gitlab.com/fdroid/fdroiddata/-/merge_requests/41300`, merged into
  `fdroiddata` master (squashed as `4935c52e`) by maintainer `linsui`, then
  built + signed by F-Droid's build server. Repo is public at
  `https://github.com/Piliii/LibreNotes` (see `git tag` for the current release). Future releases
  need a version bump + tag; F-Droid's server picks up new tags automatically
  and rebuilds (no new MR needed unless the build recipe itself changes).

## Status / history

Completed work and the reasoning behind it lives in [`HISTORY.md`](HISTORY.md)
(numbered items, referenced from here as "item N"). Planned work is not tracked
in either file.

## Conventions

- Wire format and models are defined **once** in `notally_core` and shared by
  both server and clients. Don't duplicate models — extend the shared package.
- Keep all cryptography on the client. The server must remain content-blind.
- Never commit `server/data/` (holds the db and the auth token).
- Both `clients/app/pubspec.lock` and `server/pubspec.lock` are tracked — keep
  them committed for reproducible builds (F-Droid requirement).
- `server/pubspec.yaml`'s `version` is independent of the app's version — it
  tracks the **server binary/protocol**, not app releases, and must be bumped
  by hand whenever `server/` changes (a new endpoint, a `db.dart` schema/
  conflict-logic change, a dependency bump that changes behavior, etc.),
  even if that release doesn't touch the app at all. It's already wired
  through: `scripts/package-server.sh` names the tarball off this version,
  independently of `clients/app/pubspec.yaml`. Bump `_apiVersion` in
  `server/lib/api.dart` and `clients/app/lib/sync/sync_api.dart` too, in
  lockstep, whenever the wire protocol itself changes (not just the server's
  internals) — that's what actually drives `VersionMismatchException`.
- **Releasing:** write the notes under `## [Unreleased]` in `CHANGELOG.md`, run
  `scripts/bump-version.sh X.Y.Z` (bumps `clients/app/pubspec.yaml` incl. the
  `+N` code, dates the changelog section, generates the F-Droid
  `changelogs/N.txt`), review, commit, then tag `vX.Y.Z`. `release.yml` fails
  fast if the tag doesn't match the pubspec version. The app's Sync page shows
  the version at runtime via `package_info_plus`; nothing else hardcodes it.
