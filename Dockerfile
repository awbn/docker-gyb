ARG GYB_VERSION
ARG ALPINE_VERSION=3.13

FROM ghcr.io/linuxserver/baseimage-alpine:$ALPINE_VERSION

ENV PYTHONUNBUFFERED=1 \
    JOB_FULL_CMD='/app/gyb --action backup' \
    JOB_FULL_CRON='0 1 * * SUN' \
    JOB_INC_CMD='/app/gyb --action backup --search "newer_than:3d"' \
    JOB_INC_CRON='0 1 * * MON-SAT' \
    JOB_EXTRA_CMD='' \
    JOB_EXTRA_CRON=''

RUN \
  echo "**** install packages ****" && \ 
  apk add --no-cache \
	  curl \
 	  py3-pip \
  	jq \
    ssmtp \
    git  && \
  if [ -z ${GYB_VERSION+x} ]; then \
	  GYB_VERSION=$(curl -sX GET https://api.github.com/repos/jay0lee/got-your-back/releases/latest \
	  | jq -r '.tag_name'); \
  fi && \
  echo "**** install Got-Your-Back ${GYB_VERSION} ****" && \
  git config --global advice.detachedHead false && \
  git clone --depth 1 \
  	--branch ${GYB_VERSION} \
	  https://github.com/jay0lee/got-your-back.git \
	  /app/src && \
  rm -r /app/src/.git && \
  pip3 install --requirement /app/src/requirements.txt

COPY root/ /
VOLUME ["/config"]