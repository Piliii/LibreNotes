# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

The owner: one person capturing and finding their own notes across their own devices (Android phone, Linux and Windows desktop, web). Used many times a day, switching between quick capture and finding an old note. Single-user by design; there are no teams or sharing.

## Product Purpose

LibreNotes is a personal, cross-device markdown note-taking app with a self-hosted sync server. Success means notes open instantly, work fully offline, and sync quietly whenever the home server is reachable.

## Positioning

The server is end-to-end-encryption-blind (it stores only ciphertext) and lives on a home LAN, never the public internet. Clients are offline-first, and conflicts are resolved by the user picking the winner rather than auto-merge. No Electron, no trackers, AGPLv3, published on F-Droid.

## Operating Context

One Flutter/Dart codebase ships to native Android, native Linux and Windows desktop, and web. Desktop shows a resizable notes list on the left and the editor on the right. Mobile shows a staggered 2-column masonry grid of cards. Notes autosave with a ~500 ms debounce from a local Drift store.

## Capabilities and Constraints

- Notes are markdown text with optional title, pin, archive, trash, per-note solid or gradient colour, self-destruct expiry, bulk actions and a global quick-capture hotkey on Linux.
- Mobile cards show body preview only when there is no title; title plus body when a title exists.
- Crypto stays on the client; the server never sees content or keys.
- Flutter only, no new dependencies for UI work, no Electron.

## Brand Commitments

- Name: LibreNotes. Android package `dev.librenotes.app`.
- Design DNA from the original prototype: dark theme (`#1a1a1a` / `#242424`), orange accent `#ff6900`, resizable sidebar, local cache for instant load.
- Platform choice: one custom brand language across targets, adapted per form factor.

## Evidence on Hand

- Source app icon: `assets/icon/librenotes.jpg`.
- Golden screenshots: `clients/app/test/goldens/home_desktop.png`, `home_mobile.png` (uncommitted).
- F-Droid screenshots under `clients/app/fastlane/metadata/android/en-US/`.

## Product Principles

- Privacy first: nothing leaves the user's own network or device, and the UI never implies otherwise.
- Instant and offline: capture and retrieval come before everything else.
- The user decides: conflicts, deletes and destructive actions are explicit.
- Quiet infrastructure: sync state is visible but never demands attention.

## Accessibility & Inclusion

No product-specific requirement beyond baseline: readable contrast (notes with light colours switch to dark text), visible focus on desktop, 44dp touch targets on mobile.
