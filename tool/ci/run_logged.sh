#!/usr/bin/env bash
# Run a command and, when it fails, repeat the end of its output as an error
# annotation. Annotations are readable without downloading the job log.
#
# Usage: bash tool/ci/run_logged.sh <label> <command> [argument...]
set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo "::error::usage: run_logged.sh <label> <command> [argument...]"
  exit 2
fi

label="$1"
shift
log="$(mktemp)"

"$@" 2>&1 | tee "$log"
status="${PIPESTATUS[0]}"

if [ "$status" -ne 0 ]; then
  # Workflow commands need %, CR and LF escaped to keep a multi-line message.
  message="$(tail -n 60 "$log" | tr -d '\r' | sed 's/%/%25/g' | awk '{ printf "%s%%0A", $0 }')"
  echo "::error title=$label failed (exit $status)::$message"
fi
rm -f "$log"
exit "$status"
