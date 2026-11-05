#!/usr/bin/env bash
# Runs the rootless variant fully locked down: read-only root, no capabilities, no new
# privileges, and a user other than 1000 that owns /config. Checks that a scheduled job
# runs, the container is healthy, and the files it writes are private to that user.
# Usage: test/hardened.sh <image>
set -eo pipefail
image=${1:?Usage: $0 <image>}
uid=1234
name=gyb-hardened-$$
dir=$(mktemp -d)

# The files belong to the container's user, so remove them as root from a container
cleanup() {
  docker rm -f "$name" > /dev/null 2>&1 || true
  docker run --rm --user 0 --entrypoint sh -v "$dir:/c" "$image" -c 'rm -rf /c/* /c/.[!.]*' || true
  rmdir "$dir" || true
}
trap cleanup EXIT
docker run --rm --user 0 --entrypoint sh -v "$dir:/c" "$image" -c "chown $uid:$uid /c && chmod 700 /c"

echo "Hardened: ${image}"
# supercronic supports a seconds field, so run the job every two seconds
docker run -d --name "$name" --read-only --tmpfs /tmp --cap-drop ALL \
  --security-opt no-new-privileges:true --user "$uid:$uid" \
  -e EMAIL=someone@example.com -e 'JOB_EXTRA_CRON=*/2 * * * * * *' \
  -e 'JOB_EXTRA_CMD=/app/gyb --short-version' -v "$dir:/config" "$image" > /dev/null
for _ in $(seq 1 30); do
  docker exec "$name" test -f /config/.last-run 2> /dev/null && break
  sleep 1
done

failures=0
check() { # <description> <command run in the container>
  if ! docker exec "$name" sh -c "$2" > /dev/null 2>&1; then
    echo "  FAIL: $1"
    failures=$((failures + 1))
  fi
}
check "the job ran and succeeded" 'grep -q "^0 " /config/.last-run'
check "the container is healthy" '/app/healthcheck'
check "its result is the user'\''s alone" "[ \"\$(stat -c '%u %a' /config/.last-run)\" = '$uid 600' ]"
check "its data folder is the user's alone" "[ \"\$(stat -c '%u %a' /config/data)\" = '$uid 700' ]"

if [ "$failures" -gt 0 ]; then
  echo "Hardened: ${failures} failed"
  docker logs "$name"
  exit 1
fi
echo "Hardened: passed"
