package custodia

import com.sun.net.httpserver.{HttpExchange, HttpServer}
import java.net.{InetSocketAddress, URLDecoder}

// Solo se encarga de HTTP: recibe, delega en Custodia o Consultas y responde.
final class ServidorHttp(custodia: Custodia, repo: EvidenciaRepo, consultas: Consultas, puerto: Int):
  private val servidor = HttpServer.create(InetSocketAddress(puerto), 0)

  def iniciar(): Unit =
    servidor.createContext("/evidencia", manejarEvidencia)
    servidor.createContext("/consulta", manejarConsulta)
    servidor.setExecutor(null)
    servidor.start()

  def detener(): Unit = servidor.stop(0)

  private def manejarEvidencia(ex: HttpExchange): Unit =
    ex.getRequestMethod match
      case "POST" => registrarEvidencia(ex)
      case "GET"  => listarEvidencia(ex)
      case _      => responder(ex, 405, """{"error":"metodo no permitido"}""")

  private def manejarConsulta(ex: HttpExchange): Unit =
    if ex.getRequestMethod != "GET" then
      responder(ex, 405, """{"error":"metodo no permitido"}""")
    else
      val params = parametros(ex.getRequestURI.getRawQuery)
      params.get("tipo") match
        case None =>
          responder(ex, 400, """{"error":"falta el parametro tipo"}""")
        case Some(tipo) =>
          val respuesta = consultas.responder(Pregunta(tipo, params.get("persona")))
          val json = ujson.Obj(
            "tipo" -> tipo,
            "cantidad" -> ujson.Num(respuesta.cantidad),
            "version" -> ujson.Num(respuesta.version)
          )
          responder(ex, 200, json.render())

  private def registrarEvidencia(ex: HttpExchange): Unit =
    val cuerpo = new String(ex.getRequestBody.readAllBytes(), "UTF-8")
    try
      val registro = custodia.registrar(EventoJson.desdeJson(cuerpo))
      val respuesta = ujson.Obj("id" -> registro.evento.id, "hash" -> registro.hash)
      responder(ex, 201, respuesta.render())
    catch
      case e: Exception =>
        responder(ex, 400, ujson.Obj("error" -> String.valueOf(e.getMessage)).render())

  private def listarEvidencia(ex: HttpExchange): Unit =
    val json = repo.todos
      .map(r => ujson.Obj("id" -> r.evento.id, "hash" -> r.hash).render())
      .mkString("[", ",", "]")
    responder(ex, 200, json)

  // Convierte "tipo=tarjeta&persona=IV-07" en un mapa.
  private def parametros(query: String): Map[String, String] =
    Option(query).getOrElse("")
      .split("&")
      .filter(_.contains("="))
      .map { par =>
        val i = par.indexOf('=')
        par.take(i) -> URLDecoder.decode(par.drop(i + 1), "UTF-8")
      }
      .toMap

  private def responder(ex: HttpExchange, codigo: Int, cuerpo: String): Unit =
    val bytes = cuerpo.getBytes("UTF-8")
    ex.getResponseHeaders.add("Content-Type", "application/json; charset=utf-8")
    ex.sendResponseHeaders(codigo, bytes.length)
    ex.getResponseBody.write(bytes)
    ex.close()
