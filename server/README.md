# LibreNotes sync server

Self-hosted, end-to-end-encryption-**blind** sync server for LibreNotes. It
stores only ciphertext blobs plus the metadata needed to sync (`rev`, `seq`,
tombstones, purge state). It runs on your home server and binds to the LAN —
never expose it to the internet (use Tailscale/WireGuard for remote access;
that's just a client base-URL change, no server code change).

## Run

```bash
dart pub get
dart run bin/server.dart
```

Dart ships with the Flutter SDK — add it to PATH first if needed:
`export PATH="$PATH:/path/to/flutter/bin"`

On first start it prints a randomly generated bearer **token** (also saved to
`data/token`). Every request except `/health` needs `Authorization: Bearer <token>`.

Config via env: `NOTALLY_DATA` (dir), `NOTALLY_HOST` (default `0.0.0.0`),
`NOTALLY_PORT` (default `8787`), `NOTALLY_TOKEN` (override the token).

## API

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | liveness (no auth) |
| GET | `/changes?since=<seq>` | delta pull: notes with `seq > since` + `latestSeq` |
| PUT | `/notes/<id>` | create/update; body `{ciphertext, nonce, baseRev}`; **409** on stale `baseRev` |
| DELETE | `/notes/<id>?baseRev=<n>` | tombstone; **409** on stale `baseRev` |
| DELETE | `/notes/<id>/purge` | permanent purge (no conflict check); propagates to all devices |
| GET / PUT | `/keystore` | the wrapped-DEK + KDF-params bundle |

`ciphertext`/`nonce` are base64 in JSON. A conflict (409) returns the server's
current version of the note so the client can show both and let you pick.

## Quick smoke test

```bash
TOKEN=$(cat data/token)
H="Authorization: Bearer $TOKEN"

curl -s localhost:8787/health
curl -s -X PUT localhost:8787/notes/n1 -H "$H" \
  -d '{"ciphertext":"aGVsbG8=","nonce":"AAAA","baseRev":0}'
curl -s "localhost:8787/changes?since=0" -H "$H"
```

## Test

```bash
dart test
```

## Compile to a single binary (for systemd)

```bash
dart compile exe bin/server.dart -o librenotes-server
```
