############
# BUILDER - Used to build the bloomd binary
############

FROM debian:13-slim AS builder

WORKDIR /etc/bloomd

RUN apt-get update && \
    apt-get install -y --no-install-recommends build-essential scons && \
    rm -rf /var/lib/apt/lists/*

COPY deps deps

RUN cd deps/check-0.9.8 && ./configure CFLAGS="-fcommon" && make && make install

COPY src src
COPY SConstruct SConstruct

RUN scons

COPY docker/entrypoint.c docker/entrypoint.c
RUN gcc -O2 -Wall -o entrypoint docker/entrypoint.c

# The data directory is created here: the runtime image has no shell to do it.
RUN mkdir /data


############
# RUNNER - Distroless: no shell, no package manager, non-root (uid 65532)
############

# Base pinned by digest (the tag stays for humans and for Dependabot's docker updates).
FROM gcr.io/distroless/base-debian13:nonroot@sha256:7fe4df6a4413adf5889960d345a28b4574aea0872ea47684c7244c8d88027dca AS runner

WORKDIR /etc/bloomd

ENV BLOOMD_PORT=8673
ENV BLOOMD_LOG_LEVEL=INFO
ENV BLOOMD_DATA_DIR=/data
ENV BLOOMD_FLUSH_INTERVAL=300
ENV BLOOMD_WORKERS=2

COPY --from=builder /etc/bloomd/bloomd /etc/bloomd/bloomd
COPY --from=builder /etc/bloomd/entrypoint /etc/bloomd/entrypoint

# A numeric id, so that the kubelet can verify runAsNonRoot. /data is a mount point:
# on Kubernetes the volume gets this group through fsGroup.
COPY --from=builder --chown=65532:65532 /data /data
USER 65532:65532

# The configuration is written at start-up, to /tmp, so the root filesystem can be read-only
# (only /tmp and /data need to be writable).
ENTRYPOINT ["/etc/bloomd/entrypoint"]
