// Root COMPOSITE build — LOCAL DEV ONLY
//
// Loads BOTH real builds as sbt composites so IntelliJ picks them up automatically:
//   - {feature}-runtime
//   - {feature}-sdk
//
// The two builds stay decoupled:
// the SDK still depends on the runtime as a published artifact (no .dependsOn here).

ThisBuild / scalaVersion := "2.13.18"

// Blocker #4: the SDK's project/Common.scala reads `ThisBuild / isSnapshot`. In a
// composite the builds share Global scope and this would otherwise be undefined.
ThisBuild / isSnapshot := true

lazy val runtime = RootProject(file("{feature}-runtime"))
lazy val sdk = RootProject(file("{feature}-sdk"))

// aggregate only groups the two builds for IntelliJ pickup / task fan-out.
// It does NOT create a source dependency between them.
lazy val root = (project in file("."))
  .settings(name := "{feature}-root")
  .aggregate(runtime, sdk)
