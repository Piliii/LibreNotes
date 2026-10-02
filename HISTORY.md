# LibreNotes — Status / history

Completed work and the reasoning behind it. Planned work is not tracked in this file.

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
   Current release: see the latest git tag / `CHANGELOG.md` (item 27 for v1.5.5).
8. **UI polish + color picker** — DONE: note color picker implemented. Mobile
   UI fully polished: staggered masonry grid, swipe-to-archive, pull-to-refresh,
   pinned/notes section headers, animated search header, frosted-glass bottom
   sheet with inline color picker, skeuomorphic card styling (gradient +
   multi-layer shadows). Desktop polished: gradient+shadow sidebar list items,
   pinned/notes section headers, better empty-editor state. Timestamps now show
   "Dec 1" / "Dec 1 2024" format; markdown link artifacts stripped from previews.
9. **Linux distribution** — DONE: AppImage + tarball (attached to each GitHub
   release), AUR (`librenotes-bin`) live. Flatpak dropped (not worth maintaining).
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
    the real tag history (v1.0.1 → v1.2.1) and kept current per release. GitHub Discussions
    was enabled 2026-10-02.
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
      directly in the editor. Since verified working on a real Android
      device (originally shipped checked only via `flutter analyze` and
      manifest/Kotlin review).
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
    - **Follow-up (resolved)**: the installed `librenotes-bin` was updated past
      the stale v1.2.0 build (now `1.5.0-1`; AUR's latest may run ahead of what's
      installed — `yay -Syu` picks it up).

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

24. **Server download links were broken + no arm64 server build existed** — DONE:
    - **Root cause**: the website's Server Setup "Binary install" card told users to
      `curl` `https://librenotes.ayopili.com/dl/server`, but that short link
      redirected to `github.com/.../releases/latest` — an HTML release-notes
      page, not a binary. Confirmed live: `curl -L` on it downloads the page,
      and the shown `chmod +x librenotes-server` then runs against that HTML
      file. The instructions were non-functional for everyone, on any
      architecture, independent of the arm64 gap below. Separately, the copy
      also said "Replace linux-x86_64 with linux-arm64 if on a Raspberry Pi"
      even though the shown command never contained that string anywhere, and
      `build-server` in `release.yml` only ever ran on `ubuntu-latest`
      (x86_64) with no cross-compile step — no arm64 asset has ever been
      published, so the instruction was false on a *real* Raspberry Pi (which
      is arm64), undermining the "5 minutes on a Raspberry Pi" pitch repeated
      in both the Server Setup and Download sections. On top of that, the
      real release asset was never a bare binary to begin with -
      `scripts/package-server.sh` produces a `.tar.gz` with the binary,
      `install.sh` (sets up a systemd service under a dedicated
      `librenotes` user), `backup.sh`, and a bundled `libsqlite3.so` - but the
      website's 3-step flow described curl-ing a raw executable and running
      it in the foreground, which was never what shipped.
    - **Fix**: `build-server` in `release.yml` is now a 2-leg matrix
      (`ubuntu-latest`/x86_64, `ubuntu-24.04-arm`/arm64 - GitHub's free hosted
      arm64 runners, no QEMU needed), each uploading a differently-named
      artifact (`server-tarball-x86_64` / `server-tarball-arm64`) merged into
      the same release via the existing `merge-multiple: true` download step.
      `scripts/package-server.sh` normalizes `uname -m` (`aarch64` → `arm64`)
      and **drops the version number from the tarball filename** (now
      `librenotes-server-linux-<arch>.tar.gz`, version still embedded inside
      as a `VERSION` file) specifically so `website/vercel.json`'s `/dl/server`
      and new `/dl/server-arm64` redirects can point at GitHub's *stable*
      `/releases/latest/download/<exact-filename>` URLs without going stale
      every time `server/pubspec.yaml`'s version bumps (see item above on
      that version being independent of the app's). `ServerSetupSection.js`'s
      Binary steps were rewritten to match the real flow: download + `tar
      -xzf` the tarball, `cd` into it, `sudo bash install.sh` (which itself
      prints the token, with a `sudo cat /var/lib/librenotes/token` fallback
      shown too), then connect the app - and the arm64 instruction now points
      to the actual `/dl/server-arm64` link instead of an unmatched
      find-replace string.
    - **Verified against the real `v1.5.5` release (2026-09-29)**: the
      2-leg `build-server` matrix ran green and the release carries
      `librenotes-server-linux-x86_64.tar.gz` and
      `librenotes-server-linux-arm64.tar.gz`; `/dl/server` and
      `/dl/server-arm64` on the live site resolve through to those tarballs
      (HTTP 200).
    - **Follow-up refinements, same session**: step 1's download command is
      now a true one-liner - `curl -L <url> | tar -xzf -` piped directly,
      no intermediate `.tar.gz` file/filename at all (considered a shorter
      output filename like `ln-srvr.tar.gz` instead, but that doesn't fix
      what actually causes the wrap - the URL length, not the filename -
      and a cryptic name reads worse for a command meant to be pasted as
      root). Also: `install.sh` had **no non-systemd guard** - it would
      partially install (create the `librenotes` user, copy files, write the
      data dir) before dying uninformatively on `systemctl: command not
      found` on Alpine/Void/Devuan/etc. Added an early check for
      `/run/systemd/system` (the reliable "is systemd actually PID 1" test,
      not just "is `systemctl` on PATH") right after the root check, so it
      now fails immediately with a pointer to the Docker image instead -
      Docker already works on any distro regardless of init system, so that
      stays the actual answer for non-systemd hosts rather than this project
      taking on separate OpenRC/runit/sysvinit unit files to maintain.

25. **Linux desktop coredump on quit (NVIDIA)** — PARTIALLY FIXED:
    - **Symptom**: closing the desktop app on an NVIDIA (proprietary driver)
      system reliably produces a `systemd-coredump` entry, confirmed against
      a real device (`archpp`, driver `615.71.09`) on 2026-09-29. Two distinct
      crash signatures were observed, non-deterministically depending on
      shutdown timing:
      1. `SIGSEGV` inside `libnvidia-eglcore.so`, reached via an
         atexit-registered handler in `libEGL_nvidia.so` that runs *after*
         `main()` returns from `g_application_run()` — i.e. after the GTK
         window and Flutter engine have already shut down cleanly.
      2. `SIGABRT` from a libepoxy assertion
         (`epoxy_get_proc_address: ... "Couldn't find current GLX or EGL
         context"`), preceded by a `Gdk-WARNING: eglMakeCurrent failed`,
         happening *during* window teardown rather than after.
    - **Fix (variant 1 only)**: `clients/app/linux/runner/main.cc` now calls
      `_exit()` right after `g_application_run()` returns, instead of letting
      `main()` return normally. This skips libc's atexit handler chain
      entirely (harmless — the window and engine are already torn down by
      that point), matching the same workaround independently arrived at by
      another Flutter-Linux project hitting an identical trace
      (`Nihmar/Niman` issue #108 / PR #113).
    - **Variant 2 is a genuine, currently-unfixed upstream Flutter engine
      bug — not fixable from this repo.** It's
      [flutter/flutter#192873](https://github.com/flutter/flutter/issues/192873)
      ("[Linux] Potential crash in redraw_cb"), filed 2026-09-16 and still
      open as of Flutter 3.47.1 (latest stable, Aug 2026 — this project is
      still on 3.32.2). Root cause: `fl_view_present_layers()` schedules a
      GTK-thread redraw via `g_idle_add()` on the raster thread, but nothing
      stops `gtk_widget_destroy()` from tearing down the window concurrently
      on the main thread; if the idle callback loses the race it calls
      `eglMakeCurrent` against an already-destroyed EGL surface, which fails
      and sends libepoxy into an assertion-triggered `abort()`. This is
      compiled into the Flutter SDK's own `libflutter_linux_gtk.so`, entirely
      outside this repo's source, and the abort happens *before* `main()`
      would return — so the variant-1 fix above cannot reach it. No app-level
      workaround is known; resolving it requires an upstream engine fix and a
      Flutter SDK bump once one lands.
    - **Net effect**: quitting the desktop app on NVIDIA may still
      occasionally coredump (variant 2) until upstream Flutter fixes
      #192873, even though variant 1 is resolved. Neither variant loses data
      or affects the running app — both happen strictly during/after
      shutdown that has already completed from the user's perspective.

26. **Android release APK signed with a real, persisted keystore** — DONE:
    - **Root cause (flagged externally 2026-09-29)**: androidfreeware.net
      showed a "signed with a debug certificate" warning on the GitHub
      Release APK. Accurate, not a false positive:
      `clients/app/android/app/build.gradle.kts`'s `release` build type
      pointed `signingConfig` at `signingConfigs.getByName("debug")` — the
      Android Gradle Plugin's built-in auto-generated debug cert — and
      `release.yml` never persisted a keystore across CI runs, so every
      tagged build got a fresh, unique debug key. That's the same root cause
      already documented under "Licensing & distribution" as breaking
      direct-APK-to-direct-APK upgrades and guaranteeing a signer mismatch
      against F-Droid's build of the same version.
    - **Fix**: generated one real release keystore (RSA 2048, PKCS12,
      10000-day validity, alias `librenotes`) with `keytool`, kept outside
      the repo entirely at `~/.android-keys/` on this machine (not just
      gitignored — never in the working tree at all). `build.gradle.kts` now
      loads `android/key.properties` (already covered by
      `clients/app/android/.gitignore`) when present and defines a real
      `release` signing config from it; when absent — F-Droid's from-source
      build, or a contributor without the key — it falls back to the debug
      config exactly as before, so neither of those paths changed behavior.
      `release.yml`'s `build-android` job gained a step that decodes a new
      `ANDROID_KEYSTORE_BASE64` repo secret into `$RUNNER_TEMP/release.jks`
      and writes a matching `key.properties` before `flutter build apk`,
      guarded by `if: secrets.ANDROID_KEYSTORE_BASE64 != ''` so a fork
      without the secret still builds (debug-signed, as before). Secrets
      pushed to the `Piliii/LibreNotes` repo: `ANDROID_KEYSTORE_BASE64`,
      `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_PASSWORD`,
      `ANDROID_KEY_ALIAS`.
    - **Verified locally**: a real `flutter build apk --release
      --target-platform android-arm64` against the new `key.properties`
      produced an APK whose `apksigner verify --print-certs` SHA-256
      (`1f6ef3...d6a6`) matches the generated keystore's certificate —
      confirms the debug fallback isn't silently still active.
    - **Verified against the real `v1.5.5` release APK (2026-09-29)**:
      `apksigner verify --print-certs` on the GitHub Release APK reports the
      keystore's certificate (CN=LibreNotes, SHA-256 `1f6ef3...d6a6`), not a
      debug cert — the CI signing step works end to end.
    - **One-time transition cost, expected and unavoidable**: this keystore
      is brand new, so it shares no lineage with any prior GitHub Release
      APK (each of which was already a unique, mutually-incompatible debug
      key, so nothing new is lost there) or with the F-Droid signer (never
      shared to begin with). Anyone who installed a previous GitHub Release
      APK will hit exactly one more signature-mismatch break upgrading into
      the first release built with this keystore (same uninstall + reinstall
      workaround as the pre-existing F-Droid case) — every release from this
      one forward will then update in place normally.
    - **Backed up** (off-machine copy + credentials stored privately, not
      documented here). Losing all copies would reproduce this exact
      problem permanently for anyone who's installed a version signed with
      this key, with no recovery path — this is also the keystore the
      "Google Play Store submission" item below depends on reusing.

27. **v1.5.5: ghost empty notes, contrast safeguard, server/CI fixes** — DONE:
    - **Ghost empty notes**: closing an empty note (e.g. the one auto-opened
      at desktop startup) now goes through the same tombstone path as a real
      delete, and an empty note is never pushed to the server — previously
      it could reach the server, then resurrect on the next sync because
      the local discard never told the server. Empty notes no longer show in
      the list.
    - **Note text contrast**: text color is now picked per note to meet a
      minimum contrast ratio against its actual (light/white/custom/gradient)
      background.
    - **Website**: changelog page (nav + footer) and a version badge in the
      nav; live demo updated to mirror the app's live-preview editing; server
      setup fixes from item 24.
    - **Release pipeline**: item 24's server matrix and item 26's keystore
      signing shipped in this tag; `release.yml` gained a `workflow_dispatch`
      trigger for manual re-runs and several CI fixes (secrets can't be read
      in step `if:`; `setup-dart` architecture input is `x64`).
