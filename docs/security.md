# Security and threat model

This document describes what LibreNotes protects, from whom, and where the
protection stops. To report a vulnerability, see [`SECURITY.md`](../SECURITY.md).

> **Not independently audited.** The cryptography is a small amount of
> client-side code on top of the [`cryptography`](https://pub.dev/packages/cryptography)
> package (`clients/app/lib/sync/note_crypto.dart`), using standard primitives
> in a standard construction. No third party has reviewed it. Treat LibreNotes
> as a careful personal project, not as audited software, and don't rely on it
> where a failure would be dangerous. A review of `note_crypto.dart` is welcome;
> see [`SECURITY.md`](../SECURITY.md).

## Deployment assumption

LibreNotes is built for **one person with a few devices and one self-hosted
server on a home network**. The server is meant to be reachable only on the LAN
or over a private mesh (Tailscale/WireGuard). It is **not** designed to be
exposed to the public internet, and nothing here should be read as a claim that
it is safe to do so.

## What is protected

Note content: the **title, body, pinned state, color, creation and edit times,
archived state and self-destruct timer** are all inside one encrypted payload
per note. The server never receives a key and never sees these values.

## Who the attacker is

| Attacker | What they can do | What they can't do |
|---|---|---|
| **Passive network observer** on the LAN | See that a client talks to the server, request sizes and timing. If the server is plain `http://` (the default), they also see the bearer token. | Read note content (it is ciphertext before it leaves the device). |
| **Someone with the bearer token only** | Pull every ciphertext, push, delete and purge notes, overwrite the keystore. | Read any note. The token is not a key. |
| **Someone with the server's disk or backups** (stolen box, backup tarball, hosting provider) | Everything in the next section, plus an **offline guess attack on the passphrase** (see below). | Read notes without the passphrase. |
| **A malicious or compromised server** | Withhold, delete, reorder, roll back or swap ciphertexts (see limitations). | Read or forge note *content*. |
| **Someone with access to an unlocked device** | Read everything on it. | n/a, out of scope. |

## What the server sees

The server stores, per note: a random UUID, the ciphertext and its nonce, `rev`,
`seq`, the `deleted` and `purged` flags, and a server-clock `updatedAt`. It also
stores the keystore row: wrapped DEK, salt and KDF parameters.

From that it can learn: **how many notes you have, when each was last
changed, how often you write, which are in the trash or purged, and roughly how
large each note is** (ciphertext length tracks plaintext length; there is no
padding). It cannot learn titles, text, colors, archive state or timers.

## Key hierarchy

```
passphrase ──Argon2id(salt, m=19456 KiB, t=2, p=1)──▶ KEK (256-bit)
                                                        │ XChaCha20-Poly1305
random 256-bit DEK ──────────── wrapped ───────────────▶ wrapped DEK ─▶ server keystore
        │
        └─ XChaCha20-Poly1305, fresh 192-bit nonce per write ─▶ note ciphertext ─▶ server
```

- **DEK (data-encryption key).** One random 256-bit key per account, shared by
  all devices. It encrypts every note payload. Each write uses a fresh random
  nonce.
- **KEK (key-encryption key).** Derived from the passphrase with Argon2id and a
  random 16-byte salt. It is used only to wrap and unwrap the DEK, then discarded.
- **Keystore.** The wrapped DEK, salt and KDF parameters live on the server.
  A new device downloads them and needs only the passphrase to recover the DEK.
  A wrong passphrase fails authentication and is reported as "Wrong passphrase".
- **Passphrase and keys never leave the device** in usable form. Crypto is
  client-only; the server contains no crypto code.
- **On-device storage.** Each device keeps the raw DEK in the platform keyring
  (`flutter_secure_storage`) and stores note title/body encrypted under it. If the
  keyring is unreadable and encrypted notes exist, the app refuses to mint a new
  key and offers passphrase recovery instead, so notes are never silently
  orphaned.

## Known limitations

These are real and deliberate to list. None is hidden by the design.

1. **The passphrase is the whole security of your notes against anyone who
   gets the server data.** The wrapped DEK and salt are not secret from the
   server, so whoever holds them can try passphrases offline, and the bearer
   token does nothing to stop that. Argon2id at the default cost (OWASP's
   minimum-style setting, tuned to be comfortable on phones) slows each guess
   but cannot save a weak passphrase. **Use a long, random passphrase.** The app
   does not enforce a strength minimum.
2. **No ciphertext binding.** Note ciphertexts carry no associated data tying
   them to the note id or `rev`. A malicious server (or anyone who can write to
   it) can swap two notes' ciphertexts, or serve an older ciphertext of a note
   again. The client would decrypt it successfully. Confidentiality holds;
   *integrity of which-content-belongs-where and freshness* does not.
3. **The server can lie by omission.** It can drop notes, hide changes, or stop
   propagating deletes. Clients have no way to detect this.
4. **Sizes and timing leak** (see above). No padding, no batching.
5. **Plain HTTP by default.** On an untrusted network the bearer token can be
   sniffed. Put the server behind a TLS reverse proxy or Tailscale HTTPS
   (see the HTTPS section of the server setup docs).
6. **The bearer token is a single shared secret.** It is compared with a plain
   string equality (not constant-time), there is no rate limiting, and it cannot
   be rotated without editing the server's token file or `NOTALLY_TOKEN`. Anyone
   holding it can overwrite the keystore (`PUT /keystore` replaces the row
   unconditionally), which locks every device out of sync until it is restored
   from a backup. Notes already on a device stay readable.
7. **No passphrase change or key rotation yet.** The DEK is for life. If you
   suspect it leaked, the only remedy today is to create a new account/server and
   migrate notes.
8. **Local device protection is only as strong as the OS keyring** and the OS's
   disk protection. A user-level attacker on an unlocked desktop session can read
   the keyring.
9. **Exports are separate.** Markdown import/export writes plaintext files by
   design; protect those yourself.
10. **Memory and side channels** (swap, core dumps, clipboard, screenshots) are
    out of scope.

## Out of scope

Nation-state adversaries, malware on your devices, a compromised build or
supply chain, coercion, and anything that needs the server exposed to the
public internet.

## Verifying for yourself

The whole scheme is in one file, `clients/app/lib/sync/note_crypto.dart`, and
the server's role is in `server/lib/api.dart` and `server/lib/db.dart`. The
sync end-to-end test (`clients/app/test/sync_e2e_test.dart`) runs the real
server in-process and asserts the plaintext is absent from what the server
stores.
