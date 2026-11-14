package custodia

object Main:
  def main(args: Array[String]): Unit =
    val repo = RepoEnMemoria()
    val consultas = Consultas(repo)
    val servidor = ServidorHttp(Custodia(repo, consultas.alRegistrar), repo, consultas, 8080)
    servidor.iniciar()
    println("Custodia escuchando en http://localhost:8080/evidencia")
    Thread.sleep(Long.MaxValue)
