FROM ghcr.io/linuxserver/baseimage-alpine:3.15-version-a0482dc2

ARG GYB_VERSION
LABEL org.opencontainers.image.source="https://github.com/awbn/docker-gyb"

ENV PYTHONUNBUFFERED=1 \
    JOB_FULL_CMD='/app/gyb --action backup' \
    JOB_FULL_CRON='0 1 * * SUN' \
    JOB_INC_CMD='/app/gyb --action backup --search "newer_than:3d"' \
    JOB_INC_CRON='0 1 * * MON-SAT' \
    JOB_EXTRA_CMD='' \
    JOB_EXTRA_CRON='' \
    UMASK=077

RUN \
  echo "**** install packages ****" && \ 
  apk add --no-cache \
    curl \
    jq \
    py3-pip \
    ssmtp && \
  if [ -z "${GYB_VERSION}" ]; then \
    GYB_VERSION=$(curl -sX GET https://api.github.com/repos/jay0lee/got-your-back/releases/latest \
    | jq -r '.tag_name'); \
  fi && \
  echo "**** install Got-Your-Back ${GYB_VERSION} ****" && \  
  mkdir -p /app/src && \ 
  curl -sLX GET https://github.com/jay0lee/got-your-back/archive/refs/tags/${GYB_VERSION}.tar.gz \
    | tar -zx --strip-components=1 -C /app/src \
    || { echo "ERROR: Could not find GYB Release '${GYB_VERSION}'" >&2 && exit 1; } && \
  pip3 install --no-cache-dir --requirement /app/src/requirements.txt

COPY root/ /
VOLUME ["/config"]