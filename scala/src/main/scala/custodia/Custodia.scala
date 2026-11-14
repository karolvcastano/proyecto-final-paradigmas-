package custodia

// Solo agrega evidencia: nunca modifica ni borra lo que ya existe.
// alRegistrar se avisa cada vez que entra evidencia nueva (por defecto no hace nada).
// synchronized: una sola escritura a la vez, para que la cadena de hashes no se bifurque.
final class Custodia(repo: EvidenciaRepo, alRegistrar: Registro => Unit = _ => ()):

  // Alta de evidencia nueva. Un id que ya existe se rechaza: los repetidos los marca Haskell como "duplicado".
  def registrar(evento: Evento): Registro = synchronized {
    require(!repo.todos.exists(_.evento.id == evento.id), s"ya existe un evento con id ${evento.id}")
    agregar(evento)
  }

  // Una corrección es un registro nuevo para un evento que ya existe. El original se conserva.
  def corregir(evento: Evento): Registro = synchronized {
    require(repo.todos.exists(_.evento.id == evento.id), s"no existe el evento ${evento.id}")
    agregar(evento)
  }

  private def agregar(evento: Evento): Registro =
    val hash = Hash.encadenar(repo.ultimoHash, evento)
    val registro = Registro(evento, hash)
    repo.agregar(registro)
    alRegistrar(registro)
    registro
