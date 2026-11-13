package custodia

// Solo agrega evidencia: nunca modifica ni borra lo que ya existe.
final class Custodia(repo: EvidenciaRepo):
  def registrar(evento: Evento): Registro =
    val hash = Hash.encadenar(repo.ultimoHash, evento)
    val registro = Registro(evento, hash)
    repo.agregar(registro)
    registro
