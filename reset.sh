#!/usr/bin/env bash
# Hard-resets the runtime or SDK worktree to a remote branch picked from a menu.
#
# Usage: ./reset.sh sdk|runtime

set -euo pipefail

usage() {
  echo "Usage: $0 sdk|runtime" >&2
  exit 1
}

[[ $# -eq 1 ]] || usage
case "$1" in
  sdk | runtime) ;;
  *) usage ;;
esac

root="$(cd "$(dirname "$0")" && pwd)"
dir="$(find "$root" -maxdepth 1 -type d -name "*-$1" | head -n 1)"

if [[ -z "$dir" ]]; then
  echo "No folder ending in '-$1' found in $root" >&2
  exit 1
fi


# Shows a filterable, scrollable menu of the arguments and stores the pick in $choice.
select_with_arrows() {
  local options=("$@")
  local height=15
  local width=$(($(tput cols) - 3))
  local query=""
  local selected=0
  local offset=0
  local filtered=()
  local key rest item i line

  shopt -s nocasematch
  tput civis
  trap 'tput cnorm' EXIT

  while true; do
    filtered=()
    for item in "${options[@]}"; do
      [[ -z "$query" || "$item" == *"$query"* ]] && filtered+=("$item")
    done
    local count=${#filtered[@]}

    ((selected >= count)) && selected=$((count > 0 ? count - 1 : 0))
    ((selected < offset)) && offset=$selected
    ((selected >= offset + height)) && offset=$((selected - height + 1))

    printf '\r\e[KFilter: %s  (%d matches)\n' "$query" "$count"
    for ((i = offset; i < offset + height; i++)); do
      if ((i < count)); then
        line="${filtered[i]:0:width}"
        if ((i == selected)); then
          printf '\e[7m> %s\e[0m\e[K\n' "$line"
        else
          printf '  %s\e[K\n' "$line"
        fi
      else
        printf '\e[K\n'
      fi
    done

    IFS= read -rsn1 key
    if [[ $key == $'\e' ]]; then
      read -rsn2 rest
      key+="$rest"
    fi

    case "$key" in
      $'\e[A') ((selected > 0)) && selected=$((selected - 1)) ;;
      $'\e[B') ((selected < count - 1)) && selected=$((selected + 1)) ;;
      $'\x7f' | $'\b') query="${query%?}"; selected=0 ;;
      "") ((count > 0)) && break ;;
      $'\e'*) ;;
      *) query+="$key"; selected=0 ;;
    esac

    printf '\e[%dA' $((height + 1))
  done

  shopt -u nocasematch
  tput cnorm
  choice="${filtered[selected]}"
}


cd "$dir"
branch="$(git rev-parse --abbrev-ref HEAD)"

echo "Folder: $dir"
echo "Branch: $branch"
echo
echo "Fetching remotes..."
git fetch --all --prune --quiet

branches=()
while IFS= read -r ref; do
  branches+=("$ref")
done < <(git for-each-ref --format='%(refname:short)' refs/remotes | grep -v '/HEAD$' | sort)

echo
echo "Type to filter, ↑/↓ to move, Enter to select, Ctrl-C to quit."
select_with_arrows "${branches[@]}"


echo
if [[ -n "$(git status --porcelain)" ]]; then
  echo "WARNING: the working tree has uncommitted changes. They will be lost."
fi
read -rp "Hard-reset '$branch' to '$choice'? [y/N] " answer
[[ "$answer" == [yY] ]] || { echo "Aborted."; exit 1; }

git reset --hard "$choice"
cd ..
