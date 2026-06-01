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
    // Cross-build project refs in a composite are addressed as {build-uri}id/task; the
    // runtime build's aggregating `root` publishes the whole module set in one task.
    val runtimeBuild = file("{feature}-runtime").getCanonicalFile.toURI
    s"{$runtimeBuild}root/publishM2" ::
      s"{$runtimeBuild}root/publishLocal" ::
      "syncSdkRuntimeVersion" ::
      "reload" ::
      state
  }
