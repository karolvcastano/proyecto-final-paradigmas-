package custodia

object EventoJson:
  // Los cinco estados que definió el equipo en el contrato JSON.
  private val estados = Set("valido", "contradictorio", "denegado", "duplicado", "corrupto")

  def desdeJson(texto: String): Evento =
    val j = ujson.read(texto)
    Evento(
      id = j("id").str,
      fuente = j("fuente").str,
      lineaOriginal = j("linea_original").num.toInt,
      tipo = j("tipo").str,
      tsOriginal = opcional(j, "ts_original"),
      tsUtc = opcional(j, "ts_utc"),
      persona = opcional(j, "persona"),
      modulo = opcional(j, "modulo"),
      puerta = opcional(j, "puerta"),
      desde = opcional(j, "desde"),
      hacia = opcional(j, "hacia"),
      valor = j.obj.get("valor").collect { case n: ujson.Num => n.value },
      estado = estadoValido(j("estado").str),
      motivo = opcional(j, "motivo")
    )

  private def estadoValido(estado: String): String =
    require(estados.contains(estado), s"estado no valido: $estado")
    estado

  private def opcional(j: ujson.Value, campo: String): Option[String] =
    j.obj.get(campo).collect { case s: ujson.Str => s.value }
