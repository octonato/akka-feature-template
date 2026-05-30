// Root anchor — LOCAL DEV ONLY, untracked.
//
// Its ONLY purpose is to make this root directory an sbt build so IntelliJ enables
// the sbt tool window. From there, link the two real builds separately
// (sbt tool window -> "+" -> pick each build.sbt):
//   - {feature}-runtime
//   - {feature}-sdk
//
// The two builds stay fully decoupled and standalone-buildable. The SDK depends on
// the runtime as a published artifact: after an SPI change, publish the runtime
// locally and bump the SDK's runtime version (see publish-and-update.sh / CLAUDE.md).
//
// IMPORTANT: do NOT reference the sub-builds from here (no RootProject/aggregate/
// dependsOn). This file must do nothing but exist.

name := "{feature}-root"
ThisBuild / scalaVersion := "2.13.18"
