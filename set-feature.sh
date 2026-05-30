#!/usr/bin/env bash
# Replace all occurrences of '{feature}' in build.sbt with the given name.
# Usage: ./set-feature.sh <feature-name>
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <feature-name>" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target="$script_dir/build.sbt"

if [ ! -f "$target" ]; then
  echo "Error: $target not found" >&2
  exit 1
fi

# Escape characters that are special on the sed replacement side: \ & and the / delimiter.
escaped=$(printf '%s' "$1" | sed -e 's/[\/&\\]/\\&/g')

sed -i.bak "s/{feature}/$escaped/g" "$target"
rm -f "$target.bak"

echo "Replaced '{feature}' with '$1' in $target"
