#!/bin/sh
# Container entrypoint. If started as root, make sure the data dir is writable
# by the unprivileged `librenotes` user, then drop privileges and exec the
# server. If started as a non-root user (docker run --user / hosts that force a
# UID), just exec — ownership is then the host's responsibility.
set -e

if [ "$(id -u)" = "0" ]; then
  data="${NOTALLY_DATA:-/data}"
  mkdir -p "$data"
  # Only walk the tree when the top level isn't already ours (keeps restarts fast).
  if [ "$(stat -c %u "$data")" != "$(id -u librenotes)" ]; then
    chown -R librenotes:librenotes "$data" ||
      echo "warning: could not chown $data; the server may fail to write to it" >&2
  fi
  exec setpriv --reuid=librenotes --regid=librenotes --init-groups "$@"
fi

exec "$@"
