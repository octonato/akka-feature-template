# Composite root build: why it failed, and what would make it work

Goal we were chasing: a single root `build.sbt` (an sbt **composite** via
`RootProject`) that loads BOTH the runtime and the SDK so that:
- IntelliJ picks up both projects automatically (no manual "+ link"), and
- (stretch goal) the SDK compiles against the runtime SPI **from source**, so SPI
  changes propagate without `publishLocal` + version bump.

Hard constraint throughout: **do NOT modify the runtime or SDK builds.** They must
stay byte-for-byte decoupled and standalone-buildable. Everything lives at the root.

Outcome: **not achievable** under that constraint. We fell back to a trivial root
anchor + linking each build manually in IntelliJ's sbt tool window. See the root
`CLAUDE.md` for the working setup.

---

## What a composite actually does (and doesn't)

- `RootProject(file("…"))` loads each sub-build WITH its own `project/` meta-build
  (plugins, `Dependencies.scala`) intact — no merging of the meta-builds. Good.
- `.aggregate(...)` only groups projects for task fan-out. It does **NOT** turn a
  `libraryDependencies` entry into a source dependency. Source-linking requires an
  explicit `.dependsOn(...)`, which we never wanted here (it would bypass the
  publish/bump flow). So an aggregate-only composite would have kept the SDK->runtime
  link as a published-jar dependency — exactly the decoupled behavior we want.
- BUT: importing/aggregating still forces sbt to **load** every aggregated build.
  "Don't compile both" does not avoid this — IntelliJ import = a load. And loading is
  where it died.

## Blockers we hit, in order (each fix revealed the next)

1. **Sandbox** — sbt couldn't write `~/.sbt/boot/sbt.boot.lock`. Not a build issue;
   ran sbt unsandboxed.

2. **No `.git` at root** — the globally-installed **sbt-git** plugin
   (`~/.sbt/1.0/plugins/plugins.sbt` + `~/.sbt/1.0/worktree-fix.sbt`) runs `git` on
   EVERY build, including the root, and aborts (exit 128) with no `.git`.
   Note: this is sbt-git, NOT sbt-dynver. (Each sub-build has its own per-build
   sbt-dynver, which runs in its own worktree dir — those are fine.)
   Fix: `git init` + one empty commit at the root (local-only, untracked).
   Result: error downgraded to a harmless `git describe` warning; load continued.

3. **`samples` relative-path NPE** — the SDK's `project/SamplesCompilationProject.scala`
   does `file("samples").listFiles().filter(...)`. In a composite, the relative path
   `"samples"` resolves against the **root** dir, not the SDK dir. No `samples` at root
   => `listFiles()` returns null => NPE => whole load fails.
   Fix (root-only): symlink `samples -> multimodal-tool-support-sdk/samples`.

4. **`ThisBuild / isSnapshot` undefined** — SDK's `project/Common.scala:39`
   (`releaseNotesURL`) reads `ThisBuild / isSnapshot`. In a composite the builds share
   one `Global` scope and this reference failed to resolve. We tried defining
   `ThisBuild / isSnapshot := true` and `Global / isSnapshot := true` from the root.
   That got us PAST this error — straight into the real wall (#5).

5. **THE WALL — incompatible sbt-header major versions.** Final load error:
   ```
   Some keys were defined with the same name but different types:
     'headerLicense'      (de.heikoseeberger.sbtheader.License, sbtheader.License)
     'headerMappings'     (… de.heikoseeberger.sbtheader.* … vs … sbtheader.* …)
     'headerLicenseStyle' (de.heikoseeberger.sbtheader.LicenseStyle, sbtheader.LicenseStyle)
   ```
   The SDK uses the OLD sbt-header package `de.heikoseeberger.sbtheader.*`; the runtime
   uses the NEW `sbtheader.*`. A composite collapses all aggregated builds' plugin keys
   into ONE shared key namespace. The same key name bound to two incompatible types is
   an unresolvable collision. **No root-only fix exists** — by design a composite cannot
   keep two different versions of the same plugin's keys apart.

## Why this is fundamental, not whack-a-mole

Blockers 2–4 were sub-builds assuming they are the top-level build (git at base, relative
paths, ThisBuild settings). Those are individually patchable from the root. Blocker 5 is
different: it's a property of how sbt composites share the plugin-key namespace. Two
incompatible major versions of the same AutoPlugin cannot coexist in one composite,
period.

## What would make it work (requires touching the sub-builds — currently out of scope)

The single hard requirement:

- **Align sbt-header to the same major version in BOTH builds.** Bump the SDK from
  `de.heikoseeberger:sbt-header` (old org/package) to the new `org.typelevel` /
  `sbtheader.*` line that the runtime uses (or vice-versa), in each build's
  `project/plugins.sbt`. Once both expose the same `header*` key types, the namespace
  collision disappears.

Then, to make the composite actually LOAD cleanly, also neutralize blockers 2–4. The
clean way is small per-build edits rather than root hacks:
- `samples` path: make `SamplesCompilationProject` resolve the samples dir from the
  SDK build's own `baseDirectory` instead of a relative `file("samples")`.
- `isSnapshot`: ensure the SDK sets `ThisBuild / isSnapshot` itself (dynver does this
  when a tag is reachable; both worktrees DO have tags standalone, so this only breaks
  under the shared-scope composite — defining it at root also works).
- root `.git`: still needed as long as the global sbt-git plugin is active; or remove/scope
  that global plugin.

### Optional further step: true source-linking (SPI from source)
Only after the composite loads. Add an explicit dependency from the SDK's `akka-javasdk`
project onto the runtime's `akka-sdk-spi` project:
```scala
// in the root composite, after both RootProjects resolve:
// (pseudo — needs ProjectRef into each build)
sdkAkkaJavaSdk.dependsOn(runtimeAkkaSdkSpi)
```
This bypasses publishLocal/version-bump and MiMa entirely. Trade-off: you'd be developing
against a config that never matches what ships. Keep it OFF unless you explicitly want it.

## Decision

Given the no-touch-the-sub-builds constraint, we stopped here and used the trivial
anchor + manual two-click link in IntelliJ. Revisit this doc if/when aligning sbt-header
across both builds becomes acceptable.

## Cleanup note (state left behind during the experiment)

- Global `~/.sbt/1.0/plugins/plugins.sbt` was temporarily edited and **restored**.
- A stray local tag `v0.0.0` was added to the SDK worktree and **deleted**.
  (The runtime's `v1.0.0` tag already existed before; it was not created by us.)
- Root `samples` symlink: removed.
- Root `.git`, `.gitignore`, `build.sbt` anchor, `project/build.properties`: kept (these
  are the working anchor setup, all untracked).
