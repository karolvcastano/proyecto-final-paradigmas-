package custodia

// Solo agrega evidencia: nunca modifica ni borra lo que ya existe.
// alRegistrar se avisa cada vez que entra evidencia nueva (por defecto no hace nada).
final class Custodia(repo: EvidenciaRepo, alRegistrar: Registro => Unit = _ => ()):
  def registrar(evento: Evento): Registro =
    val hash = Hash.encadenar(repo.ultimoHash, evento)
    val registro = Registro(evento, hash)
    repo.agregar(registro)
    alRegistrar(registro)
    registro
