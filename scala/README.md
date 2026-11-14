# Scala: C4 Consultas simultáneas y C5 Custodia de la evidencia

Responsable: Karol Viviana Castaño Usma 

C5 guarda la evidencia original sin modificarla. Cada registro tiene un hash encadenado con el anterior, para demostrar que nadie alteró el historial. Las correcciones se guardan como versiones separadas.

C4 atiende consultas simultáneas: si dos investigadores preguntan lo mismo al mismo tiempo, reciben la misma respuesta. También maneja las suscripciones para avisar cuando cambia la evidencia de una pregunta.

## Pendiente
- [x] Modelo inmutable y cadena de hashes
- [ ] Base de datos real con la misma interfaz
- [ ] Endpoints HTTP de evidencia y correcciones
- [ ] Consultas simultáneas y suscripciones
