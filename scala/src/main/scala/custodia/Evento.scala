package custodia

final case class Evento(
    id: String,
    fuente: String,
    lineaOriginal: Int,
    tipo: String,
    tsOriginal: Option[String],
    tsUtc: Option[String],
    persona: Option[String],
    modulo: Option[String],
    puerta: Option[String],
    desde: Option[String],
    hacia: Option[String],
    valor: Option[Double],
    estado: String,
    motivo: Option[String]
)
