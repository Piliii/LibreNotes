# Security Policy

LibreNotes handles private notes and end-to-end encryption keys. If you find
a security vulnerability, please report it privately — not as a public issue.

## Reporting a vulnerability

Use **[GitHub Private Security Advisories](https://github.com/Piliii/LibreNotes/security/advisories/new)**
for this repository. This lets you share details (and, if needed, a fix)
without exposing the issue publicly before a patch is out.

If that path doesn't work for you, open a regular issue asking for an
alternative contact method — without including any exploit details.

Please include:

- A description of the vulnerability and its impact.
- Steps to reproduce (a minimal example if possible).
- Which component is affected: client (`clients/app/`), server (`server/`),
  or shared models (`packages/notally_core/`).
- Whether it affects the encryption design (client-side crypto in
  `clients/app/lib/sync/note_crypto.dart`) or is a more conventional bug
  (auth, injection, etc.).

## Scope

Particularly interested in reports affecting:

- **Confidentiality of note content** — anything that lets the server, a
  network observer, or another device read plaintext it shouldn't.
- **The E2EE design** — key derivation (Argon2id), key wrapping, AEAD usage
  (XChaCha20-Poly1305), nonce handling.
- **Auth** — the server's bearer-token scheme (`server/lib/api.dart`).
- **Sync/conflict logic** — anything that could corrupt or leak data across
  devices via `/changes`, push/pull, or the conflict-resolution path.

Out of scope: issues that only manifest on a server deliberately exposed to
the public internet against this project's documented LAN/Tailscale-only
guidance, or that require physical access to an unlocked, already-decrypted
device.

## Response

This is a personal-scale project maintained in spare time — there's no SLA,
but security reports get priority over everything else in the backlog. You'll
get an acknowledgment, and credit in the release notes if you'd like it once
a fix ships.
