#!/usr/bin/env bash

BUILDER_NAME="gyb-multiplat"

# Clean up stale builders
if docker buildx inspect ${BUILDER_NAME} > /dev/null; then
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

docker buildx build --platform $PLATFORMS . $*
