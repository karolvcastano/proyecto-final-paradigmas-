package custodia

import java.util.concurrent.{CompletableFuture, ConcurrentHashMap, CopyOnWriteArrayList}

// Pregunta: cuántos eventos válidos hay de un tipo (y, opcionalmente, de una persona).
final case class Pregunta(tipo: String, persona: Option[String] = None)

final case class Respuesta(pregunta: Pregunta, cantidad: Int, version: Int)

object Consultas:
  def coincide(evento: Evento, pregunta: Pregunta): Boolean =
    evento.estado == "valido" &&
      evento.tipo == pregunta.tipo &&
      pregunta.persona.forall(p => evento.persona.contains(p))

final class Consultas(repo: EvidenciaRepo):
  // Cálculos compartidos: misma pregunta + misma versión = un solo cálculo.
  private val calculos = ConcurrentHashMap[(Pregunta, Int), CompletableFuture[Respuesta]]()

  // Suscriptores por pregunta.
  private val suscriptores = ConcurrentHashMap[Pregunta, CopyOnWriteArrayList[Respuesta => Unit]]()

  def responder(pregunta: Pregunta): Respuesta =
    val version = repo.todos.size
    calculos
      .computeIfAbsent((pregunta, version), _ => CompletableFuture.supplyAsync(() => calcular(pregunta, version)))
      .join()

  def suscribir(pregunta: Pregunta, alCambiar: Respuesta => Unit): Unit =
    suscriptores
      .computeIfAbsent(pregunta, _ => new CopyOnWriteArrayList[Respuesta => Unit]())
      .add(alCambiar)

  // Se llama cada vez que entra evidencia nueva.
  def alRegistrar(registro: Registro): Unit =
    suscriptores.forEach { (pregunta, lista) =>
      if Consultas.coincide(registro.evento, pregunta) then
        val respuesta = responder(pregunta)
        lista.forEach(cb => cb(respuesta))
    }

  private def calcular(pregunta: Pregunta, version: Int): Respuesta =
    val cantidad = repo.todos.take(version).count(r => Consultas.coincide(r.evento, pregunta))
    Respuesta(pregunta, cantidad, version)
