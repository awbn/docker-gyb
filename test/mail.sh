#!/usr/bin/env bash
# The failure mail, end to end, against a fake SMTP server (test/smtp/server.py).
# Usage: test/mail.sh <image>
set -eo pipefail
image=${1:?Usage: $0 <image>}
smtp=$(cd "$(dirname "$0")/smtp" && pwd)

# Runs in the container. Waits for the server to listen, then runs a job that prints 250
# lines, a GYB-style progress line and a last line with no newline, then stops the server.
# shellcheck disable=SC2016 # expanded by the container's shell, not this one
script='python3 /smtp/server.py /tmp/smtp.log & server=$!
for _ in $(seq 1 50); do [ -e /tmp/smtp.log.ready ] && break; sleep 0.1; done
seq 1 250 > /tmp/lines
/app/job sh -c '\''cat /tmp/lines; printf "a\rprogress 1\rprogress 9\r\n"; printf "no newline"; exit 2'\'' > /tmp/out 2>&1
kill "$server" 2> /dev/null; wait
cat /tmp/smtp.log; echo "--- container log"; cat /tmp/out; echo "--- left in /tmp"; ls -A /tmp'

echo "Mail: ${image}"
out=$(docker run --rm -v "$smtp:/smtp:ro" --entrypoint sh -e CONFIG_DIR=/tmp \
  -e MAIL_TO=to@example.com -e MAIL_FROM=from@example.com -e SMTP_HOST=127.0.0.1 \
  -e SMTP_PORT=2525 -e SMTP_TLS=NO -e SMTP_USER=me -e 'SMTP_PASS=p"a\ss w#rd' \
  "$image" -c "$script" 2>&1)

failures=0
expect() { # <grep -E pattern> [absent]
  if grep -qE -- "$1" <<< "$out"; then found=1; else found=0; fi
  if [ "${2:-}" = absent ]; then found=$((1 - found)); fi
  if [ "$found" = 0 ]; then echo "  FAIL: ${2:+no }'$1'"; failures=$((failures + 1)); fi
}
expect '^AUTH \|me\|p"a\\ss w#rd$'
expect '^BODY From: from@example.com$'
expect '^BODY To: to@example.com$'
expect '^BODY Subject: Error running Got Your Back job$'
expect '^BODY 54$'                       # the last 200 lines: 54-250, then three more
expect '^BODY 53$' absent
expect '^BODY progress 9$'
expect '^(BODY )?progress 1$' absent
expect '^BODY no newline$'
expect '^BODY ERROR: job failed with exit code 2'
expect '^progress 9$'                    # the container log too
expect $'\r' absent
expect 'could not send' absent
expect '^tmp\.' absent                   # no configuration or capture left behind

if [ "$failures" -gt 0 ]; then echo "Mail: ${failures} failed"; echo "$out"; exit 1; fi
echo "Mail: passed"
