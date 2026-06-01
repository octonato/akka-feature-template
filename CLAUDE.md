This project contains two worktrees. One for the runtime and one for the SDK.

The runtime worktree is `{feature}-runtime` and the SDK worktree is `{feature}-sdk`.
They share code through an SPI defined in the runtime worktree.

## SPI evolution

When we change the SPI, we must adapt it on the SDK side as well. The flow is:
publish the runtime locally, then update the SDK's runtime dependency version.

Use `publish-and-update.sh` to do both in one step:

```
./publish-and-update.sh {feature}-runtime {feature}-sdk
```

It publishes the runtime locally (`publishM2` + `publishLocal`), extracts the
published version, and runs the SDK's `updateRuntimeVersions.sh` with it.

## IntelliJ multi-project setup

Open IntelliJ at this root and it sees BOTH the runtime and the SDK — the root
`build.sbt` loads them as sbt composite builds (`RootProject` + `aggregate`), so
they are picked up automatically. No manual linking needed.

The two builds stay decoupled: the SDK depends on the runtime as a published
artifact (no source dependency), so SPI changes still go through the publish +
version-bump flow above.

⚠️ The root has its own `.git` scaffold repo: running `git` from the root talks to
that scaffold, NOT the worktrees. Always run git **inside** the
`{feature}-runtime` / `{feature}-sdk` subdirectories.
