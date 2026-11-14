# Scala: C4 Consultas simultáneas y C5 Custodia de la evidencia

Responsable: Karol Viviana Castaño Usma

C5 guarda la evidencia original sin modificarla. Cada registro tiene un hash encadenado con el anterior, para demostrar que nadie alteró el historial. Las correcciones se guardan como versiones separadas: el original nunca cambia.

C4 atiende consultas simultáneas: si dos investigadores preguntan lo mismo al mismo tiempo, comparten un solo cálculo y reciben la misma respuesta. También maneja las suscripciones para avisar cuando cambia la evidencia de una pregunta.

## Cómo ejecutar

```
cd scala
sbt test
sbt run
```

El servidor queda en `http://localhost:8080`. Para detenerlo, presiona Ctrl + C.

## Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| POST | `/evidencia` | Registra un evento nuevo y devuelve su `id` y `hash` |
| GET | `/evidencia` | Lista los registros con su `id` y `hash` |
| POST | `/correccion` | Guarda una versión corregida de un evento existente; el original se conserva |
| GET | `/consulta?tipo=...&persona=...` | Cuenta los eventos válidos del tipo pedido (y de la persona, si se indica) |
| GET | `/consulta?tipo=...&version=N` | Reconstruye la respuesta tal como era en la versión N |

## Pendiente
- [x] Modelo inmutable y cadena de hashes
- [x] Endpoints HTTP de evidencia y correcciones
- [x] Consultas simultáneas y consultas por versión
- [x] Suscripciones (lógica interna)
- [ ] Endpoint HTTP para suscripciones
- [ ] Base de datos real con la misma interfaz
- [ ] Alinear el evento con el contrato de 14 campos del equipo
