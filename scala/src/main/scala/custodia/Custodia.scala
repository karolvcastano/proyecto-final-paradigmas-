package custodia

// Solo agrega evidencia: nunca modifica ni borra lo que ya existe.
// alRegistrar se avisa cada vez que entra evidencia nueva (por defecto no hace nada).
// synchronized: una sola escritura a la vez, para que la cadena de hashes no se bifurque.
final class Custodia(repo: EvidenciaRepo, alRegistrar: Registro => Unit = _ => ()):
  def registrar(evento: Evento): Registro = synchronized {
    val hash = Hash.encadenar(repo.ultimoHash, evento)
    val registro = Registro(evento, hash)
    repo.agregar(registro)
    alRegistrar(registro)
    registro
  }

  // Una corrección es un registro nuevo para un evento que ya existe. El original se conserva.
  def corregir(evento: Evento): Registro = synchronized {
    require(repo.todos.exists(_.evento.id == evento.id), s"no existe el evento ${evento.id}")
    registrar(evento)
  }
