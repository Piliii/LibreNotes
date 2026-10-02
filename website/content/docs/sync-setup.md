# Set up sync

Sync needs three things: a **server address**, a **token**, and a **passphrase**.

- The **address and token** let your device talk to your server.
- The **passphrase** unlocks your notes. It never leaves your device, and the server never sees it. Use the same passphrase on every device.

> Sync servers are meant for your home network or a private network such as Tailscale or WireGuard. Don't expose one directly to the public internet.

## 1. Run the server

### With Docker

```bash
curl -Lo docker-compose.yml https://librenotes.ayopili.com/dl/docker-compose
docker compose up -d
docker compose logs
```

The token is printed on first start and saved in the data volume. To choose your own, set `NOTALLY_TOKEN` in the compose file.

### On Linux with systemd

```bash
curl -L https://librenotes.ayopili.com/dl/server | tar -xzf -
cd librenotes-server
sudo bash install.sh
```

The installer creates a dedicated unprivileged user and a systemd service, and prints the token. You can read it again with `sudo cat /var/lib/librenotes/token`. On a Raspberry Pi, use `/dl/server-arm64` instead.

## 2. Connect the app

Open **Settings → Sync** and enter:

```
Server URL:  http://<server-ip>:8787
Token:       <your token>
Passphrase:  <choose one, and remember it>
```

The first device you connect creates your key. On your other devices, enter the same URL, token and passphrase.

> **If you forget the passphrase, your synced notes can't be recovered.** The server can't reset it, because it never had it.

## Server settings

The server is configured with environment variables.

| Variable | Default | Meaning |
|---|---|---|
| `NOTALLY_DATA` | `./data` (`/data` in Docker) | Directory for the database and token |
| `NOTALLY_HOST` | `0.0.0.0` | Address to bind |
| `NOTALLY_PORT` | `8787` | Port |
| `NOTALLY_TOKEN` | generated | Bearer token |

Back up the data directory to back up the server.
