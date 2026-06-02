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


  // ---------------------------------------------------------------------------
  // publishSpi — publish the runtime SPI locally and point the SDK at it.
  //
  // The SDK pins the runtime version via a plain Scala constant in its metabuild:
  //
  //   {feature}-sdk/project/Dependencies.scala
  //   val AkkaRuntimeVersion = sys.props.getOrElse("akka-runtime.version", "1.6.3")
  //
  // `publishSpi` runs these steps, in order, on the runtime build's aggregating `root`
  // so every module (akka-sdk-spi, akka-runtime-core/-dev, …) is covered:
  //   1. publishM2    — to ~/.m2, consumed by the Maven-based samples.
  //   2. publishLocal — to ~/.ivy2/local, consumed by the (sbt) SDK build.
  //   3. syncSdkRuntimeVersion — rewrites the default above with the dynver version read
  //      from the runtime build.
  //   4. reload — re-reads the changed build definition in this session.
  //
  // Rewriting Dependencies.scala (a *watched* metabuild file) is what makes IntelliJ
  // auto-reload; a system property or .sbtopts entry would not. Everything lives in this
  // root build; neither sub-build's build.sbt is touched.
  // ---------------------------------------------------------------------------

  commands += Command.command("syncSdkRuntimeVersion") { state =>
    val extracted = Project.extract(state)
    val runtimeBuild = file("{feature}-runtime").getCanonicalFile.toURI
    val publishedVersion = extracted.get(ProjectRef(runtimeBuild, "runtime-core") / version)

    val depFile = file("{feature}-sdk/project/Dependencies.scala")
    val original = IO.read(depFile)
    val pattern = """(sys\.props\.getOrElse\("akka-runtime\.version",\s*")[^"]*("\))""".r
    val updated = pattern.replaceAllIn(original, m => m.group(1) + publishedVersion + m.group(2))

    if (updated == original) {
      state.log.warn(
        s"akka-runtime.version already $publishedVersion (or pattern not found) in $depFile")
    } else {
      IO.write(depFile, updated)
      state.log.info(s"SDK akka-runtime.version -> $publishedVersion")
    }
    state
  }

  commands += Command.command("publishSpi") { state =>
    // `rt <task>` targets the runtime build's aggregating `root`, so each publish
    // covers the whole module set in one task (see delegateTo above).
    "rt publishM2" ::
      "rt publishLocal" ::
      "syncSdkRuntimeVersion" ::
      "reload" ::
      state
  }
