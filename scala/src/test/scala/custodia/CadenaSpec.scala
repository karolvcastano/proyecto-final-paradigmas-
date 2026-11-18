package custodia

class CadenaSpec extends munit.FunSuite:

  private def evento(id: String, puerta: String): Evento =
    Evento(
      id = id,
      fuente = "tarjetas.csv",
      lineaOriginal = 1,
      tipo = "tarjeta",
      tsOriginal = Some("2041-06-14T01:20:33"),
      tsUtc = Some("2041-06-14T01:20:33Z"),
      persona = Some("IV-07"),
      modulo = None,
      puerta = Some(puerta),
      desde = Some("LAB-B"),
      hacia = Some("GEN"),
      valor = None,
      estado = "valido",
      motivo = None
    )

  test("el mismo historial produce el mismo hash final") {
    val a = Custodia(RepoEnMemoria())
    val b = Custodia(RepoEnMemoria())
    a.registrar(evento("1", "P4"))
    b.registrar(evento("1", "P4"))
    assertEquals(a.registrar(evento("2", "P3")).hash, b.registrar(evento("2", "P3")).hash)
  }

  test("cambiar un evento anterior cambia el hash final") {
    val a = Custodia(RepoEnMemoria())
    val b = Custodia(RepoEnMemoria())
    a.registrar(evento("1", "P4"))
    b.registrar(evento("1", "P3"))
    assertNotEquals(a.registrar(evento("2", "P3")).hash, b.registrar(evento("2", "P3")).hash)
  }
