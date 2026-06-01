This project contains two worktrees. One for the runtime and one for the SDK.

The runtime worktree is `{feature}-runtime` and the SDK worktree is `{feature}-sdk`.
They share code through an SPI defined in the runtime worktree.

## SPI evolution

When we change the SPI, we must adapt it in the SDK side as well.
After changing the SPI, publish the runtime locally and point the SDK at the new version.

How to update the SDK's runtime version:
* From a root sbt session, run `publishSpi`. It publishes every runtime module to `~/.m2`
  (consumed by the Maven-based samples) and `~/.ivy2/local` (consumed by the SDK build),
  rewrites `akka-runtime.version` in `{feature}-sdk/project/Dependencies.scala` to the freshly
  published version, and reloads. IntelliJ auto-reloads on the `Dependencies.scala` change.


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
