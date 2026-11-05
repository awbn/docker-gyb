#!/usr/bin/env bash
# Tests both images for a tag: <repo>:<tag> and its rootless variant,
# <repo>:<tag>-rootless. Use --only to test just one. CI runs this too.
set -eo pipefail

usage() {
  echo "Usage: $0 [--only default|rootless] <repo>[:<tag>]" >&2
  echo "  e.g. $0 awbn/gyb:1.97" >&2
  exit 1
}

only=""
if [ "$1" = "--only" ]; then only=$2; shift 2 || usage; fi
case "$only" in ""|default|rootless) ;; *) usage ;; esac
[ $# -eq 1 ] || usage

# Split off the tag. Only look after the last '/', since a registry can have a port.
image=$1
if [[ "${image##*/}" == *:* ]]; then repo=${image%:*} tag=${image##*:}; else repo=$image tag=latest; fi
if [ "$tag" = latest ]; then rootless_tag=rootless; else rootless_tag=${tag}-rootless; fi

# Download a pinned container-structure-test for this machine and check its checksum
CST_VERSION=v1.22.1
cst=./container-structure-test-${CST_VERSION}
if [ ! -x "$cst" ]; then
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  case "$(uname -m)" in x86_64|amd64) arch=amd64 ;; arm64|aarch64) arch=arm64 ;; *) arch=$(uname -m) ;; esac
  # A shell under Rosetta reports x86_64 on an Apple Silicon Mac.
  if [ "$os" = darwin ] && [ "$(sysctl -in sysctl.proc_translated)" = 1 ]; then arch=arm64; fi
  name=container-structure-test-${os}-${arch}
  url=https://github.com/GoogleContainerTools/container-structure-test/releases/download/${CST_VERSION}
  echo "Downloading ${name} ${CST_VERSION}..."
  curl -fsSLo "${cst}.tmp" "${url}/${name}"
  sum=$(curl -fsSL "${url}/checksums.txt" | awk -v n="$name" '$2 == n {print $1}')
  [ -n "$sum" ] || { echo "ERROR: no checksum for ${name}" >&2; rm -f "${cst}.tmp"; exit 1; }
  echo "${sum}  ${cst}.tmp" | shasum -a 256 -c - > /dev/null
  chmod +x "${cst}.tmp" && mv "${cst}.tmp" "$cst"
fi

run() {
  echo "Testing $2"
  "$cst" test --config "$1" --config ./test/tests-common.yml --image "$2"
  ./test/mail.sh "$2"
}

[ "$only" = rootless ] || run ./test/tests.yml "${repo}:${tag}"
if [ "$only" != default ]; then
  run ./test/tests-rootless.yml "${repo}:${rootless_tag}"
  ./test/hardened.sh "${repo}:${rootless_tag}"
fi
