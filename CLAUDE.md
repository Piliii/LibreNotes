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
│   └── test/db_test.dart    Core sync/conflict tests (in-memory db).
└── clients/app/             Flutter client (desktop + Android + web, one codebase).
    ├── lib/main.dart        Wires AppDatabase → NotesRepository → SyncService → UI.
    ├── lib/data/            Drift local store (database.dart) + notes_repository.dart.
    ├── lib/sync/            sync_service.dart (pull/push loop), sync_api.dart,
    │                        note_crypto.dart (Argon2id + XChaCha20-Poly1305, client-only).
    ├── lib/ui/              home_screen, note_editor, conflicts_page, sync_settings_page,
    │                        archive_page.dart, trash_page.dart.
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
  Repo is public at `https://github.com/Piliii/LibreNotes`, tagged `v1.2.0`.

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
   release: `v1.2.0`.
8. **UI polish + color picker** — DONE: note color picker implemented. Mobile
   UI fully polished: staggered masonry grid, swipe-to-archive, pull-to-refresh,
   pinned/notes section headers, animated search header, frosted-glass bottom
   sheet with inline color picker, skeuomorphic card styling (gradient +
   multi-layer shadows). Desktop polished: gradient+shadow sidebar list items,
   pinned/notes section headers, better empty-editor state. Timestamps now show
   "Dec 1" / "Dec 1 2024" format; markdown link artifacts stripped from previews.
9. **Linux distribution** — DONE: AppImage + tarball (attached to GitHub release
   v1.2.0), AUR (`librenotes-bin`) live. Flatpak dropped (not worth maintaining).
   Packaging scripts: `scripts/package-linux.sh`, `scripts/package-server.sh`.
10. **Marketing website** — DONE: Next.js + Tailwind static export in `website/`.
    Sections: hero, Android screenshots, features, live demo (React/localStorage),
    download, server setup (3-step Binary + Docker tabs with copy buttons), footer.
    Deployed to Vercel + Cloudflare at `https://librenotes.ayopili.com`. Short
    redirects via `website/vercel.json` (`/dl/server`, `/dl/apk`, `/github`,
    `/dl/docker-compose`). Bunny Fonts, lucide-react + simple-icons,
    react-markdown + remark-gfm + react-syntax-highlighter in the live demo.
11. **Sync infrastructure** — DONE: Docker server image on GHCR
    (`server/Dockerfile`, `docker-compose.yml`, `.github/workflows/docker.yml`).
    Seamless re-unlock via platform keyring (`flutter_secure_storage`,
    `NoteCrypto.fromDek`, auto-unlock in `SyncService.init`). Version mismatch
    detection (`X-Librenotes-Api-Version` header, `VersionMismatchException`).
    Release automation (`.github/workflows/release.yml`: APK + AppImage/tarball +
    server tarball on tag push, GitHub release, AUR auto-updated).
12. **KDE Wayland** — DONE: `my_application.cc` uses `XDG_CURRENT_DESKTOP` to
    detect GNOME vs other DEs; KDE and others get server-side decorations (no
    double header bar). Ctrl+Q and Ctrl+W quit the app via a `HardwareKeyboard`
    global handler in `main.dart` (not `CallbackShortcuts` — that gets blocked
    by focused TextFields handling Ctrl+W as "delete word").
13. **Note search** — DONE: client-side substring search over title + body.
    Desktop: always-visible field in sidebar (orange focus border, X to clear).
    Mobile: search icon → animated header takeover. No-results empty states on
    both platforms. Section headers suppressed during search.
14. **Icons + branding** — DONE: all platform icons (Android mipmaps, web PWA,
    favicon) replaced with the squircle PNG. `MaterialApp.title` corrected to
    `'LibreNotes'` (was `'Notally'`).
15. **Desktop multi-select** — DONE: Ctrl+Click toggles notes in/out of a
    selection set; Shift+Click range-selects from the last clicked note.
    Selected items show an accent checkmark and tinted background. A bulk-action
    bar appears at the bottom of the sidebar (Archive / Pin / Unpin) and the
    editor area switches to a `_MultiSelectPanel` when 2+ notes are selected.
16. **Archive** — DONE: notes can be archived instead of deleted. `archived` is
    a bool column in the local DB (schema v4) and part of the encrypted payload,
    so archive state syncs across devices without the server ever seeing it.
    Primary removal action throughout the UI (swipe, context menu, editor
    toolbar) is now **Archive** rather than Trash. `ArchivePage` lists archived
    notes with Restore / Move-to-Trash per note; Trash is accessible from inside
    the archive page. Trash page + permanent-delete flow unchanged.
17. **Title-less cards** — DONE: when a note has no title, mobile cards show
    only the body preview (9 lines) with no "Untitled" label. Desktop sidebar
    items show the body text as the primary (italic) text and skip the secondary
    preview line. Desktop tab labels use the body text (italic) as a fallback.
18. **TODO — remaining before "good to go":**
    - **Linux .deb/.rpm packages**: add `fpm` to `scripts/package-linux.sh` to
      produce `.deb` (Debian/Ubuntu) and `.rpm` (Fedora/openSUSE) from the same
      Flutter bundle. Install to `/opt/librenotes/` + wrapper at `/usr/bin/librenotes`,
      desktop entry, icon, appdata in standard XDG paths. Distribute via GitHub
      releases alongside AppImage + tarball. Dependency: `gtk3`/`libgtk-3-0`.
    - **Server optional WebSocket push** (instead of polling every 10s).
    - **awesome-selfhosted submission**: submit a PR to
      `awesome-selfhosted/awesome-selfhosted` to list LibreNotes under the
      Notes/Notebooks category. This is one of the highest-value visibility
      actions for a self-hosted project — the list drives organic traffic, stars,
      and the right audience. Write the PR yourself (no AI); it's a one-liner
      entry in a markdown file.
    - **Open source project hygiene** *(do this once there are actual users —
      premature before the community exists):* add the standard files that signal
      a mature, welcoming project to contributors and stores like Flathub:
        - `CONTRIBUTING.md` — how to report bugs, request features, submit PRs.
        - `SECURITY.md` — where/how to report security vulnerabilities privately
          (e.g. GitHub private security advisories).
        - `CODE_OF_CONDUCT.md` — standard Contributor Covenant boilerplate.
        - GitHub issue templates (`.github/ISSUE_TEMPLATE/`) — bug report and
          feature request forms to keep the tracker tidy.
        - `CHANGELOG.md` at repo root — human-readable release history (not just
          fastlane changelogs).
        - Enable GitHub Discussions — gives users a place to ask questions and
          share setups, which generates the "community engagement" signal that
          Flathub's mature-project exception looks for.

## Conventions

- Wire format and models are defined **once** in `notally_core` and shared by
  both server and clients. Don't duplicate models — extend the shared package.
- Keep all cryptography on the client. The server must remain content-blind.
- Never commit `server/data/` (holds the db and the auth token).
- Both `clients/app/pubspec.lock` and `server/pubspec.lock` are tracked — keep
  them committed for reproducible builds (F-Droid requirement).
