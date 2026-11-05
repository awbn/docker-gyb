# The rootless variant, published as the `-rootless` tags. GYB runs as whichever user
# the container is started with, nothing needs root, and the root filesystem can be
# read-only. Jobs are scheduled by supercronic. See "Rootless variant" in README.md.
FROM python:3.13-alpine

# Required, so that every image is built from a known GYB release.
ARG GYB_VERSION
ARG GYB_REPO=GAM-team/got-your-back

LABEL org.opencontainers.image.source="https://github.com/awbn/docker-gyb"

RUN set -eu; \
  test -n "${GYB_VERSION}" || { echo "ERROR: build with --build-arg GYB_VERSION=<tag>" >&2; exit 1; }; \
  apk add --no-cache msmtp supercronic tini tzdata; \
  mkdir -p /app/src /config; \
  chown 1000:1000 /config; \
  wget -qO- "https://github.com/${GYB_REPO}/archive/refs/tags/${GYB_VERSION}.tar.gz" \
    | tar -zx --strip-components=1 -C /app/src; \
  pip install --no-cache-dir --requirement /app/src/requirements.txt

COPY rootless/ /
COPY common/ /

ENV PYTHONUNBUFFERED=1 \
    CONFIG_DIR=/config \
    DEST_DIR=/config/data \
    JOB_FULL_CMD='/app/gyb --action backup' \
    JOB_FULL_CRON='0 1 * * SUN' \
    JOB_INC_CMD='/app/gyb --action backup --search "newer_than:3d"' \
    JOB_INC_CRON='0 1 * * MON-SAT' \
    JOB_EXTRA_CMD='' \
    JOB_EXTRA_CRON='' \
    UMASK=077

# The default user; any other can be given with --user. Whoever it is must own /config.
# New volumes get this user from the image; bind mounts need a chown.
USER 1000:1000
VOLUME ["/config"]

HEALTHCHECK --interval=5m --timeout=10s --start-period=1m --retries=1 CMD ["/app/healthcheck"]

ENTRYPOINT ["/sbin/tini", "--", "/app/entrypoint"]
