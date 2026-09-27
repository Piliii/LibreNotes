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
  or release sync silently fails. Release still uses the debug signing config
  (`android/app/build.gradle.kts`) — harmless for F-Droid itself, since F-Droid
  always builds from source and re-signs with its own repo key regardless of
  what signs the build. It does bite the **GitHub Release APK**, though:
  `release.yml`'s runners don't persist a keystore, so every tagged CI build
  mints a fresh, unique debug key. Consequence, confirmed 2026-09-28 against a
  real device: a phone with LibreNotes installed from a GitHub Release APK (or
  any non-F-Droid build) will *never* show F-Droid updates as installable —
  F-Droid's client falls back to a plain "Open" button and reports "no
  versions with compatible signer" in the version list, since Android refuses
  to let F-Droid overwrite an app signed with a different certificate. Same
  problem strikes direct-APK-to-direct-APK upgrades between releases, since
  each GitHub build's debug key differs from the last. Only fix on an affected
  device is uninstall + reinstall from the desired source. A real fix needs a
  dedicated, persisted release keystore (generated once, stored as a GitHub
  Actions secret, reused by every CI run) — not done yet; see the roadmap's
  "not version-gated" list.
- **F-Droid status:** LIVE. App is published in the official F-Droid repo at
  `https://f-droid.org/packages/dev.librenotes.app/` — installable via the
  F-Droid client, no manual APK download needed. Fastlane metadata +
  screenshots in `clients/app/fastlane/metadata/android/en-US/`, build recipe
  in `metadata/dev.librenotes.app.yml`. Got here via MR
  `https://gitlab.com/fdroid/fdroiddata/-/merge_requests/41300`, merged into
  `fdroiddata` master (squashed as `4935c52e`) by maintainer `linsui`, then
  built + signed by F-Droid's build server. Repo is public at
  `https://github.com/Piliii/LibreNotes`, tagged `v1.2.0`. Future releases
  need a version bump + tag; F-Droid's server picks up new tags automatically
  and rebuilds (no new MR needed unless the build recipe itself changes).

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
7. **F-Droid submission** — DONE, fully live: screenshots added, build recipe
   written, MR submitted to `fdroid/fdroiddata` (MR #41300), merged by
   maintainer `linsui`, and the app is now published at
   `https://f-droid.org/packages/dev.librenotes.app/`. Repo public on GitHub.
   Current release: `v1.4.0`.
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
    double header bar). Ctrl+Q quits the app via a `HardwareKeyboard` global
    handler in `main.dart`. Ctrl+W is intentionally NOT wired to quit — on
    Linux/GTK it is consumed at the IME level for "delete word" in TextFields,
    which causes orphaned `KeyUpEvent` warnings from Flutter's key-state tracker.
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
    items show the body text as the primary text (normal weight, not italic)
    and skip the secondary preview line. Desktop tab labels use the body text
    as a fallback.
18. **Open source project hygiene** — DONE: `CONTRIBUTING.md`, `SECURITY.md`
    (points to GitHub private security advisories), `CODE_OF_CONDUCT.md`
    (Contributor Covenant 2.1), `.github/ISSUE_TEMPLATE/` (bug report + feature
    request forms, plus a `config.yml` disabling blank issues and linking to
    security advisories/discussions), and a root `CHANGELOG.md` seeded from
    the real tag history (v1.0.1 → v1.2.1). **Still needs a manual step:**
    enable GitHub Discussions in repo settings (Settings → Features) — the
    issue template config links to it.
19. **v1.3.0: self-destruct timers + quick capture** — DONE:
    - **Self-destructing notes**: optional per-note TTL set from the editor
      toolbar (hourglass icon → 1h/1d/7d/30d/off). Stored as a nullable
      `expiresAt` (schema v5) that's part of the encrypted payload like
      `archived`, so the timer syncs across devices. `NotesRepository`
      runs a client-side sweep (`sweepExpiredNotes`, every 60s +
      once at startup) that tombstones expired notes through the exact same
      soft-delete path as a manual trash delete.
    - **Linux global hotkey quick-capture**: Ctrl+Alt+N (via `hotkey_manager`
      + `window_manager`, `lib/desktop/quick_capture.dart`) shrinks the app
      window to a small floating box, focuses a text field, and creates a note
      on Enter (Esc discards) — then restores the window's exact prior size/
      position/visibility. Requires the `keybinder-3.0` system library
      (Linux runtime dep, like `gtk3` for packaging) — `linux/CMakeLists.txt`
      also suppresses an upstream `-Wsometimes-uninitialized` build failure in
      `hotkey_manager_linux` 0.2.3 (unmaintained since 2024), same pattern
      already used there for `flutter_secure_storage_linux`. **Known
      limitation:** `keybinder-3.0` uses X11's `XGrabKey`, which silently does
      nothing under a native-Wayland GDK session (GDK's default backend on
      current GNOME/KDE) — no error surfaced, the shortcut just never fires.
      A real fix needs the `xdg-desktop-portal` GlobalShortcuts portal
      instead, a different and compositor-support-dependent integration.
      Workaround today: launch with `GDK_BACKEND=x11`.
    - **Android share-sheet integration**: registers LibreNotes as an
      `ACTION_SEND` (`text/plain`) target. Native side is a small Kotlin
      method channel in `MainActivity.kt` (`dev.librenotes.app/share`) —
      `getInitialSharedText` for a cold start launched by a share,
      `onSharedText` pushed via `onNewIntent` for a share while the app's
      already running (`singleTop` launch mode). Dart side
      (`lib/android/share_intent.dart`) creates the note and opens it
      directly in the editor. Not yet verified against a real Android build —
      no Android SDK on the dev machine this was built on; verified via
      `flutter analyze` and manifest/Kotlin review only.
    - Also fixed in passing: a stale local dev database on this machine had
      `PRAGMA user_version` stuck at 3 while the `archived` column (schema
      v4) already existed physically, crash-looping the app on every launch.
      Not caused by this work, but blocked verifying it — backed up and
      repaired with `PRAGMA user_version = 4` (metadata-only, no note content
      touched).
20. **v1.4.0: local-at-rest encryption + import/export + UI polish** — DONE:
    - **Local-at-rest encryption**: local notes are no longer plaintext in the
      Drift/sqlite table. `title`/`body` are encrypted together (as one
      `{title, body}` payload, matching the sync payload shape) into
      `content_ciphertext`/`content_nonce` BLOB columns (schema v6) using the
      *same* DEK that protects notes in transit (`note_crypto.dart`'s
      XChaCha20-Poly1305 AEAD). Everything else (pinned, color, timestamps,
      archived, expiresAt) stays plaintext locally — the app itself needs to
      sort/filter on those, and only the free-text content was the actual
      plaintext-on-disk risk. `NotesRepository` is the sole boundary:
      decrypts on the way out of `watchNotes()`/`watchNote()`/`getNote()`/
      `watchArchive()`/`watchTrash()`/`dirtyNotes()`, encrypts on
      `createNote()`/`updateContent()`/`applyRemote()`. UI code is unaffected
      — it still consumes a `NoteRow` with plain `title`/`body` strings; that
      type moved from a Drift-generated class to a plain one in
      `notes_repository.dart` (the raw encrypted row is now `LocalNoteRow`).
    - **DEK now resolves before any note is shown, even fully offline**: new
      `lib/data/local_key_manager.dart` (`LocalKeyManager`) owns the single
      raw DEK in the platform keyring (`flutter_secure_storage`), independent
      of whether sync is configured. `main.dart` calls `db.warmUp()` (forces
      the v5→v6 migration to run, which encrypts any legacy plaintext rows)
      then `LocalKeyManager.resolve(db)` before building `NotesRepository` or
      showing any UI. A brand-new/local-only install silently generates and
      keyring-persists a fresh DEK (nothing at risk yet); an existing
      sync-configured device reuses its already-keyring-persisted DEK (same
      key protects local + remote — see below). If the keyring can't be read
      *and* the notes table already has ciphertext rows, `resolve()` refuses
      to silently mint a new, unrelated DEK (that would just make every note
      permanently undecryptable) — it throws `LocalKeyStorageException` and
      `main.dart` shows `lib/ui/locked_recovery_screen.dart` instead: if sync
      was ever configured, the user's passphrase re-derives the same DEK from
      the locally-cached wrapped keystore (no network round-trip); otherwise
      there's no passphrase to recover with, and the only way forward is an
      explicit, confirmed local reset. Keyring *write* failures are always
      best-effort/non-fatal (matches the pre-existing sync auto-unlock
      pattern) — only a *read* miss against existing ciphertext is treated as
      unrecoverable-without-recovery-flow.
    - **Sync and local encryption now share one DEK**: `SyncService` no
      longer owns a separate `_crypto`/keyring lifecycle — it reads/writes
      through `NotesRepository.crypto`. Connecting sync for the first time
      (no server keystore yet) wraps *this device's existing local DEK*
      (`NoteCrypto.wrap`) instead of generating a new one, so already-
      encrypted local notes don't need re-encrypting. Connecting to an
      *existing* keystore (second device, or reconnecting) adopts the
      server's DEK via the new `NotesRepository.adoptCrypto()`, which
      re-encrypts every local row under the new key (a no-op if the bytes are
      already identical). `SyncService.isUnlocked` now means "sync is
      actively connected" (`_api != null`), not "crypto is available" (it
      always is, from boot).
    - **Markdown import/export** (`lib/ui/import_export_page.dart`, opened via
      an import/export icon next to Archive in the sidebar/toolbar on both
      desktop and mobile): Export decrypts every non-trashed note on the fly
      and writes one plain `.md` file per note (title as an `# H1` line, then
      body; deduplicated filenames) into a folder the user picks via
      `file_picker`. Import reads picked `.md`/`.markdown`/`.txt` files
      (a leading `# Heading` line becomes the title) and creates+encrypts a
      note per file through the normal `NotesRepository` path. Decryption/
      encryption only ever happens at these explicit, user-triggered
      boundaries. Verified via `flutter analyze`/tests and a real headless
      desktop launch (including a live run of the v5→v6 migration against
      this machine's actual dev database — 68 real notes migrated cleanly,
      `user_version` now 6, `title`/`body` columns dropped); the folder/file
      picker dialogs themselves weren't manually clicked through.
    - **Lighter title-less card/sidebar body text** (item 17): mobile card
      body-preview text now uses a brighter shade when it's a title-less
      card's *only* content, instead of the dimmer secondary-preview shade;
      desktop sidebar rows do the same (no more dimming for title-less rows
      even when not the active selection).

21. **Local db migration hardening (schema-downgrade guard)** — DONE:
    - **Root cause of a recurring dev-machine crash-loop**: `AppDatabase.migration`'s
      `onUpgrade` only wrote `PRAGMA user_version` once, after the *entire*
      multi-step v1→v6 migration function returned. Any interruption partway
      through (hot restart, a slow/failing step, a killed process) left the
      already-applied `ALTER TABLE`s committed (SQLite auto-commits DDL) but
      the version number stuck behind, so the next launch re-ran completed
      steps and crashed on `duplicate column name`. This happened three times
      on this machine's dev database (`~/Documents/notally.sqlite`, backups
      at `.bak-preschemafix-20260906T012545`/`-20260924T033531`) before being
      root-caused on 2026-09-27.
    - **Fix — incremental version persistence**: each `if (from < N)` step in
      `database.dart`'s `onUpgrade` now issues `PRAGMA user_version = N`
      immediately after completing, instead of relying on drift to do it once
      at the end. The v5→v6 step (the riskiest: async, multi-statement, loops
      over every note to encrypt it) is additionally made resumable/idempotent
      by checking actual on-disk state — `pragma_table_info('notes')` for
      which columns already exist, and `WHERE length(content_ciphertext) = 0`
      for which rows still need encrypting — instead of trusting `from`.
    - **Fix — the actual recurring culprit was a version *downgrade*, not just
      interruption**: drift calls the same `onUpgrade(m, from, to)` callback
      for downgrades (`from > to`) as for upgrades, and with no guard, an
      older app binary opening a newer-schema database would run zero steps
      (all `if (from < N)` checks false), return "successfully," and drift
      would then stamp `user_version` with *that old binary's own lower*
      schemaVersion regardless (confirmed in drift 2.31.0 source,
      `_runMigrations` in `engines.dart`: `setSchemaVersion` runs
      unconditionally after `onUpgrade` returns, based only on `oldVersion !=
      currentVersion`) — silently corrupting the version number while leaving
      the actual (newer) table shape untouched. In practice this kept
      undoing every fix: the desktop launcher (`dev.librenotes.app.desktop`
      → `/usr/bin/librenotes`) runs the AUR package `librenotes-bin`, which
      was stuck at v1.2.0 (installed 2026-06-28, never `yay`-updated) even
      though AUR itself already had `1.4.0-1` published — opening it against
      the dev database after each repair reset the version number again.
      `onUpgrade` now throws `DatabaseTooNewException(from, to)` immediately
      when `from > to`, *before* drift's version write — confirmed via a
      regression test (`test/database_downgrade_guard_test.dart`) that seeds
      a real sqlite file at a future schema version and asserts
      `PRAGMA user_version` is left completely untouched after the throw.
      `main.dart` catches it at `db.warmUp()` and shows
      `lib/ui/outdated_app_screen.dart` ("update the app") instead of
      crashing or silently corrupting state.
    - **Repaired the dev database** to match: removed 2 note rows with
      empty/never-encrypted `content_ciphertext` (unrecoverable — `title`/
      `body` plaintext columns were already dropped in this file by an
      earlier interrupted migration), set `user_version = 6` to match the
      actual (already-migrated) table shape. Fresh backup at
      `.bak-preschemafix-20260927T202518` before touching anything.
    - **Follow-up for the owner**: run `yay -S librenotes-bin` to sync the
      installed binary with AUR's current `1.4.0-1` — until that's done, the
      desktop launcher still opens the stale v1.2.0 build (which will now
      hit the new `OutdatedAppScreen` instead of corrupting the db, but is
      still worth updating).

22. **v1.5.0: live-preview markdown editing, text highlighting, custom/
    gradient note colors** — DONE:
    - **Live-preview markdown editing** (`lib/markdown_editing_controller.dart`,
      `lib/markdown_format.dart`): notes are still plain markdown end to end —
      no new storage format — but the editor now renders that markdown styled
      (bold actually bold, headings actually sized, highlights actually
      colored) instead of showing raw syntax characters, Obsidian/Typora
      "live preview" style. `MarkdownEditingController extends
      TextEditingController` and overrides `buildTextSpan`: syntax markers
      (`**`, `#`, `- `, `==...==^color`) stay real characters in the buffer
      (so cursor/tap hit-testing never desyncs from the text) but are shrunk
      to a near-invisible sliver on any line the cursor isn't on, and shown
      small-and-faded on the line it is on. `markdown_format.dart` supplies
      the text-selection-toolbar actions (`toggleBold`, `toggleItalic`,
      `applyHeading`, `toggleBulletList`) that apply/remove those markers
      around a selection — idempotent (apply Bold to already-bold text,
      get plain text back). This only covers what those actions produce
      (heading/bold/italic/bullet/highlight); richer markdown (links, code
      blocks, blockquotes, tables, images) still renders as literal text
      here — the full-fidelity "Preview" toggle (complete `flutter_markdown`
      render) still exists for that.
    - **Text highlighting** (`lib/markdown_highlight.dart`): select text →
      apply one of 5 preset pastel colors (yellow/green/blue/pink/orange,
      chosen pastel so they read as "highlighted" regardless of the app's
      dark theme) via `==highlighted text==^colorkey` inline markdown syntax.
      `HighlightSyntax`/`HighlightBuilder` render it as a colored rounded
      background in the full markdown `Preview` mode; `previewText()`
      (`format.dart`) strips the delimiters (keeping the inner text) for
      card/sidebar previews; `MarkdownEditingController` renders it live in
      the editor itself, same as bold/headings.
    - **Custom hex color picker + gradient note colors** (`theme.dart`, new
      `flutter_colorpicker` dependency): the note-color picker (item 8) now
      also offers an HSV hex input, not just the fixed swatch set — any
      arbitrary color, on both desktop and Android. Colors can additionally
      be a 2-3 stop gradient. `Note.color` (`notally_core`) stays a plain
      `String` — a single hex (`"#2a2a2a"`) for a solid color, or
      `"grad:#hex,#hex"` for a gradient — so this needed **no schema
      migration and no sync/crypto changes**: it's still just an opaque
      string threaded through the existing encrypted payload. `theme.dart`
      adds `hexFromColor`/`isGradientColor`/`gradientStopHexes`/
      `encodeGradient`/`noteBaseColors`/`noteBackgroundDecoration` as the
      shared helpers UI code renders through.
    - Bundled with the item 21 downgrade-guard fix into a single v1.5.0
      release since both were sitting uncommitted together; not otherwise
      related. `flutter analyze` clean, all 41 tests pass (incl. the new
      downgrade-guard regression test) at release time.

23. **Mobile toolbar/header decluttering** — DONE:
    - **Note editor toolbar**: removed the self-destruct-timer (hourglass) and
      pin icons from the mobile note editor's icon bar (`note_editor.dart`) —
      they were mobile-only (desktop never showed them, relying on its
      right-click context menu instead), and duplicated what the note card's
      long-press menu already offered. Deleted the now-dead `NoteEditor.desktop`
      flag and the `_pinned`/`_pickExpiry`/`_togglePin` state that only existed
      to drive those two buttons; the two `NoteEditor(... desktop: true)` call
      sites in `home_screen.dart` were updated accordingly. The remaining
      toolbar (color picker, preview toggle, archive, delete) is unchanged.
    - **Mobile long-press sheet gained self-destruct**: `_showMobileNoteActions`
      (the bottom sheet from long-pressing a card) previously only had
      Pin/Archive/Move-to-Trash — it had **no** self-destruct entry at all, so
      removing the editor's hourglass icon would have made the timer
      unreachable on mobile. Added a "Self-destruct timer"/"Change
      self-destruct timer" `ListTile` (opens the same `NoteExpiryDialog` the
      desktop context menu uses) between Pin and Archive, so the feature stays
      reachable on mobile through the card menu instead of the editor.
    - **Home screen mobile header**: removed the standalone manual "Refresh
      now" icon (`_RefreshButton`) — the sync loop still polls automatically,
      this only removed the explicit manual-pull affordance. Collapsed the
      separate Archive and Import/Export icon buttons into a single vertical
      3-dot overflow menu (new `_MobileMoreButton`, `Icons.more_vert`),
      mirroring the existing desktop sidebar's `_SidebarMoreButton` pattern.
      Mobile header is now: Search → 3-dot menu (Archive, Import/export) →
      sync status icon. `_ArchiveButton`/`_ImportExportButton`/`_RefreshButton`
      were deleted as dead code once nothing referenced them.
    - `flutter analyze` clean across the whole app after each change.

24. **TODO — versioned roadmap, grouped by dependency and theme:**

    **v1.6.0 — Packaging & sync infra.** Distribution reach plus the two
    remaining infra gaps.
    - **Linux .deb/.rpm packages**: add `fpm` to `scripts/package-linux.sh` to
      produce `.deb` (Debian/Ubuntu) and `.rpm` (Fedora/openSUSE) from the same
      Flutter bundle. Install to `/opt/librenotes/` + wrapper at `/usr/bin/librenotes`,
      desktop entry, icon, appdata in standard XDG paths. Distribute via GitHub
      releases alongside AppImage + tarball. Dependency: `gtk3`/`libgtk-3-0`.
    - **Global hotkey via `xdg-desktop-portal` on Wayland**: the current
      quick-capture hotkey (`lib/desktop/quick_capture.dart`, `hotkey_manager`
      + `keybinder-3.0`) only works under X11/XWayland — `XGrabKey` has no
      visibility into native-Wayland clients, so on a native-Wayland GNOME/KDE
      session the shortcut only fires while the app itself already has focus
      (confirmed: `GDK_BACKEND=x11` silences the binding warning but doesn't
      restore true global capture, since almost everything else on the
      session is a native Wayland client outside the X server's view). Fix:
      implement the `org.freedesktop.portal.GlobalShortcuts` D-Bus portal
      (CreateSession → BindShortcuts → listen for `Activated`; no ready-made
      Flutter package, needs a small client via the `dbus` package) as the
      primary path on Wayland — zero-setup, and covers GNOME (mutter) and KDE
      Plasma 6 (KWin), the large majority of Wayland desktop users. Keep
      `keybinder-3.0` for X11 sessions (unaffected by this issue, works
      today). For Wayland compositors without portal support (Sway, other
      wlroots-based), gracefully skip the auto-grab rather than silently
      failing, and surface a one-time in-app note pointing to a manual
      fallback: expose a D-Bus method (or Unix socket) that triggers
      quick-capture, which the user binds themselves via their compositor's
      own custom-shortcut settings. Goal is tiered friction: zero setup for
      X11 + GNOME/KDE (the majority), manual one-time setup only for the
      long-tail compositors.
    - **Server optional WebSocket push** (instead of polling every 10s).

    **v1.7.0 — Editing & customization.** Remaining editor-toolbar and
    font-surface work — the highlight/custom-color/live-preview items
    originally planned here shipped early in v1.5.0 (item 22).
    - **Collapse the rest of the note editor toolbar into an overflow menu**:
      item 23 already removed the self-destruct-timer and pin icons from the
      mobile editor toolbar (redundant with the long-press card menu). What's
      left — color picker, preview toggle, archive, delete — is still a row
      of always-visible icon buttons. Move the less-frequently-used ones
      (archive, delete) behind a three-dot overflow menu instead.
    - **Font selection**: let the user change the font used for note text
      (editor + rendered preview).

    **v1.8.0 — Personal knowledge base.** Both purely local/client-side, turn
    the app from a note pile into a lightweight PKB.
    - **Backlinks / `[[wiki-links]]` between notes**: let notes reference each
      other by title (`[[Note Title]]`), resolved and rendered client-side
      against already-decrypted content — no server or crypto changes needed.
      Show a "linked mentions" section per note for backlinks.
    - **Per-note local version history**: `rev` already bumps on every
      accepted write — persist the last N encrypted snapshots per note
      locally (Drift) so a note can be time-traveled/undone independently of
      the trash/archive flow. Purely local, no server involvement.

    **v1.9.0 — New surfaces.** Bigger, more independent features — new
    platform surfaces rather than core app changes.
    - **Home-screen Android widget**: a widget for quick note creation
      (and/or showing pinned notes) without opening the app.
    - **On-device voice-to-text notes**: local speech-to-text (e.g.
      whisper.cpp/vosk) to transcribe voice memos into notes with zero cloud
      STT dependency — consistent with the no-Google-services/self-hosted
      privacy stance.
    - **Tearable note tabs on desktop**: let a note be dragged out of the main
      app window into its own separate window (tab-tear-off, like a browser
      tab), so multiple notes can be viewed/edited side by side on desktop.

    **Not version-gated — do anytime, no release needed.**
    - **awesome-selfhosted submission**: submit a PR to
      `awesome-selfhosted/awesome-selfhosted` to list LibreNotes under the
      Notes/Notebooks category. This is one of the highest-value visibility
      actions for a self-hosted project — the list drives organic traffic, stars,
      and the right audience. Write the PR yourself (no AI); it's a one-liner
      entry in a markdown file.
    - **Verify Android share-sheet on a real device/SDK**: shipped in v1.3.0
      but only verified via `flutter analyze` and manifest/Kotlin review — no
      Android SDK was available on the dev machine it was built on.
    - **Enable GitHub Discussions** in repo settings (Settings → Features) —
      the issue template `config.yml` already links to it.
    - **Guard against unsynced server/client version drift**: make sure a
      client and server running mismatched versions of each other (e.g. an
      old client against a newer server schema, or vice versa) can't corrupt
      state or crash — audit `X-Librenotes-Api-Version` handling and the
      sync/wire-format assumptions in `notally_core` for gaps.
    - **Persist a real Android release keystore in CI**: see the signing note
      under "Licensing & distribution" — `release.yml`'s GitHub Release APK
      is currently signed with a fresh debug key on every tagged build (no
      keystore persisted between runs), which breaks in-place updates between
      GitHub releases and guarantees a signer mismatch against the F-Droid
      build of the same version. Generate one keystore, store it
      base64-encoded as a GitHub Actions secret, and have `build-android` in
      `release.yml` use it instead of the debug config.

## Conventions

- Wire format and models are defined **once** in `notally_core` and shared by
  both server and clients. Don't duplicate models — extend the shared package.
- Keep all cryptography on the client. The server must remain content-blind.
- Never commit `server/data/` (holds the db and the auth token).
- Both `clients/app/pubspec.lock` and `server/pubspec.lock` are tracked — keep
  them committed for reproducible builds (F-Droid requirement).
