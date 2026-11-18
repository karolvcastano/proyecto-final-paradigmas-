ThisBuild / scalaVersion := "3.3.4"

lazy val root = (project in file("."))
  .settings(
    name := "halley-7-custodia",
    libraryDependencies ++= Seq(
      "com.lihaoyi" %% "ujson" % "3.3.1",
      "com.mysql" % "mysql-connector-j" % "9.1.0",
      "org.scalameta" %% "munit" % "1.0.0" % Test
    ),
    // Ejecuta el servidor en un proceso aparte para que sbt espere a que termine
    Compile / run / fork := true
  )
