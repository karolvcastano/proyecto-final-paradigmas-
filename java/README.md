# Java: Recepción en vivo (C3)

Responsable: Juan Esteban Giraldo 

Recibe las lecturas que la estación sigue transmitiendo (tarjetas, presencia y temperatura), las valida, las guarda en disco y las entrega a Scala (`POST /evidencia`). Ninguna lectura se pierde aunque Scala esté caído: queda en la cola y se reenvía cuando vuelve.

```
Simulador ──► Receptor ──► ColaEnDisco ──► Reenviador ──► Scala
 (estación)   (valida)     (cola.txt)      (reintenta)
```

## Clases

| Clase | Qué hace |
|---|---|
| `Lectura` | Una lectura con los 14 campos del contrato (`haskell/evento.schema.json`) |
| `ColaEnDisco` | Guarda cada lectura en `cola.txt` antes de enviarla y recuerda cuántas ya se entregaron |
| `Destino` | Interfaz: "entregar una lectura". Permite probar sin Scala |
| `DestinoHttp` | Entrega a Scala por HTTP. 201 = guardada, 400 = rechazada (no se reintenta), otro error = reintentar |
| `Reenviador` | Hilo que cada segundo envía las pendientes en orden; si una falla, espera y reintenta |
| `Receptor` | Servidor HTTP en el puerto 8090 (`POST /lectura`). Valida y guarda; las inválidas van a `rechazadas.txt` con su motivo |
| `Simulador` | Imita a la estación: envía lecturas al azar a velocidad configurable |
| `ServicioEnVivo` | Programa principal: arranca el receptor y el reenviador |

## Requisitos

Java 17 o superior. No usa librerías externas.

## Cómo ejecutar

Desde la carpeta `java`:

```
javac -encoding UTF-8 -d out src/envivo/*.java
java -cp out envivo.ServicioEnVivo
```

En otra terminal, también desde `java`:

```
java -cp out envivo.Simulador 500 5
```

El primer número es la velocidad (milisegundos entre lecturas) y el segundo la cantidad (0 = sin fin).

Para enviar a otra dirección de Scala: `SCALA_URL=http://otra-direccion/evidencia java -cp out envivo.ServicioEnVivo`.

## Archivos que genera (en `java/datos-vivo/`)

- `cola.txt`: todas las lecturas recibidas, una por línea. Nunca se borra nada.
- `entregadas.txt`: cuántas de esas lecturas ya recibió Scala.
- `rechazadas.txt`: lecturas inválidas con su motivo.

## Pruebas

```
java -cp out envivo.PruebaLectura      # el JSON cumple el contrato
java -cp out envivo.PruebaCola         # la cola sobrevive a un reinicio
java -cp out envivo.PruebaReenviador   # con el destino caído no se pierde nada
```

## Formato de las lecturas en vivo

El simulador envía una línea de texto separada por comas:

```
temperatura,2026-11-17T22:30:00Z,ALM,-7.5
presencia,2026-11-17T22:30:00Z,GEN,2
tarjeta,2026-11-17T22:30:00Z,IV-07,P4,LAB-B,GEN
```

`Lectura` la convierte al contrato de 14 campos con `id` = `vivo-00001`, `fuente` = `simulador` y `linea_original` = número de llegada.

## Pendiente
- [x] Simulador de lecturas (tarjetas, presencia, temperatura) con velocidad configurable
- [x] Recepción en vivo que incorpora la evidencia a medida que llega
- [x] Ninguna lectura se pierde con Scala caído (cola en disco y reintentos)
- [ ] Probar con el servidor Scala real
- [ ] Alertas: avisar solo al investigador que hizo la pregunta afectada (depende del endpoint de suscripciones de Scala)