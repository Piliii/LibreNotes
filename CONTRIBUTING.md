# Contributing to LibreNotes

LibreNotes is a small, personal-scale project — a self-hosted, end-to-end
encrypted note-taking app with one owner and many devices. Contributions are
welcome, but please read this before opening a PR so your time isn't wasted.

## Before you start

For anything beyond a small fix (typo, obvious bug, docs), please open an
issue first to discuss the approach. This project has a specific design
philosophy — see [`CLAUDE.md`](CLAUDE.md) for the product shape, sync model,
and encryption design — and changes that conflict with it won't be merged
regardless of code quality. In particular:

- **No Electron, no Windows client.** Flutter only, across website/Linux/Android.
- **The server must stay E2EE-blind.** No feature should require the server to
  see plaintext note content.
- **No CRDTs / auto-merge.** Conflicts are surfaced to the user, who picks a
  winner. This is intentional, not a gap.
- **LAN-first.** Remote access is meant to go through Tailscale/WireGuard, not
  by exposing the server to the public internet.

## Reporting bugs

Open a [GitHub issue](https://github.com/Piliii/LibreNotes/issues/new/choose)
using the bug report template. Include:

- What you did, what you expected, what happened instead.
- Platform (Android / Linux desktop / web) and version (`Settings` screen, or
  the APK/release filename).
- Server logs if the bug involves sync (redact your bearer token).

For **security vulnerabilities**, do not open a public issue — see
[`SECURITY.md`](SECURITY.md) instead.

## Requesting features

Open an issue using the feature request template. Explain the problem you're
trying to solve, not just the feature — there may already be a way to do it,
or a reason it's deliberately not there (see the design philosophy above).

## Submitting a pull request

1. Fork the repo and branch from `main`.
2. Keep PRs focused — one change per PR is much easier to review than a
   grab-bag.
3. Match existing code style; there's no separate linter config beyond the
   Dart/Flutter defaults (`dart format`, `flutter analyze`).
4. Run the relevant test suite before opening the PR:
   ```bash
   # Server changes (run from server/)
   dart test

   # Client changes (run from clients/app/)
   flutter test
   ```
5. Update `packages/notally_core` instead of duplicating models if your change
   touches wire format or shared types — it's the single source of truth for
   both the app and the server.
6. Describe *what* changed and *why* in the PR description. Screenshots for
   any UI change (both platforms if it affects layout).

## Project structure

See the "Repository layout" section in [`CLAUDE.md`](CLAUDE.md) for a map of
the codebase and what lives where.

## License

By contributing, you agree your contribution is licensed under the project's
[AGPLv3 license](LICENSE).
