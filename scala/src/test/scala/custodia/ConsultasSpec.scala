package custodia

import java.util.concurrent.CompletableFuture

class ConsultasSpec extends munit.FunSuite:

  private def evento(id: String, tipo: String): Evento =
    Evento(
      id = id,
      fuente = "tarjetas.csv",
      lineaOriginal = 1,
      tipo = tipo,
      tsOriginal = None,
      tsUtc = None,
      persona = Some("IV-07"),
      modulo = None,
      puerta = None,
      desde = None,
      hacia = None,
      valor = None,
      estado = "valido",
      motivo = None
    )

  test("responde cuántos eventos válidos hay del tipo pedido") {
    val repo = RepoEnMemoria()
    val custodia = Custodia(repo)
    custodia.registrar(evento("1", "tarjeta"))
    custodia.registrar(evento("2", "radio"))
    val consultas = Consultas(repo)
    assertEquals(consultas.responder(Pregunta("tarjeta")).cantidad, 1)
  }

  test("consultas concurrentes con la misma pregunta dan la misma respuesta") {
    val repo = RepoEnMemoria()
    Custodia(repo).registrar(evento("1", "tarjeta"))
    val consultas = Consultas(repo)
    val pregunta = Pregunta("tarjeta")
    val futuros = (1 to 20).map(_ => CompletableFuture.supplyAsync(() => consultas.responder(pregunta)))
    val cantidades = futuros.map(_.join().cantidad).toList
    assertEquals(cantidades, List.fill(20)(1))
  }

  test("el suscriptor solo recibe cambios de su pregunta") {
    val repo = RepoEnMemoria()
    val consultas = Consultas(repo)
    val custodia = Custodia(repo, consultas.alRegistrar)
    var recibidas = List.empty[Respuesta]
    consultas.suscribir(Pregunta("tarjeta"), r => recibidas = recibidas :+ r)

    custodia.registrar(evento("1", "radio"))
    assertEquals(recibidas.size, 0)

    custodia.registrar(evento("2", "tarjeta"))
    assertEquals(recibidas.map(_.cantidad), List(1))
  }

  test("una corrección cambia la respuesta actual pero no la pasada") {
    val repo = RepoEnMemoria()
    val custodia = Custodia(repo)
    custodia.registrar(evento("1", "tarjeta"))
    val consultas = Consultas(repo)
    val versionPasada = consultas.responder(Pregunta("tarjeta")).version

    custodia.corregir(evento("1", "radio"))

    assertEquals(consultas.responder(Pregunta("tarjeta")).cantidad, 0)
    assertEquals(consultas.responderEn(Pregunta("tarjeta"), versionPasada).cantidad, 1)
    assertEquals(repo.todos.size, 2)
  }

  test("no se puede corregir un evento que no existe") {
    val custodia = Custodia(RepoEnMemoria())
    intercept[IllegalArgumentException] {
      custodia.corregir(evento("99", "tarjeta"))
    }
  }

  test("no se puede registrar dos veces el mismo id") {
    val repo = RepoEnMemoria()
    val custodia = Custodia(repo)
    custodia.registrar(evento("1", "tarjeta"))
    intercept[IllegalArgumentException] {
      custodia.registrar(evento("1", "radio"))
    }
    assertEquals(repo.todos.size, 1)
  }

  test("una suscripcion cuenta la evidencia nueva que la afecta y se reinicia al leer") {
    val repo = RepoEnMemoria()
    val consultas = Consultas(repo)
    val custodia = Custodia(repo, consultas.alRegistrar)
    val id = consultas.crearSuscripcion(Pregunta("tarjeta"))

    custodia.registrar(evento("1", "radio"))
    assertEquals(consultas.leerSuscripcion(id).map(_._2), Some(0))

    custodia.registrar(evento("2", "tarjeta"))
    custodia.registrar(evento("3", "tarjeta"))
    val (respuesta, nuevos) = consultas.leerSuscripcion(id).get
    assertEquals(respuesta.cantidad, 2)
    assertEquals(nuevos, 2)
    assertEquals(consultas.leerSuscripcion(id).map(_._2), Some(0))
  }

  test("una suscripcion desconocida no existe") {
    assertEquals(Consultas(RepoEnMemoria()).leerSuscripcion("no-existe"), None)
  }

