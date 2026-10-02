# syntax=docker/dockerfile:1
# Build context must be the repo root so the notally_core path dep is available.

FROM dart:stable AS builder

WORKDIR /build
COPY packages/notally_core packages/notally_core
COPY server server

WORKDIR /build/server
RUN dart pub get && \
    dart compile exe bin/server.dart -o /librenotes-server

# ── Runtime ───────────────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends libsqlite3-0 && \
    rm -rf /var/lib/apt/lists/* && \
    SQLITE_LIB="$(find / -xdev -name 'libsqlite3.so.0' 2>/dev/null | head -1)" && \
    ln -s "$SQLITE_LIB" "$(dirname "$SQLITE_LIB")/libsqlite3.so"

COPY --from=builder /librenotes-server /usr/local/bin/librenotes-server
COPY server/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh

# Fixed UID/GID so ownership of a bind-mounted or pre-existing volume is
# predictable across image rebuilds.
RUN groupadd -r -g 10001 librenotes && \
    useradd -r -u 10001 -g 10001 -s /bin/false librenotes && \
    mkdir -p /data && \
    chown librenotes:librenotes /data && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

VOLUME ["/data"]
EXPOSE 8787
ENV NOTALLY_DATA=/data

# Starts as root only so the entrypoint can fix /data ownership (a fresh
# volume mounted by a host is usually root-owned), then drops to `librenotes`.
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["/usr/local/bin/librenotes-server"]

HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD ["/usr/local/bin/librenotes-server", "--healthcheck"]
