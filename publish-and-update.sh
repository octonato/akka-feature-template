#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $(basename "$0") <runtime-dir> <sdk-dir>" >&2
  exit 1
fi

RUNTIME_DIR="$1"
SDK_DIR="$2"

for d in "$RUNTIME_DIR" "$SDK_DIR"; do
  if [[ ! -d "$d" ]]; then
    echo "ERROR: not a directory: $d" >&2
    exit 1
  fi
done

PUBLISH_LOG=$(mktemp)
trap 'rm -f "$PUBLISH_LOG"' EXIT

echo ">>> Publishing runtime locally (sbt pub) in $RUNTIME_DIR..."
(cd "$RUNTIME_DIR" && sbt ";publishM2;publishLocal") | tee "$PUBLISH_LOG"

# Parse a line like:
#   :: delivering :: io.akka#akka-runtime-core_2.13;1.6.0-16-c58f7461-SNAPSHOT :: 1.6.0-16-c58f7461-SNAPSHOT :: ...
VERSION=$(grep -oE 'akka-runtime-core_2\.13;[^ ]+' "$PUBLISH_LOG" | head -1 | sed 's/.*;//')

if [[ -z "$VERSION" ]]; then
  echo "ERROR: could not extract published version from sbt output" >&2
  exit 1
fi

echo ">>> Published version: $VERSION"
echo ">>> Updating SDK dependencies in $SDK_DIR..."
(cd "$SDK_DIR" && ./updateRuntimeVersions.sh "$VERSION")

echo ">>> Done."
