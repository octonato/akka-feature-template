This project contains two worktrees. One for the runtime and one for the SDK.

The runtime worktree is `{feature}-runtime` and the SDK worktree is `{feature}-sdk`.
They share code through an SPI defined in the runtime worktree.

## SPI evolution

When we change the SPI, we must adapt it in the SDK side as well.
After changing the SPI, publish the runtime locally and point the SDK at the new version.

How to update the SDK's runtime version:
* From the root, run `./publish-spi.sh`. It publishes every runtime module to `~/.m2`
  (consumed by the Maven-based samples) and `~/.ivy2/local` (consumed by the SDK build).
  Then it sets `akka-runtime.version` in `{feature}-sdk/project/Dependencies.scala` to the
  published version. IntelliJ auto-reloads on the `Dependencies.scala` change.
* The script starts its own sbt in the runtime worktree. Reload any running SDK sbt session
  afterwards.


## IntelliJ multi-project setup

Open IntelliJ at this root and it sees BOTH the runtime and the SDK — the root
`build.sbt` loads them as sbt composite builds (`RootProject` + `aggregate`), so
they are picked up automatically. No manual linking needed.

The two builds stay decoupled: the SDK depends on the runtime as a published
artifact (no source dependency), so SPI changes still go through the publish +
version-bump flow above.

⚠️ The root is not a git repository. Always run git **inside** the
`{feature}-runtime` / `{feature}-sdk` subdirectories.
