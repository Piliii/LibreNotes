#!/usr/bin/env bash
# Produces dist/librenotes-server-linux-<arch>.tar.gz
#
# The tarball name is deliberately version-less: the website links to it via
# GitHub's stable /releases/latest/download/<name> URL, which needs an exact,
# unchanging filename. The server's own version (independent of the app's -
# see CLAUDE.md) still ships inside the tarball as a VERSION file.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVER_DIR="$REPO_ROOT/server"
DIST="$REPO_ROOT/dist"

case "$(uname -m)" in
  x86_64) ARCH="x86_64" ;;
  aarch64|arm64) ARCH="arm64" ;;
  *) echo "ERROR: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac
VERSION="$(grep '^version:' "$SERVER_DIR/pubspec.yaml" | sed 's/version: //')"

mkdir -p "$DIST"

# ── 1. Compile ────────────────────────────────────────────────────────────────
echo "==> Compiling server (v${VERSION}, ${ARCH})…"
cd "$SERVER_DIR"
dart pub get
dart compile exe bin/server.dart -o "$DIST/librenotes-server"
echo "    Binary size: $(du -sh "$DIST/librenotes-server" | cut -f1)"
echo "$VERSION" > "$DIST/VERSION"

# ── 2. Tarball ────────────────────────────────────────────────────────────────
TARBALL="librenotes-server-linux-${ARCH}.tar.gz"
echo "==> Creating tarball…"

STAGE="$DIST/.server-stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/librenotes-server"

# Find libsqlite3.so (or .so.0) from the system and bundle it
SQLITE_SO="$(ldconfig -p | grep 'libsqlite3\.so ' | awk '{print $NF}' | head -1)"
SQLITE_SO="${SQLITE_SO:-$(ldconfig -p | grep 'libsqlite3\.so\.0' | awk '{print $NF}' | head -1)}"
if [ -z "$SQLITE_SO" ]; then
  echo "ERROR: libsqlite3 not found on this system. Install it and retry." >&2
  exit 1
fi
echo "    Bundling SQLite: $SQLITE_SO"

mkdir -p "$STAGE/librenotes-server/lib"
cp "$SQLITE_SO" "$STAGE/librenotes-server/lib/libsqlite3.so"

cp "$DIST/librenotes-server"                       "$STAGE/librenotes-server/librenotes-server"
cp "$DIST/VERSION"                                 "$STAGE/librenotes-server/VERSION"
cp "$SERVER_DIR/librenotes-server.service"         "$STAGE/librenotes-server/"
cp "$SERVER_DIR/install.sh"                        "$STAGE/librenotes-server/"
cp "$SERVER_DIR/backup.sh"                         "$STAGE/librenotes-server/"
chmod +x "$STAGE/librenotes-server/install.sh" \
          "$STAGE/librenotes-server/backup.sh"

tar -czf "$DIST/$TARBALL" -C "$STAGE" librenotes-server
rm -rf "$STAGE" "$DIST/librenotes-server" "$DIST/VERSION"
echo "    → $DIST/$TARBALL"

echo ""
echo "Done:"
ls -lh "$DIST/$TARBALL"
