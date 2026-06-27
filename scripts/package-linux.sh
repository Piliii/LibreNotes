#!/usr/bin/env bash
# Produces two artifacts in dist/:
#   LibreNotes-<version>-linux-<arch>.tar.gz   — relocatable bundle + desktop entry
#   LibreNotes-<version>-<arch>.AppImage        — self-contained AppImage
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT="$REPO_ROOT/clients/app"
DIST="$REPO_ROOT/dist"
TOOLS="$REPO_ROOT/.tools"

APP_ID="dev.librenotes.app"
BINARY="librenotes"
ARCH="$(uname -m)"
VERSION="$(grep '^version:' "$CLIENT/pubspec.yaml" | sed 's/version: //;s/+.*//')"
BUNDLE="$CLIENT/build/linux/x64/release/bundle"
DESKTOP="$CLIENT/linux/$APP_ID.desktop"
APPDATA="$CLIENT/linux/$APP_ID.appdata.xml"
ICON="$CLIENT/web/icons/Icon-512.png"

mkdir -p "$DIST" "$TOOLS"

# ── 1. Build ──────────────────────────────────────────────────────────────────
echo "==> Building Flutter Linux release (v${VERSION})…"
cd "$CLIENT"
flutter build linux --release

# ── 2. Tarball ────────────────────────────────────────────────────────────────
TARBALL="LibreNotes-${VERSION}-linux-${ARCH}.tar.gz"
echo "==> Creating tarball…"

STAGE="$DIST/.stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/$BINARY"
cp -r "$BUNDLE/." "$STAGE/$BINARY/"
cp "$DESKTOP"     "$STAGE/$BINARY/$APP_ID.desktop"
cp "$APPDATA"     "$STAGE/$BINARY/$APP_ID.appdata.xml"
cp "$ICON"        "$STAGE/$BINARY/$APP_ID.png"

tar -czf "$DIST/$TARBALL" -C "$STAGE" "$BINARY"
rm -rf "$STAGE"
echo "    → $DIST/$TARBALL"

# ── 3. AppImage ───────────────────────────────────────────────────────────────
echo "==> Building AppImage…"

APPIMAGETOOL="$TOOLS/appimagetool-${ARCH}.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
  echo "    Downloading appimagetool…"
  curl -fsSL -o "$APPIMAGETOOL" \
    "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage"
  chmod +x "$APPIMAGETOOL"
fi

# AppDir layout: Flutter bundle lives under opt/ so its relative lib/ and data/
# paths are preserved. AppRun cd's into it before exec.
APPDIR="$DIST/.AppDir"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/opt/$BINARY"
cp -r "$BUNDLE/."  "$APPDIR/opt/$BINARY/"
cp "$DESKTOP"      "$APPDIR/$APP_ID.desktop"
cp "$ICON"         "$APPDIR/$APP_ID.png"

cat > "$APPDIR/AppRun" <<'APPRUN'
#!/bin/bash
cd "$(dirname "$(readlink -f "$0")")/opt/librenotes"
exec ./librenotes "$@"
APPRUN
chmod +x "$APPDIR/AppRun"

APPIMAGE="LibreNotes-${VERSION}-${ARCH}.AppImage"
ARCH="$ARCH" APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" "$APPDIR" "$DIST/$APPIMAGE"
rm -rf "$APPDIR"
echo "    → $DIST/$APPIMAGE"

echo ""
echo "Done:"
ls -lh "$DIST/$TARBALL" "$DIST/$APPIMAGE"
