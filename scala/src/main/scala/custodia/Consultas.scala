package custodia

import java.util.UUID
import java.util.concurrent.{CompletableFuture, ConcurrentHashMap, CopyOnWriteArrayList}
import java.util.concurrent.atomic.AtomicInteger

// Pregunta: cuántos eventos válidos hay de un tipo (y, opcionalmente, de una persona).
final case class Pregunta(tipo: String, persona: Option[String] = None)

final case class Respuesta(pregunta: Pregunta, cantidad: Int, version: Int)

// Suscripción de un investigador: cuenta la evidencia nueva que afecta su pregunta desde la última lectura.
final class Suscripcion(val pregunta: Pregunta):
  val pendientes = AtomicInteger(0)

object Consultas:
  def coincide(evento: Evento, pregunta: Pregunta): Boolean =
    evento.estado == "valido" &&
      evento.tipo == pregunta.tipo &&
      pregunta.persona.forall(p => evento.persona.contains(p))

final class Consultas(repo: EvidenciaRepo):
  // Cálculos compartidos: misma pregunta + misma versión = un solo cálculo.
  // Como el registro solo crece, una versión pasada nunca cambia, así que se puede guardar.
  private val calculos = ConcurrentHashMap[(Pregunta, Int), CompletableFuture[Respuesta]]()

  // Suscriptores por pregunta.
  private val suscriptores = ConcurrentHashMap[Pregunta, CopyOnWriteArrayList[Respuesta => Unit]]()

  // Suscripciones pedidas por HTTP, por id.
  private val suscripciones = ConcurrentHashMap[String, Suscripcion]()

  // Respuesta con la evidencia actual.
  def responder(pregunta: Pregunta): Respuesta =
    responderEn(pregunta, repo.todos.size)

  // Respuesta tal como era en una versión pasada (reconstrucción).
  def responderEn(pregunta: Pregunta, version: Int): Respuesta =
    require(version >= 0 && version <= repo.todos.size, s"version fuera de rango: $version")
    calculos
      .computeIfAbsent((pregunta, version), _ => CompletableFuture.supplyAsync(() => calcular(pregunta, version)))
      .join()

  def suscribir(pregunta: Pregunta, alCambiar: Respuesta => Unit): Unit =
    suscriptores
      .computeIfAbsent(pregunta, _ => new CopyOnWriteArrayList[Respuesta => Unit]())
      .add(alCambiar)

  // Crea una suscripción y devuelve su id.
  def crearSuscripcion(pregunta: Pregunta): String =
    val id = UUID.randomUUID.toString
    suscripciones.put(id, Suscripcion(pregunta))
    id

  // Devuelve la respuesta actual y cuántos eventos nuevos la afectaron desde la última lectura.
  // Al leer, el contador vuelve a cero.
  def leerSuscripcion(id: String): Option[(Respuesta, Int)] =
    Option(suscripciones.get(id)).map { s =>
      val nuevos = s.pendientes.getAndSet(0)
      (responder(s.pregunta), nuevos)
    }

  // Se llama cada vez que entra evidencia nueva (o una corrección).
  def alRegistrar(registro: Registro): Unit =
    suscriptores.forEach { (pregunta, lista) =>
      if afecta(registro, pregunta) then
        val respuesta = responder(pregunta)
        lista.forEach(cb => cb(respuesta))
    }
    suscripciones.forEach { (_, s) =>
      if afecta(registro, s.pregunta) then
        s.pendientes.incrementAndGet()
        ()
    }

  // Afecta si el evento nuevo cumple la pregunta, o si cumplía su versión anterior.
  private def afecta(registro: Registro, pregunta: Pregunta): Boolean =
    repo.todos.exists(r => r.evento.id == registro.evento.id && Consultas.coincide(r.evento, pregunta))

  // La versión vigente de cada evento es su último registro dentro de las primeras `version` entradas.
  private def calcular(pregunta: Pregunta, version: Int): Respuesta =
    val vigentes = repo.todos.take(version).groupBy(_.evento.id).values.map(_.last.evento)
    val cantidad = vigentes.count(e => Consultas.coincide(e, pregunta))
    Respuesta(pregunta, cantidad, version)
