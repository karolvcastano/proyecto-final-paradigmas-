# Scala: C4 Consultas simultáneas y C5 Custodia de la evidencia

Responsable: Karol Viviana Castaño Usma

C5 guarda la evidencia original sin modificarla. Cada registro tiene un hash encadenado con el anterior, para demostrar que nadie alteró el historial. Las correcciones se guardan como versiones separadas: el original nunca cambia.

C4 atiende consultas simultáneas: si dos investigadores preguntan lo mismo al mismo tiempo, comparten un solo cálculo y reciben la misma respuesta. También maneja las suscripciones para avisar cuando cambia la evidencia de una pregunta.

La evidencia se guarda en **MySQL 8.4 dentro de Docker**.

## Requisitos

- Docker Desktop (en ejecución)
- sbt 1.10.x y Java 17 o superior

## Cómo ejecutar

1. Levanta la base de datos (desde la carpeta `scala`):

```
docker compose up -d
```

MySQL queda en el puerto **3308** de tu computador. La tabla `registros` se crea sola al arrancar el servidor.

2. Prueba y ejecuta el servidor:

```
sbt test
sbt run
```

El servidor queda en `http://localhost:8080`. Para detenerlo, presiona Ctrl + C.

3. Para apagar la base de datos cuando termines:

```
docker compose down
```

Los datos se conservan en el volumen `custodia-datos`. Para borrarlos también, usa `docker compose down -v`.

## Configuración

La conexión a MySQL se toma de variables de entorno, con estos valores por defecto:

| Variable | Valor por defecto |
|---|---|
| `MYSQL_URL` | `jdbc:mysql://localhost:3308/custodia` |
| `MYSQL_USER` | `custodia` |
| `MYSQL_PASSWORD` | `custodia` |

## Endpoints

| Método | Ruta | Qué hace |
|---|---|---|
| POST | `/evidencia` | Registra un evento nuevo y devuelve su `id` y `hash` |
| GET | `/evidencia` | Lista los registros con su `id` y `hash` |
| POST | `/correccion` | Guarda una versión corregida de un evento existente; el original se conserva |
| GET | `/consulta?tipo=...&persona=...` | Cuenta los eventos válidos del tipo pedido (y de la persona, si se indica) |
| GET | `/consulta?tipo=...&version=N` | Reconstruye la respuesta tal como era en la versión N |
| POST | `/suscripcion?tipo=...&persona=...` | Crea una suscripción a una pregunta y devuelve su `id` |
| GET | `/suscripcion?id=...` | Devuelve la respuesta actual y `nuevos`: cuántos eventos nuevos la afectaron desde la última lectura (el contador vuelve a cero) |

## Pendiente
- [x] Modelo inmutable y cadena de hashes
- [x] Endpoints HTTP de evidencia y correcciones
- [x] Consultas simultáneas y consultas por versión
- [x] Suscripciones (lógica interna y por HTTP)
- [x] Base de datos real: MySQL 8.4 en Docker
- [x] Endpoint HTTP para suscripciones
- [x] Alinear el evento con el contrato de 14 campos del equipo (estados validados; probado con casos valido, denegado y corrupto del formato de Haskell)
- [x] Probar con el JSON completo de Haskell (76 eventos cargados sin rechazos)
