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

RUN useradd -r -s /bin/false librenotes && \
    mkdir -p /data && \
    chown librenotes:librenotes /data

VOLUME ["/data"]
EXPOSE 8787
ENV NOTALLY_DATA=/data

USER librenotes
ENTRYPOINT ["/usr/local/bin/librenotes-server"]
