// Root anchor — LOCAL DEV ONLY, untracked.
//
// Its ONLY purpose is to make this root directory an sbt build so IntelliJ enables
// the sbt tool window. From there, link the two real builds separately
// (sbt tool window -> "+" -> pick each build.sbt):
//   - multimodal-tool-support-runtime
//   - multimodal-tool-support-sdk
//
// Why not a composite (RootProject + aggregate)? It cannot load these two builds
// together: they pull DIFFERENT major versions of sbt-header (de.heikoseeberger.*
// vs sbtheader.*), and a composite shares one plugin-key namespace, so the keys
// collide irreconcilably. Aligning that would require editing the sub-builds, which
// we deliberately do not do. Hence: anchor + manual link.
//
// The two builds stay fully decoupled and standalone-buildable. The SDK depends on
// the runtime as a published artifact: after an SPI change, publish the runtime
// locally and bump the SDK's runtime version (see publish-and-update.sh / CLAUDE.md).
//
// IMPORTANT: do NOT reference the sub-builds from here (no RootProject/aggregate/
// dependsOn). This file must do nothing but exist.

name := "multimodal-tool-support-root"
ThisBuild / scalaVersion := "2.13.18"
