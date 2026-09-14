# Changelog

All notable changes to LibreNotes are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning is
plain semver-ish tags (`vX.Y.Z`).

## [Unreleased]

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

[Unreleased]: https://github.com/Piliii/LibreNotes/compare/v1.3.0...HEAD
[1.3.0]: https://github.com/Piliii/LibreNotes/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/Piliii/LibreNotes/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/Piliii/LibreNotes/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/Piliii/LibreNotes/compare/v1.0.1...v1.1.0
[1.0.1]: https://github.com/Piliii/LibreNotes/releases/tag/v1.0.1
