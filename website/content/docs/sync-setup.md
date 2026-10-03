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

## HTTPS (optional)

The server speaks plain HTTP. Your notes are encrypted either way, but HTTPS also protects the token and metadata in transit, and is worth setting up before you sync outside your home network. Put a TLS-terminating proxy in front of the server and leave the server itself as it is. Set `NOTALLY_HOST=127.0.0.1` so only the proxy can reach it, then enter the `https://` address as the Server URL in the app.

Use a certificate your devices already trust. A self-signed certificate will make the app refuse to connect.

### Tailscale HTTPS

The simplest option if you already use Tailscale. Enable HTTPS certificates in the Tailscale admin console, then run:

```bash
tailscale serve --bg 8787
```

Your server is now available at `https://<machine>.<tailnet>.ts.net` for devices on your tailnet.

### Caddy

Caddy gets and renews certificates automatically. This works when you own a domain name for the server:

```
notes.example.com {
    reverse_proxy 127.0.0.1:8787
}
```

### nginx

```
server {
    listen 443 ssl;
    server_name notes.example.com;

    ssl_certificate     /etc/letsencrypt/live/notes.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/notes.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8787;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

HTTPS doesn't make it safe to expose the server to the public internet. Keep it on your home network or a private mesh.

## Server settings

The server is configured with environment variables.

| Variable | Default | Meaning |
|---|---|---|
| `NOTALLY_DATA` | `./data` (`/data` in Docker) | Directory for the database and token |
| `NOTALLY_HOST` | `0.0.0.0` | Address to bind |
| `NOTALLY_PORT` | `8787` | Port |
| `NOTALLY_TOKEN` | generated | Bearer token |

Back up the data directory to back up the server.
