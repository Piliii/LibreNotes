# Changelog

All notable changes to LibreNotes are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
plain semver-ish tags (`vX.Y.Z`).

## [Unreleased]

### Added
- Android: adaptive launcher icon with a monochrome layer, so themed icons
  (Android 13+, Lawnchair "tint with accent color") now work.
- Conflict screen: a line-by-line diff of this device vs. the server, and a
  "Merge manually" editor (starts from both versions with conflict markers).
- Search is now backed by an in-memory SQLite FTS5 index (never written to
  disk, so at-rest encryption is unaffected); falls back to plain substring
  search if FTS5 is unavailable or the query has terms under 3 characters.
- Android: a one-time, dismissible note on the Sync page explaining that
  F-Droid and GitHub APKs are signed differently and can't update each other.
- `PROTOCOL.md`: the wire protocol and encryption envelope, with test vectors.

## [1.5.7] — 2026-10-03

### Added
- The Sync page now shows the app version and build number at the bottom.
- Trash: notes are now permanently deleted 30 days after being trashed
  (on every device, via the same purge that "Delete permanently" uses). The
  Trash page shows how many days each note has left. **Notes that have
  already been in the trash for more than 30 days when you update get a
  3-day grace period** (counted from the first launch after updating) before
  they are deleted, and a one-time notice explains this when the app opens.
- Startup: a proper launch screen instead of a blank window — the LibreNotes
  icon on a dark background on Android (using the Android 12+ splash screen
  where available), and an icon-and-name loading screen on desktop while the
  local database and keys are being opened.
- Linux: `.deb` (Debian/Ubuntu) and `.rpm` (Fedora/openSUSE) packages,
  attached to each GitHub release alongside the AppImage and tarball.
- Server (Docker): a built-in health check (`librenotes-server --healthcheck`),
  so `docker ps` and hosting platforms can see whether the server is healthy.

### Fixed
- Server (Docker): the container no longer fails to start when its data
  volume is owned by root (as a fresh volume from a hosting platform usually
  is). It now fixes ownership of the data directory on startup, then runs as
  an unprivileged user with a fixed UID (10001). Existing volumes are
  migrated automatically on the first start.

## [1.5.6] — 2026-10-01

### Fixed
- Android: the app no longer sits on a black screen at launch when your sync
  server is unreachable (e.g. a home-network address while you're away, with
  internet on). The first sync now runs in the background after the app opens,
  and every sync request gives up after 15 seconds and shows as offline
  instead of hanging.

## [1.5.5] — 2026-09-29

### Added
- Website: a changelog page, linked from the nav bar and footer, plus a
  version badge in the nav bar.
- Web demo: updated to mirror the app's live-preview markdown editing and
  highlighting.

### Fixed
- Ghost empty notes: an empty note (e.g. the one auto-opened when the
  desktop app starts) could reach the sync server before being discarded,
  and discarding it only deleted it locally without telling the server —
  so it would resurrect on the next sync. Closing an empty note now goes
  through the same tombstone path as a real delete, and an empty note is
  never pushed to the server in the first place. Notes with no text no
  longer show up in the notes list at all.
- Note text contrast: a light, white, or custom/gradient note color could
  render text that blended into the background. Text color is now chosen
  per note to meet a minimum contrast ratio against its actual background.
- Website: the server "Binary install" instructions pointed at a broken
  download link (it resolved to the GitHub release page, not a binary) and
  there was no arm64 server build, despite the Raspberry Pi pitch. The
  server is now built and published for both x86_64 and arm64, and the
  install steps match what's actually shipped (the real tarball + `install.sh`).
- `install.sh` now fails fast with a clear message on non-systemd hosts
  instead of partially installing.
- Android: GitHub Release APKs are now signed with a persistent release
  keystore in CI instead of a fresh debug key on every build, fixing
  in-place updates between GitHub releases.

## [1.5.0] — 2026-09-27

### Added
- Live-preview markdown editing: the editor now renders markdown styled
  (bold, headings, highlights) instead of raw syntax, with a selection
  toolbar for heading/bold/italic/bullet-list — no separate raw/preview mode
  to switch out of.
- Text highlighting: select text and apply one of 5 preset colors.
- Custom hex color picker and gradient (2-3 stop) note colors, alongside the
  existing preset swatches.

### Fixed
- A recurring local-database crash-loop: schema migrations now persist their
  version incrementally instead of only at the end, and opening a database
  with a newer on-disk schema than the running app understands now shows an
  "update the app" screen instead of silently corrupting the version number
  or crash-looping.

## [1.4.0] — 2026-09-23

### Added
- Local-at-rest encryption: notes stored on-device are now encrypted with the
  same key that already protects them in transit to the sync server, closing
  the last plaintext-on-disk gap. The encryption key is resolved from the
  system keyring before any note is shown, even fully offline. If the keyring
  can't be read but encrypted notes already exist, a recovery screen offers
  passphrase-based recovery (if sync was ever configured) or an explicit,
  confirmed local reset.
- Markdown import/export: export every note as plain `.md` files to a folder
  you choose, or import `.md` files from other apps — notes are never locked
  into LibreNotes.

### Fixed
- Lightened body-preview text on title-less notes (mobile cards and desktop
  sidebar), which was too close to the dark background to read comfortably.

## [1.3.0] — 2026-09-14

### Added
- Self-destructing notes: optional per-note timer (1h/1d/7d/30d) that
  tombstones the note client-side when it expires, syncing across devices.
- Linux global hotkey quick-capture (Ctrl+Alt+N): shrinks the app window into
  a small floating box to jot a note without switching focus, from anywhere
  on the desktop. Requires `keybinder-3.0`; X11/XWayland only for now (see
  `CLAUDE.md` for the native-Wayland limitation).
- Android share-sheet integration: share text or a link from any app straight
  into a new LibreNotes note.
- Repository hygiene: `CONTRIBUTING.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`,
  GitHub issue templates.

### Fixed
- Docker server image: `/data` is now created and chowned to the non-root
  `librenotes` user at build time, fixing a `Permission denied` crash on
  startup when writing the auth token file. **If you already have a
  `librenotes-data` volume from an earlier image**, it was created with root
  ownership and needs a one-time fix after upgrading:
  `docker compose run --rm --user root librenotes-server chown -R librenotes:librenotes /data`
- Android: removed an empty `taskAffinity` override on `MainActivity` that,
  once the share-sheet intent-filter was added, caused the app to open in a
  second, separate Recents/Overview task instead of reusing the existing one.

## [1.2.1] — 2026-08-21

### Fixed
- Removed the Ctrl+W quit shortcut — on Linux/GTK it's consumed at the IME
  level for "delete word" in text fields, causing orphaned key-state warnings.
- Fixed a sidebar bold-title fallback bug (title-less notes falling back to
  body text).
- Corrected the F-Droid store listing category from "Notes" to "Note".

### Added
- Archive: notes can be archived instead of deleted, with restore /
  move-to-trash from the Archive page. Archive state is part of the encrypted
  payload, so it syncs without the server ever seeing it.
- Client-side note search (title + body substring match) on desktop and mobile.
- Desktop multi-select (Ctrl+Click / Shift+Click range-select) with a bulk
  action bar.
- Fastlane store icon for the F-Droid listing.

## [1.2.0] — 2026-06-28

### Added
- Seamless re-unlock via the platform keyring (`flutter_secure_storage`) —
  no passphrase prompt needed on every app start.
- Docker distribution for the sync server (GHCR image + `docker-compose.yml`).
- KDE Wayland fix: server-side decorations on non-GNOME desktops to avoid a
  double header bar.
- Release automation: tag push builds APK, AppImage/tarball, and server
  tarball, publishes a GitHub release, and updates the AUR package.
- Version mismatch detection between client and server
  (`X-Librenotes-Api-Version` header).

## [1.1.0] — 2026-06-27

### Added
- Note color picker.
- Linux desktop client support.
- Marketing website (`librenotes.ayopili.com`).

### Changed
- Mobile UI polish pass (staggered masonry grid, card styling).

## [1.0.1] — 2026-06-25

Initial public release of LibreNotes: self-hosted sync server, Flutter client
(Android + Linux desktop + web), end-to-end encryption (XChaCha20-Poly1305 +
Argon2id), trash bin with soft-delete tombstones, AGPLv3 license, F-Droid
build recipe and store screenshots.

[Unreleased]: https://github.com/Piliii/LibreNotes/compare/v1.5.5...HEAD
[1.5.5]: https://github.com/Piliii/LibreNotes/compare/v1.5.0...v1.5.5
[1.5.0]: https://github.com/Piliii/LibreNotes/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/Piliii/LibreNotes/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/Piliii/LibreNotes/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/Piliii/LibreNotes/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/Piliii/LibreNotes/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Piliii/LibreNotes/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/Piliii/LibreNotes/releases/tag/v1.0.1
