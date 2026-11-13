package custodia

import java.security.MessageDigest

object Hash:
  def sha256(texto: String): String =
    MessageDigest
      .getInstance("SHA-256")
      .digest(texto.getBytes("UTF-8"))
      .map("%02x".format(_))
      .mkString

  // Cada hash depende del anterior: alterar un registro cambia todos los siguientes.
  def encadenar(hashAnterior: String, evento: Evento): String =
    sha256(hashAnterior + evento.toString)
