#!/usr/bin/env bash
#
# akka-feature.sh — create / close an Akka "feature" workspace made of three
# linked git worktrees: a feature root, the SDK and the runtime.
#
# Source this file from your shell to get the `akka.new.feature` and
# `akka.close.feature` functions.
#
# Required environment variables:
#   AKKA_FEATURE_DIR    path to the feature template repo. Feature worktrees are
#                       created as siblings of this directory.
#   AKKA_SDK_DIR        path to the Akka SDK checkout used as the worktree base.
#   AKKA_RUNTIME_DIR    path to the Akka runtime checkout used as the worktree base.
#
# Optional environment variables:
#   GH_USER_PREFIX      prefix prepended to every created branch name.
#
# See README.md for setup instructions.

# Verify the required configuration is present before doing any work.
_akka_require_env() {
  local missing=0
  [ -z "$AKKA_FEATURE_DIR" ] && { echo "akka-feature.sh: AKKA_FEATURE_DIR is not set" >&2; missing=1; }
  [ -z "$AKKA_SDK_DIR" ]      && { echo "akka-feature.sh: AKKA_SDK_DIR is not set" >&2; missing=1; }
  [ -z "$AKKA_RUNTIME_DIR" ]  && { echo "akka-feature.sh: AKKA_RUNTIME_DIR is not set" >&2; missing=1; }
  return $missing
}

# ----------------------------------------------------------------------------
# git-worktree helpers
# ----------------------------------------------------------------------------

# Print the current branch name of the repository in the current directory.
_akka_git_current_branch() {
  git rev-parse --abbrev-ref HEAD 2>/dev/null
}

# Create a worktree for a new branch, cd into it, and pull from upstream.
# If GH_USER_PREFIX is set it is prepended to the branch name.
# Accepts either a bare name (worktree created as ../<name>) or a path
# containing a slash (used verbatim as the worktree location).
_akka_git_worktree() {
  if [ ! -d .git ]; then
    echo "Not a git repository"
    return 1
  fi

  local name="$1"
  if [ -z "$name" ]; then
    echo "usage: _akka_git_worktree <name|path>"
    return 1
  fi

  local base_branch=$(_akka_git_current_branch)
  local worktree_path
  case "$name" in
    */*) worktree_path="$name" ;;
    *)   worktree_path="../$name" ;;
  esac
  local branch_name=$(basename "$name")

  git worktree add -b "${GH_USER_PREFIX}${branch_name}" "$worktree_path"
  cd "$worktree_path"

  echo "pulling from upstream ${base_branch}..."
  git pull upstream "$base_branch"
}

# Check a git directory for potential data loss.
# Returns warnings via stdout. Empty output means safe to delete.
_akka_check_data_loss() {
  local dir="$1"
  local warnings=""

  if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
    warnings="${warnings}  - Has uncommitted/unstaged changes\n"
  fi

  local remote_branch=$(git -C "$dir" rev-parse --abbrev-ref @{upstream} 2>/dev/null)
  if [ -z "$remote_branch" ]; then
    warnings="${warnings}  - No remote tracking branch (no backup)\n"
  else
    git -C "$dir" fetch --quiet 2>/dev/null
    local local_rev=$(git -C "$dir" rev-parse HEAD 2>/dev/null)
    local remote_rev=$(git -C "$dir" rev-parse @{upstream} 2>/dev/null)
    if [ "$local_rev" != "$remote_rev" ]; then
      warnings="${warnings}  - Local differs from remote (unpushed commits)\n"
    fi
  fi

  printf '%b' "$warnings"
}

# Prompt the user if there are data loss warnings.
# Pass a non-empty second argument to skip the prompt (assume "yes").
# Returns 0 if safe to proceed, 1 if aborted.
_akka_confirm_data_loss() {
  local dir="$1"
  local skip_confirm="$2"

  [ -n "$skip_confirm" ] && return 0

  local warnings=$(_akka_check_data_loss "$dir")

  if [ -n "$warnings" ]; then
    echo "Warning: potential data loss in $dir:"
    printf '%b' "$warnings"
    printf 'Continue? (y/N) '
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
      echo "Aborted."
      return 1
    fi
  fi
  return 0
}

# Remove a worktree and its branch.
# Pass a non-empty second argument to skip the data-loss confirmation.
_akka_worktree_remove() {
  if [ -d .git ]; then
    if [ "$1" ]; then
      local WORKTREE_PATH="$1"
      local skip_confirm="$2"
      local BRANCH_NAME=$(git -C "$WORKTREE_PATH" rev-parse --abbrev-ref HEAD 2>/dev/null)

      _akka_confirm_data_loss "$WORKTREE_PATH" "$skip_confirm" || return 0

      git worktree remove --force "$WORKTREE_PATH"
      if [ "$BRANCH_NAME" != "HEAD" ] && [ -n "$BRANCH_NAME" ]; then
        git branch -D "$BRANCH_NAME"
      fi
    else
      echo "path must be passed, usage: _akka_worktree_remove ../some-name"
    fi
  else
    echo "Not a git repository"
  fi
}

# Delete a branch directory, handling both worktrees and hard forks.
# Pass a non-empty second argument to skip the data-loss confirmation.
_akka_delete_branch() {
  local dir="$1"
  local skip_confirm="$2"
  if [ ! -d "$dir" ]; then
    echo "Directory not found: $dir"
    return 1
  fi

  if [ -f "$dir/.git" ]; then
    # It's a worktree, remove it properly from the main worktree
    local WORKTREE_PATH=$(git -C "$dir" rev-parse --show-toplevel)
    local MAIN_DIR=$(git -C "$dir" worktree list --porcelain | head -1 | sed 's/^worktree //')
    echo "Removing worktree $(basename "$WORKTREE_PATH")"
    (
      cd "$MAIN_DIR"
      _akka_worktree_remove "$WORKTREE_PATH" "$skip_confirm"
    )
  else
    _akka_confirm_data_loss "$dir" "$skip_confirm" || return 0
    echo "Removing $dir"
    rm -rf "$dir"
  fi
}

# ----------------------------------------------------------------------------
# Feature lifecycle
# ----------------------------------------------------------------------------

akka.new.feature() {

    if [ $1 ]; then
        _akka_require_env || return 1

        # create feature worktree (as a sibling of the template directory)
        echo "Creating feature worktree $1 in $AKKA_FEATURE_DIR"
        cd "$AKKA_FEATURE_DIR"
        _akka_git_worktree "$1"
        ./set-feature.sh "$1"


        DIR=$(pwd)
        echo "Feature directory is $DIR"
        (
            echo
            echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
            echo "Creating sdk worktree at ${DIR}/$1-sdk"
            cd "$AKKA_SDK_DIR"
            _akka_git_worktree "${DIR}/$1-sdk"
            echo "-----------------------------------------------"
            echo
        )

        (
            echo
            echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
            echo "Creating runtime worktree at ${DIR}/$1-runtime"
            cd "$AKKA_RUNTIME_DIR"
            _akka_git_worktree "${DIR}/$1-runtime"
            echo "-----------------------------------------------"
            echo
        )

        # the root project requires samples to be available at the root
        echo "-----------------------------------------------"
        echo "Creating symlink for samples at ${1}-sdk/samples"
        ln -s "$1-sdk/samples" samples
        echo "-----------------------------------------------"
        echo

        git add .
        git commit -m "feat: initialize '$1'"

        echo
        echo ">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        echo "Created feature worktree at $DIR"
        echo "  SDK worktree at ${DIR}/$1-sdk"
        echo "  Runtime worktree at ${DIR}/$1-runtime"
        echo "Done"
    fi
}

akka.close.feature() {

    # Parse arguments: an optional -f/--force flag skips all data-loss
    # confirmations, the remaining argument is the feature name.
    local skip_confirm=""
    local feature=""
    while [ $# -gt 0 ]; do
        case "$1" in
            -f|--force) skip_confirm=1 ;;
            *)          feature="$1" ;;
        esac
        shift
    done

    if [ -n "$feature" ]; then
        _akka_require_env || return 1
        (
            DIR="$(dirname "$AKKA_FEATURE_DIR")/$feature"

            echo "Deleting feature branch '$feature'"
            echo "  SDK worktree at ${DIR}/$feature-sdk"
            echo "  Runtime worktree at ${DIR}/$feature-runtime"
            echo "  Feature worktree at ${DIR}"
            echo "-----------------------------------------------"
            echo

            echo
            echo "-----------------------------------------------"
            echo "Deleting SDK worktree at ${DIR}/$feature-sdk"
            _akka_delete_branch "${DIR}/$feature-sdk" "$skip_confirm"
            echo
            echo "-----------------------------------------------"
            echo "Deleting Runtime worktree at ${DIR}/$feature-runtime"
            _akka_delete_branch "${DIR}/$feature-runtime" "$skip_confirm"
            echo
            echo "-----------------------------------------------"
            # The root feature worktree never needs confirmation: it only holds
            # the scaffold + symlink, the real work lives in the sub-worktrees.
            echo "Finally delete feature worktree ${DIR}"
            _akka_delete_branch "${DIR}" 1
            echo "-----------------------------------------------"
        )
    fi
}
