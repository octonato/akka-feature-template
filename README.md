# akka-feature

Helper shell functions for spinning up and tearing down an Akka **feature
workspace** — a feature root plus two linked git worktrees (the SDK and the
runtime) that share code through an SPI.

The feature root is a plain copy of the template, not a git repository, so it
cannot be pushed.

A feature workspace looks like this:

```
<feature>/            # feature root, copied from AKKA_FEATURE_DIR
├── <feature>-sdk/        # worktree of the SDK repo
├── <feature>-runtime/    # worktree of the runtime repo
└── samples -> <feature>-sdk/samples   # symlink the root build expects
```

## Requirements

### Tools

- **bash or zsh** — the functions are sourced into your interactive shell. The
  body is portable, but the command names (`akka.new.feature` /
  `akka.close.feature`) contain dots, which only bash and zsh accept as function
  names.
- **git** with worktree support (git ≥ 2.5).
- Standard POSIX utilities: `basename`, `dirname`, `sed`, `head`, `ln`, `tar`.

### Repositories

You need three local git checkouts, and each must have an `upstream` remote
configured (the helpers pull from `upstream/<base-branch>` when creating a
worktree):

- the **feature template** repo,
- the **Akka SDK** repo,
- the **Akka runtime** repo.

## Configuration

Set the following environment variables (e.g. in `~/.zshrc` or `~/.bashrc`).
There are no defaults — the helpers refuse to run if any required variable is
missing.

| Variable            | Required | Description                                                                                   |
| ------------------- | -------- | --------------------------------------------------------------------------------------------- |
| `AKKA_FEATURE_DIR`  | yes      | Path to the feature template repo. Feature workspaces are created as **siblings** of this dir. |
| `AKKA_SDK_DIR`      | yes      | Path to the Akka SDK checkout used as the worktree base.                                        |
| `AKKA_RUNTIME_DIR`  | yes      | Path to the Akka runtime checkout used as the worktree base.                                    |
| `GH_USER_PREFIX`    | no       | Prefix prepended to every created branch name (e.g. `myuser/`).                                |

Example:

```sh
export AKKA_FEATURE_DIR="$HOME/Sources/akka/feature/template"
export AKKA_SDK_DIR="$HOME/Sources/akka/sdk/main"
export AKKA_RUNTIME_DIR="$HOME/Sources/akka/runtime/main"
export GH_USER_PREFIX="myuser/"   # optional
```

## Setup

Source the script from your shell startup file so the functions are available
in every session:

```sh
# ~/.zshrc or ~/.bashrc
source /path/to/akka-feature.sh
```

Then open a new shell (or `source ~/.zshrc`).

## Usage

### Create a feature

```sh
akka.new.feature my-feature
```

This will:

1. Copy the template's committed files (`git archive HEAD`) into a sibling of
   `AKKA_FEATURE_DIR`.
2. Run `set-feature.sh` to substitute the feature name into the templated files.
3. Create the SDK worktree at `<feature>/my-feature-sdk`.
4. Create the runtime worktree at `<feature>/my-feature-runtime`.
5. Create the `samples` symlink the root build expects.

Branch names are `<GH_USER_PREFIX><name>` for each worktree.

### Publish the SPI

```sh
./publish-spi.sh
```

Run it from the feature root. It publishes the runtime worktree to `~/.m2` and
`~/.ivy2/local`, then sets the SDK worktree's runtime version to the published
version.

### Close a feature

```sh
akka.close.feature my-feature
```

This removes the SDK and runtime worktrees, deletes their branches, and deletes
the feature root. If a worktree has uncommitted changes or unpushed commits you will be
warned and asked to confirm before anything is deleted.
