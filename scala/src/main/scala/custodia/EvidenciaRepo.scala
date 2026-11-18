package custodia

final case class Registro(evento: Evento, hash: String)

// Abstracción: hoy en memoria para las pruebas, después la base de datos.
trait EvidenciaRepo:
  def ultimoHash: String
  def agregar(registro: Registro): Unit
  def todos: List[Registro]

final class RepoEnMemoria() extends EvidenciaRepo:
  private var registros = Vector.empty[Registro]

  def ultimoHash: String =
    registros.lastOption.map(_.hash).getOrElse("GENESIS")

  def agregar(registro: Registro): Unit =
    registros = registros :+ registro

  def todos: List[Registro] = registros.toList
