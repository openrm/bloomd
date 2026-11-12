############
# BUILDER - Used to build the bloomd binary
############

FROM cgr.dev/chainguard/wolfi-base:latest as BUILDER

WORKDIR /etc/bloomd

RUN apk add --no-cache build-base gcc scons

COPY deps deps

RUN cd deps/check-0.9.8 && ./configure CFLAGS="-fcommon" && make && make install

RUN cd /etc/bloomd

COPY src src
COPY SConstruct SConstruct

RUN scons


############
# RUNNER - Use Bloomd binary generated in the builder above
############

# Base pinned by digest (the tag stays for humans and for Dependabot's docker updates).
FROM cgr.dev/chainguard/busybox:latest-glibc@sha256:01c4029ff15de19e67307803fa8c4e8c913f71048c854303c80cc7bbca2323d7 as RUNNER

# Chainguard images default to a non-root user; the setup steps below need root, the final USER drops it again.
USER root
WORKDIR /etc/bloomd
# The configuration is written at start-up, to /tmp, so the container can run as a non-root user
# with a read-only root filesystem (only /tmp and /data are writable then).
RUN mkdir /data

ENV BLOOMD_PORT=8673
ENV BLOOMD_LOG_LEVEL=INFO
ENV BLOOMD_DATA_DIR=/data
ENV BLOOMD_FLUSH_INTERVAL=300
ENV BLOOMD_WORKERS=2

COPY --from=BUILDER /etc/bloomd/bloomd /etc/bloomd/bloomd

RUN printf "#!/bin/sh\n\
printf \"[bloomd]\\ntcp_port = \$BLOOMD_PORT\\ndata_dir = \$BLOOMD_DATA_DIR\\nlog_level = \$BLOOMD_LOG_LEVEL\\nflush_interval = \$BLOOMD_FLUSH_INTERVAL\\nworkers = \$BLOOMD_WORKERS\" > /tmp/bloomd.conf \n \
./bloomd -f /tmp/bloomd.conf" > entry.sh

RUN chmod +x entry.sh

# A numeric id, so that the kubelet can verify runAsNonRoot (a named user cannot be verified). /data is a mount point:
# on Kubernetes the volume gets this group through fsGroup.
RUN chown 1000:1000 /data
USER 1000:1000

CMD ["./entry.sh"]
