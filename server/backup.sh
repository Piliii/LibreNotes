#!/usr/bin/env bash
# Back up the LibreNotes SQLite database.
# Safe to run while the server is running (uses SQLite online backup API
# via the .backup command, or stops/copies/restarts as fallback).
set -euo pipefail

DATA_DIR="${NOTALLY_DATA:-/var/lib/librenotes}"
DB="$DATA_DIR/notally.db"
BACKUP_DIR="${LIBRENOTES_BACKUP_DIR:-$DATA_DIR/backups}"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DEST="$BACKUP_DIR/notally-$TIMESTAMP.db"

mkdir -p "$BACKUP_DIR"

if ! [ -f "$DB" ]; then
  echo "Database not found at $DB" >&2
  exit 1
fi

if command -v sqlite3 &>/dev/null; then
  # Online backup — no downtime
  sqlite3 "$DB" ".backup '$DEST'"
  echo "Backup written to $DEST (online)"
else
  # Fallback: stop → copy → start
  echo "sqlite3 not found, falling back to stop/copy/start…"
  systemctl stop librenotes-server
  cp "$DB" "$DEST"
  systemctl start librenotes-server
  echo "Backup written to $DEST (offline)"
fi

# Keep only the 30 most recent backups
ls -t "$BACKUP_DIR"/notally-*.db 2>/dev/null | tail -n +31 | xargs -r rm --
echo "Done. Backups in $BACKUP_DIR:"
ls -lh "$BACKUP_DIR"/notally-*.db | tail -5
