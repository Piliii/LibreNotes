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
   Current release: `v1.2.0`.
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
20. **TODO — remaining before "good to go":**
    - **Linux .deb/.rpm packages**: add `fpm` to `scripts/package-linux.sh` to
      produce `.deb` (Debian/Ubuntu) and `.rpm` (Fedora/openSUSE) from the same
      Flutter bundle. Install to `/opt/librenotes/` + wrapper at `/usr/bin/librenotes`,
      desktop entry, icon, appdata in standard XDG paths. Distribute via GitHub
      releases alongside AppImage + tarball. Dependency: `gtk3`/`libgtk-3-0`.
    - **Server optional WebSocket push** (instead of polling every 10s).
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
    - **awesome-selfhosted submission**: submit a PR to
      `awesome-selfhosted/awesome-selfhosted` to list LibreNotes under the
      Notes/Notebooks category. This is one of the highest-value visibility
      actions for a self-hosted project — the list drives organic traffic, stars,
      and the right audience. Write the PR yourself (no AI); it's a one-liner
      entry in a markdown file.
    - **Local-at-rest encryption**: local notes are currently stored as
      **plaintext** in the Drift/sqlite table (`title`/`body` are plain
      `text()` columns) — the DEK today only protects data in transit to the
      server. Change local storage to ciphertext using the *same* DEK
      (`note_crypto.dart`'s existing XChaCha20-Poly1305 AEAD): schema bump to
      store encrypted blobs, `NotesRepository` decrypts on the way out of
      `watchNotes()`/`watchNote()`/`getNote()` and encrypts on the way into
      create/update. Consequence: the app needs the DEK resolved (keyring or
      a passphrase prompt) before showing any note, even offline before first
      sync — closes the "plaintext sqlite on a lost/stolen device" gap. The
      import/export feature below is built directly on top of this boundary.
    - **Markdown import/export as an explicit crypto boundary**: manual,
      opt-in interop — "Export" decrypts notes on the fly and writes them out
      as plain `.md` files to a folder the user picks, so notes are never
      locked to LibreNotes and stay readable elsewhere. "Import" reads `.md`
      files from other apps and immediately encrypts them into the local
      at-rest store (see item above) using the same DEK. Decryption/
      encryption only ever happens at these explicit, user-triggered
      boundaries — nothing sits in plaintext on disk automatically.
    - **Backlinks / `[[wiki-links]]` between notes**: let notes reference each
      other by title (`[[Note Title]]`), resolved and rendered client-side
      against already-decrypted content — no server or crypto changes needed.
      Show a "linked mentions" section per note for backlinks. Turns the app
      from a note pile into a lightweight personal knowledge base.
    - **Per-note local version history**: `rev` already bumps on every
      accepted write — persist the last N encrypted snapshots per note
      locally (Drift) so a note can be time-traveled/undone independently of
      the trash/archive flow. Purely local, no server involvement.
    - **Home-screen Android widget**: a widget for quick note creation
      (and/or showing pinned notes) without opening the app.
    - **On-device voice-to-text notes**: local speech-to-text (e.g.
      whisper.cpp/vosk) to transcribe voice memos into notes with zero cloud
      STT dependency — consistent with the no-Google-services/self-hosted
      privacy stance.
    - **Tearable note tabs on desktop**: let a note be dragged out of the main
      app window into its own separate window (tab-tear-off, like a browser
      tab), so multiple notes can be viewed/edited side by side on desktop.
    - **Font selection**: let the user change the font used for note text
      (editor + rendered preview).
    - **Text highlighting**: select text and apply a highlight in a choice of
      colors, similar to the existing note color picker but scoped to a text
      selection rather than the whole note.
    - **WYSIWYG formatting mode (alternative to raw markdown)**: today notes
      are edited as raw markdown text (typing `#`, `-`, etc. by hand). Add a
      mode where selecting a piece of text surfaces a set of visual actions
      (heading size, bold, list, etc.) that apply the equivalent markdown
      under the hood — same underlying format, no need to know markdown
      syntax to use it.
    - **Custom note colors (hex picker)**: the existing color picker (item 8)
      only offers a fixed swatch set. Add a hex color input (on both Android
      and desktop) so a note can be set to any arbitrary color, not just the
      presets.
    - **Gradient note colors**: extend note coloring beyond a single flat
      color to support a gradient (two or more stops) as the note's
      background.

## Conventions

- Wire format and models are defined **once** in `notally_core` and shared by
  both server and clients. Don't duplicate models — extend the shared package.
- Keep all cryptography on the client. The server must remain content-blind.
- Never commit `server/data/` (holds the db and the auth token).
- Both `clients/app/pubspec.lock` and `server/pubspec.lock` are tracked — keep
  them committed for reproducible builds (F-Droid requirement).
