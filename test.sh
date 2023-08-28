#!/usr/bin/env bash

set -eo pipefail

# Temporarily set the path to incude local dir
PATH=$PATH:${PWD}

if ! command -v container-structure-test &> /dev/null ; then
  echo "Downloading container-structure-test..."
  PLAT=$(uname -s | awk '{print tolower($0)}')
  curl -Lo "container-structure-test" \
    https://storage.googleapis.com/container-structure-test/latest/container-structure-test-${PLAT}-amd64
  chmod +x ./container-structure-test
fi

container-structure-test test --config ./test/tests.yml --image $@
