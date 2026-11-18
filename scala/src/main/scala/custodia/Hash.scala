package custodia

import java.security.MessageDigest

object Hash:
  def sha256(texto: String): String =
    MessageDigest
      .getInstance("SHA-256")
      .digest(texto.getBytes("UTF-8"))
      .map("%02x".format(_))
      .mkString

  // Forma canónica y estable del evento: los 14 campos, siempre en el mismo orden.
  // No depende de toString, así que no cambia si cambia la clase Evento internamente.
  def canonico(evento: Evento): String =
    ujson.Obj(
      "id" -> evento.id,
      "fuente" -> evento.fuente,
      "linea_original" -> ujson.Num(evento.lineaOriginal),
      "tipo" -> evento.tipo,
      "ts_original" -> opcional(evento.tsOriginal),
      "ts_utc" -> opcional(evento.tsUtc),
      "persona" -> opcional(evento.persona),
      "modulo" -> opcional(evento.modulo),
      "puerta" -> opcional(evento.puerta),
      "desde" -> opcional(evento.desde),
      "hacia" -> opcional(evento.hacia),
      "valor" -> evento.valor.fold[ujson.Value](ujson.Null)(ujson.Num(_)),
      "estado" -> evento.estado,
      "motivo" -> opcional(evento.motivo)
    ).render()

  private def opcional(valor: Option[String]): ujson.Value =
    valor.fold[ujson.Value](ujson.Null)(ujson.Str(_))

  // Cada hash depende del anterior: alterar un registro cambia todos los siguientes.
  def encadenar(hashAnterior: String, evento: Evento): String =
    sha256(hashAnterior + canonico(evento))
