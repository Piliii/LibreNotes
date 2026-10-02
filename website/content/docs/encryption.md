# Encryption & privacy

## What protects your notes

- Each note is encrypted with a random 256-bit key using XChaCha20-Poly1305.
- That key is itself locked by a key derived from your passphrase with Argon2id.
- Encryption and decryption happen only on your devices.
- On each device, notes are also encrypted in the local database, with the key kept in the system keyring.

## What the server can see

The server stores only encrypted note contents. It can see:

- note IDs, revision numbers and timestamps
- whether a note is deleted
- how large each encrypted note is, and when it changes

It cannot see titles, bodies, colors, pinned or archived state, or timers. Those all live inside the encrypted payload.

## What LibreNotes collects

Nothing. There are no accounts, analytics, ads or trackers. See the [privacy policy](/privacy) for details.

## Transport security

Sync works over plain `http://` on a home network. Your notes are still encrypted, but the token and some metadata travel unprotected, and someone on the network path could tamper with data. Off your home network, use a private network such as Tailscale or WireGuard, or put the server behind an HTTPS reverse proxy.
