package custodia

import com.sun.net.httpserver.{HttpExchange, HttpServer}
import java.net.InetSocketAddress

// Solo se encarga de HTTP: recibe, delega en Custodia y responde.
final class ServidorHttp(custodia: Custodia, repo: EvidenciaRepo, puerto: Int):
  private val servidor = HttpServer.create(InetSocketAddress(puerto), 0)

  def iniciar(): Unit =
    servidor.createContext("/evidencia", manejarEvidencia)
    servidor.setExecutor(null)
    servidor.start()

  def detener(): Unit = servidor.stop(0)

  private def manejarEvidencia(ex: HttpExchange): Unit =
    ex.getRequestMethod match
      case "POST" => registrarEvidencia(ex)
      case "GET"  => listarEvidencia(ex)
      case _      => responder(ex, 405, """{"error":"metodo no permitido"}""")

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

  private def responder(ex: HttpExchange, codigo: Int, cuerpo: String): Unit =
    val bytes = cuerpo.getBytes("UTF-8")
    ex.getResponseHeaders.add("Content-Type", "application/json; charset=utf-8")
    ex.sendResponseHeaders(codigo, bytes.length)
    ex.getResponseBody.write(bytes)
    ex.close()
