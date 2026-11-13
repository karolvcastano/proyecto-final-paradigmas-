ThisBuild / scalaVersion := "3.3.4"

lazy val root = (project in file("."))
  .settings(
    name := "halley-7-custodia",
    libraryDependencies += "org.scalameta" %% "munit" % "1.0.0" % Test
  )
