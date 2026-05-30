This project contains two worktrees. One for the runtime and one for the SDK.

The runtime worktree is suffixed with `-runtime` and the SDK worktree is suffixed with `-sdk`.
They share code through an SPI defined in the runtime worktree.

When we change the SPI, we must adapt it in the SDK side as well.
After changing the SPI, we make a local release and update the dependencies on the SDK side.

How to update the SDK's runtime version:
* in runtime project: This can be done by calling `sbt publishLocal` grab the version key from the output.
* in SDK project: run `./updateRuntimeVersions.sh <version-key>`.

## IntelliJ multi-project setup (local only, not committed anywhere)

Goal: open IntelliJ at this root and see BOTH the runtime and the SDK.

How it works:
* The root `build.sbt` is a **trivial anchor** — it does nothing but exist, so the
  root counts as an sbt build and IntelliJ enables the sbt tool window. It must NOT
  reference the sub-builds (no `RootProject` / `aggregate` / `dependsOn`).
* In IntelliJ: open the root, then in the **sbt tool window** click **`+`** twice to
  link each real build separately:
  - `multimodal-tool-support-runtime/build.sbt`
  - `multimodal-tool-support-sdk/build.sbt`
* This keeps the two builds fully decoupled. The SDK still depends on the runtime as a
  published artifact, so SPI changes go through the publish + version-bump flow above.

Why not one composite build (auto-pickup)? A `RootProject` composite cannot load these
two builds together: they pull **different major versions of sbt-header**
(`de.heikoseeberger.sbtheader.*` vs `sbtheader.*`), and a composite shares one
plugin-key namespace, so the keys collide irreconcilably. Fixing that would require
editing the sub-builds, which we deliberately avoid.

Local scaffolding at the root (all untracked, safe to delete to revert):
* `build.sbt` — the anchor described above.
* `project/build.properties` — pins sbt 1.12.8 (same as both builds).
* `.git` + `.gitignore` — a **throwaway local git repo**. It exists ONLY because the
  globally-installed `sbt-git` plugin (`~/.sbt/1.0/plugins` + `~/.sbt/1.0/worktree-fix.sbt`)
  runs `git` on every build, including this anchor, and aborts without a `.git`. It is
  never pushed and tracks nothing real.

⚠️ Because of that root `.git`: running `git` from the root directory talks to the
throwaway scaffold repo, NOT the worktrees. Always run git **inside** the
`-runtime` / `-sdk` subdirectories.
