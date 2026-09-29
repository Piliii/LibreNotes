#!/usr/bin/env bash
# Builds .deb (Debian/Ubuntu) and .rpm (Fedora/openSUSE) packages from the
# already-built Flutter Linux bundle, using fpm. Called at the end of
# package-linux.sh; can also be run on its own after `flutter build linux`.
#
#   dist/LibreNotes-<version>-<deb-arch>.deb      (amd64 / arm64)
#   dist/LibreNotes-<version>-<rpm-arch>.rpm      (x86_64 / aarch64)
#
# Needs: fpm (gem install fpm), and `rpm` (rpmbuild) for the .rpm.
# If fpm is missing the step is skipped with a note, unless
# REQUIRE_PACKAGES=1 (CI sets it) — then a missing tool is an error.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLIENT="$REPO_ROOT/clients/app"
DIST="$REPO_ROOT/dist"

APP_ID="dev.librenotes.app"
BINARY="librenotes"
VERSION="$(grep '^version:' "$CLIENT/pubspec.yaml" | sed 's/version: //;s/+.*//')"
BUNDLE="$CLIENT/build/linux/x64/release/bundle"
DESKTOP="$CLIENT/linux/$APP_ID.desktop"
APPDATA="$CLIENT/linux/$APP_ID.appdata.xml"
ICON="$CLIENT/web/icons/Icon-512.png"

case "$(uname -m)" in
  x86_64)        DEB_ARCH=amd64; RPM_ARCH=x86_64 ;;
  aarch64|arm64) DEB_ARCH=arm64; RPM_ARCH=aarch64 ;;
  *) echo "error: unsupported architecture $(uname -m)" >&2; exit 1 ;;
esac

missing=()
command -v fpm      >/dev/null || missing+=(fpm)
command -v rpmbuild >/dev/null || missing+=(rpmbuild)
if [ "${#missing[@]}" -gt 0 ]; then
  if [ "${REQUIRE_PACKAGES:-0}" = "1" ]; then
    echo "error: missing tools for .deb/.rpm packaging: ${missing[*]}" >&2
    exit 1
  fi
  echo "==> Skipping .deb/.rpm (missing: ${missing[*]}; install with 'gem install fpm' and your distro's 'rpm' package)"
  exit 0
fi
if [ ! -x "$BUNDLE/$BINARY" ]; then
  echo "error: no Flutter bundle at $BUNDLE — run 'flutter build linux --release' first" >&2
  exit 1
fi

mkdir -p "$DIST"

# ── Package root: /opt bundle + launcher + XDG metadata ─────────────────────
# Same layout as the AUR package (aur/PKGBUILD): the Flutter bundle keeps its
# internal lib/ and data/ paths under /opt/librenotes, with a tiny wrapper on
# PATH.
ROOT="$DIST/.pkgroot"
rm -rf "$ROOT"
install -dm755 "$ROOT/opt/$BINARY" "$ROOT/usr/bin"
cp -r "$BUNDLE/." "$ROOT/opt/$BINARY/"

cat > "$ROOT/usr/bin/$BINARY" <<'EOF'
#!/bin/bash
cd /opt/librenotes
exec ./librenotes "$@"
EOF
chmod 755 "$ROOT/usr/bin/$BINARY"

install -Dm644 "$DESKTOP" "$ROOT/usr/share/applications/$APP_ID.desktop"
install -Dm644 "$ICON"    "$ROOT/usr/share/icons/hicolor/512x512/apps/$APP_ID.png"
install -Dm644 "$APPDATA" "$ROOT/usr/share/metainfo/$APP_ID.appdata.xml"

# ── Shared fpm options ──────────────────────────────────────────────────────
COMMON=(
  -s dir
  -n "$BINARY"
  -v "$VERSION"
  --iteration 1
  --url "https://github.com/Piliii/LibreNotes"
  --license "AGPL-3.0-only"
  --maintainer "Piliii <developer@ayopili.com>"
  --vendor "LibreNotes"
  --description "Private, self-hosted, end-to-end encrypted note-taking app"
  --category "utils"
  -C "$ROOT"
)

# Runtime libraries the bundle links against (GTK, the libsecret keyring, and
# keybinder for the Ctrl+Alt+N quick-capture hotkey). Everything else —
# Flutter engine, SQLite — ships inside the bundle.
echo "==> Building .deb…"
DEB="LibreNotes-${VERSION}-${DEB_ARCH}.deb"
rm -f "$DIST/$DEB"
fpm "${COMMON[@]}" -t deb -a "$DEB_ARCH" \
  --deb-user root --deb-group root \
  -d libgtk-3-0 -d libsecret-1-0 -d libkeybinder-3.0-0 \
  -p "$DIST/$DEB" \
  opt usr

# .rpm dependencies are declared as shared-library capabilities rather than
# package names, because the names differ between Fedora (gtk3, libsecret,
# keybinder3) and openSUSE (libgtk-3-0, libsecret-1-0, libkeybinder-3_0-0)
# while the sonames are the same on both.
echo "==> Building .rpm…"
RPM="LibreNotes-${VERSION}-${RPM_ARCH}.rpm"
rm -f "$DIST/$RPM"
fpm "${COMMON[@]}" -t rpm -a "$RPM_ARCH" \
  --rpm-user root --rpm-group root \
  --rpm-rpmbuild-define '_build_id_links none' \
  -d 'libgtk-3.so.0()(64bit)' \
  -d 'libsecret-1.so.0()(64bit)' \
  -d 'libkeybinder-3.0.so.0()(64bit)' \
  -p "$DIST/$RPM" \
  opt usr

rm -rf "$ROOT"
echo "    → $DIST/$DEB"
echo "    → $DIST/$RPM"
