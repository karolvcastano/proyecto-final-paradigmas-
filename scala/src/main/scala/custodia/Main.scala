package custodia

object Main:
  def main(args: Array[String]): Unit =
    val repo = crearRepo()
    val consultas = Consultas(repo)
    val servidor = ServidorHttp(Custodia(repo, consultas.alRegistrar), repo, consultas, 8080)
    servidor.iniciar()
    println("Custodia escuchando en http://localhost:8080/evidencia")
    Thread.sleep(Long.MaxValue)

  // MySQL 8.4 en Docker (ver docker-compose.yml, puerto 3308). Se puede cambiar con variables de entorno.
  private def crearRepo(): EvidenciaRepo =
    val url = sys.env.getOrElse("MYSQL_URL", "jdbc:mysql://localhost:3308/custodia")
    val usuario = sys.env.getOrElse("MYSQL_USER", "custodia")
    val clave = sys.env.getOrElse("MYSQL_PASSWORD", "custodia")
    RepoMySQL(url, usuario, clave)
