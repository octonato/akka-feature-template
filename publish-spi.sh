#!/usr/bin/env bash
# Publishes the runtime worktree locally and points the SDK worktree at that version.
#
# Usage: ./publish-spi.sh

set -euo pipefail

root="$(cd "$(dirname "$0")" && pwd)"
runtime_dir="$(find "$root" -maxdepth 1 -type d -name "*-runtime" | head -n 1)"
sdk_dir="$(find "$root" -maxdepth 1 -type d -name "*-sdk" | head -n 1)"

if [[ -z "$runtime_dir" ]]; then
  echo "No folder ending in '-runtime' found in $root" >&2
  exit 1
fi

if [[ -z "$sdk_dir" ]]; then
  echo "No folder ending in '-sdk' found in $root" >&2
  exit 1
fi

if [[ ! -x "$sdk_dir/updateRuntimeVersions.sh" ]]; then
  echo "$sdk_dir/updateRuntimeVersions.sh not found or not executable" >&2
  exit 1
fi


publish_log="$(mktemp)"
trap 'rm -f "$publish_log"' EXIT

echo ">>> Publishing runtime locally (publishM2 + publishLocal) in $runtime_dir..."
(cd "$runtime_dir" && sbt ";publishM2;publishLocal") | tee "$publish_log"

# Reads the version from a line like:
#   :: delivering :: io.akka#akka-runtime-core_2.13;1.6.0-16-c58f7461-SNAPSHOT :: ...
version="$(grep -oE 'akka-runtime-core_2\.13;[^ ]+' "$publish_log" | head -n 1 | sed 's/.*;//')"

if [[ -z "$version" ]]; then
  echo "Could not read the published version from the sbt output" >&2
  exit 1
fi


echo ">>> Published version: $version"
echo ">>> Updating SDK dependencies in $sdk_dir..."
(cd "$sdk_dir" && ./updateRuntimeVersions.sh "$version")

echo ">>> Done."
