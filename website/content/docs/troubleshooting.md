# Troubleshooting

## The app can't reach my server

- Check the address includes `http://` and the port (`:8787` by default).
- Your phone and the server must be on the same network, or both on your private network (Tailscale or WireGuard).
- Open `http://<server-ip>:8787/health` in a browser. If the server is running, it answers without a token.

## I lost my token

Docker: `docker compose logs`, or set `NOTALLY_TOKEN` yourself.
systemd install: `sudo cat /var/lib/librenotes/token`.

## I forgot my passphrase

Synced notes can't be decrypted without it, and it can't be reset. Notes still stored on a device that's already unlocked stay readable there: export them as Markdown, then set up sync again with a new server and passphrase.

## The app says it is outdated, or the server version doesn't match

Update the app and the server to their latest releases.

## Something else

Open an issue on [GitHub](https://github.com/Piliii/LibreNotes/issues).
