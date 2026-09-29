#!/usr/bin/env bash
# Prepare a release: bump the app version and stage the changelog entries.
#
#   scripts/bump-version.sh 1.6.0
#
# - Sets `version: X.Y.Z+N` in clients/app/pubspec.yaml (N = old N + 1).
# - Turns `## [Unreleased]` in CHANGELOG.md into `## [X.Y.Z] — <today>` and
#   leaves a fresh empty `## [Unreleased]` above it.
# - Writes the F-Droid changelog clients/app/fastlane/.../changelogs/N.txt
#   from that section's bullets (edit it by hand if you want shorter text).
#
# Commits, tags and pushes nothing. Prints the commands to run afterwards.
set -euo pipefail

cd "$(dirname "$0")/.."

NEW="${1:-}"
if [[ ! "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "usage: $0 <major.minor.patch>   (e.g. 1.6.0)" >&2
  exit 1
fi

PUBSPEC=clients/app/pubspec.yaml
CHANGELOG=CHANGELOG.md
FASTLANE=clients/app/fastlane/metadata/android/en-US/changelogs

CURRENT=$(sed -n -E 's/^version: ([0-9.]+)\+([0-9]+)$/\1/p' "$PUBSPEC")
CODE=$(sed -n -E 's/^version: ([0-9.]+)\+([0-9]+)$/\2/p' "$PUBSPEC")
if [[ -z "$CURRENT" || -z "$CODE" ]]; then
  echo "error: couldn't parse 'version: X.Y.Z+N' in $PUBSPEC" >&2
  exit 1
fi
if [[ "$NEW" == "$CURRENT" ]]; then
  echo "error: already at $CURRENT" >&2
  exit 1
fi
if grep -q "^## \[$NEW\]" "$CHANGELOG"; then
  echo "error: $CHANGELOG already has a [$NEW] section" >&2
  exit 1
fi
if ! grep -q '^## \[Unreleased\]' "$CHANGELOG"; then
  echo "error: no '## [Unreleased]' heading in $CHANGELOG" >&2
  exit 1
fi

NEWCODE=$((CODE + 1))
TODAY=$(date +%F)

# The Unreleased body: everything between its heading and the next '## ['.
BODY=$(awk '
  /^## \[Unreleased\]/ { on=1; next }
  on && /^## \[/       { exit }
  on                   { print }
' "$CHANGELOG")
if [[ -z "$(echo "$BODY" | tr -d '[:space:]')" ]]; then
  echo "error: '## [Unreleased]' in $CHANGELOG is empty; write the release notes first" >&2
  exit 1
fi

sed -i -E "s/^version: .*/version: $NEW+$NEWCODE/" "$PUBSPEC"
sed -i "s/^## \[Unreleased\]/## [Unreleased]\n\n## [$NEW] — $TODAY/" "$CHANGELOG"

# F-Droid changelog: top-level bullets only, continuation lines joined, and
# F-Droid's 500-byte limit respected.
echo "$BODY" | awk '
  /^- /           { if (line) print line; line=$0; next }
  /^[[:space:]]+[^[:space:]]/ && line { sub(/^[[:space:]]+/, " "); line = line $0; next }
  END { if (line) print line }
' | head -c 500 > "$FASTLANE/$NEWCODE.txt"
echo >> "$FASTLANE/$NEWCODE.txt"

echo "Bumped $CURRENT+$CODE -> $NEW+$NEWCODE"
echo "  $PUBSPEC"
echo "  $CHANGELOG"
echo "  $FASTLANE/$NEWCODE.txt  (check: F-Droid caps this at 500 bytes)"
echo
echo "Next, after reviewing:"
echo "  git commit -am 'chore: release v$NEW'"
echo "  git tag v$NEW && git push && git push origin v$NEW"
