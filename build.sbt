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


  // ---------------------------------------------------------------------------
  // rt / sdk — run a task in a sub-build without typing the build URI.
  //
  //   rt  <task>   ->  runtime build   e.g.  rt compile
  //                                          rt runtime-core/test
  //   sdk <task>   ->  sdk build       e.g.  sdk test
  //                                          sdk akka-javasdk/compile
  //
  // With no `proj/` the task runs on the sub-build's aggregating root (fans out
  // over every module); with a `proj/task` it targets that one module.
  //
  // Composite cross-build refs are addressed as {build-uri}proj/task — this just
  // hides the {uri} bookkeeping behind a name. (A plain addCommandAlias can't do
  // this: aliases are literal prepends and the trailing space breaks the parse.)
  // ---------------------------------------------------------------------------
  def delegateTo(name: String, build: java.io.File, rootId: String): Command =
    Command.args(name, "<task>") { (state, args) =>
      val uri = build.getCanonicalFile.toURI
      val task = args.mkString(" ")
      val scoped = if (task.contains("/")) task else s"$rootId/$task"
      s"{$uri}$scoped" :: state
    }

  commands += delegateTo("rt", file("{feature}-runtime"), "root")
  commands += delegateTo("sdk", file("{feature}-sdk"), "akka-javasdk-root")
