#!/usr/bin/env bash
# Installs LibreNotes server as a systemd service.
# Run as root: sudo bash install.sh
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Run as root: sudo bash install.sh" >&2
  exit 1
fi

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


INSTALL_DIR="/opt/librenotes-server"
DATA_DIR="/var/lib/librenotes"
CONF_DIR="/etc/librenotes-server"
UNIT="/etc/systemd/system/librenotes-server.service"

echo "==> Creating system user 'librenotes'…"
id librenotes &>/dev/null || useradd --system --no-create-home --shell /usr/sbin/nologin librenotes

echo "==> Installing binary and libraries…"
install -dm755 "$INSTALL_DIR"
install -dm755 "$INSTALL_DIR/lib"
install -m755 "$DIR/librenotes-server"     "$INSTALL_DIR/librenotes-server"
install -m755 "$DIR/backup.sh"             "$INSTALL_DIR/backup.sh"
install -m644 "$DIR/lib/libsqlite3.so"     "$INSTALL_DIR/lib/libsqlite3.so"

echo "==> Creating data directory…"
install -dm750 "$DATA_DIR"
chown librenotes:librenotes "$DATA_DIR"

echo "==> Installing config template…"
install -dm755 "$CONF_DIR"
if [ ! -f "$CONF_DIR/env" ]; then
  cat > "$CONF_DIR/env" <<'EOF'
# LibreNotes server configuration — uncomment to override defaults.
# NOTALLY_PORT=8787
# NOTALLY_HOST=0.0.0.0
# NOTALLY_DATA=/var/lib/librenotes
# NOTALLY_TOKEN=your-token-here
EOF
  echo "    Config template written to $CONF_DIR/env"
fi

echo "==> Installing systemd unit…"
install -m644 "$DIR/librenotes-server.service" "$UNIT"
systemctl daemon-reload
systemctl enable --now librenotes-server

echo ""
echo "LibreNotes server is running."
echo ""
echo "Auth token:"
echo "  $(cat "$DATA_DIR/token" 2>/dev/null || echo '(generating on first start — check: sudo cat /var/lib/librenotes/token)')"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status librenotes-server"
echo "  sudo journalctl -u librenotes-server -f"
echo "  sudo /opt/librenotes-server/backup.sh"
