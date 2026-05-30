#!/usr/bin/env bash
# Replace all occurrences of '{feature}' in build.sbt and .gitignore with the given name.
# Usage: ./set-feature.sh <feature-name>
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <feature-name>" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
targets=("$script_dir/build.sbt" "$script_dir/.gitignore" "$script_dir/CLAUDE.md")

for target in "${targets[@]}"; do
  if [ ! -f "$target" ]; then
    echo "Error: $target not found" >&2
    exit 1
  fi
done

# Escape characters that are special on the sed replacement side: \ & and the / delimiter.
escaped=$(printf '%s' "$1" | sed -e 's/[\/&\\]/\\&/g')

for target in "${targets[@]}"; do
  sed -i.bak "s/{feature}/$escaped/g" "$target"
  rm -f "$target.bak"
  echo "Replaced '{feature}' with '$1' in $target"
done
