package custodia

object Main:
  def main(args: Array[String]): Unit =
    val repo = RepoEnMemoria()
    val servidor = ServidorHttp(Custodia(repo), repo, 8080)
    servidor.iniciar()
    println("Custodia escuchando en http://localhost:8080/evidencia")
