#!/usr/bin/env bash
# Builds both images of a GYB release for all platforms: <repo>:<version> and
# <repo>:<version>-rootless. Use --only to build just one. Extra arguments (e.g. --push)
# are passed to docker buildx build.
set -eo pipefail

usage() {
  echo "Usage: $0 [--only default|rootless] <gyb-tag> <repo> [buildx args...]" >&2
  echo "  e.g. $0 v1.97 awbn/gyb --push" >&2
  exit 1
}

only=""
if [ "$1" = "--only" ]; then only=$2; shift 2 || usage; fi
case "$only" in ""|default|rootless) ;; *) usage ;; esac
[ $# -ge 2 ] || usage
tag=$1 repo=$2
shift 2
version=${tag#v}

BUILDER_NAME="gyb-multiplat"

# Clean up stale builders
if docker buildx inspect ${BUILDER_NAME} > /dev/null 2>&1; then
    docker buildx rm ${BUILDER_NAME}
fi

docker buildx create --name ${BUILDER_NAME}
docker buildx use ${BUILDER_NAME}

if [[ "$*" == *"--push"* ]]; then
    if [ -n "$DOCKER_USERNAME" ] && [ -n "$DOCKER_PASSWORD" ]; then
        echo "Logging into docker registry $DOCKER_REGISTRY_URL..."
        echo "$DOCKER_PASSWORD" | docker login --username $DOCKER_USERNAME --password-stdin $DOCKER_REGISTRY_URL
    fi
fi

if [ -z "$PLATFORMS" ]; then
    PLATFORMS="linux/amd64,linux/arm64"
fi

build() {
  local file=$1 image=$2
  shift 2
  echo "Building ${image} (GYB ${tag}, ${PLATFORMS})"
  docker buildx build --platform "$PLATFORMS" --build-arg GYB_VERSION="$tag" \
    -f "$file" -t "$image" "$@" .
}

[ "$only" = rootless ] || build Dockerfile "${repo}:${version}" "$@"
[ "$only" = default ] || build rootless.Dockerfile "${repo}:${version}-rootless" "$@"
