# Haskell (C1): Integrar la Evidencia

**Responsable:** Juan Diego Pinilla
**Capacidad:** C1 — Leer las 6 fuentes de evidencia y las 2 de referencia, validar cada registro, resolver alias de identidad y módulos, unificar el tiempo a UTC y construir una única línea de tiempo de la noche sin descartar ningún dato sin rastro.

---

## 1. Estructura de archivos

El proyecto usa **Haskell estándar**: tipos algebraicos `data`, `Maybe`, `Either`, recursión, ajuste de patrones, guardas, comprensión de listas, `map` / `filter` / `foldr` y composición de funciones `.`. No usa librerías externas ni cabal.

```text
haskell/
├── Tipos.hs            -- ADTs: Modulo, Fuente, Estado, PersonaRef, PuertaRef, Evento
├── Normalizar.hs       -- Limpieza, alias, módulos y conversión de horas a UTC
├── Parsers.hs          -- Parsers puros de las 6 fuentes y las 2 referencias
├── Validador.hs        -- Duplicados, permisos, topología, contradicciones y orden
├── Json.hs             -- Serializador puro al contrato JSON de 14 campos
├── DatosAnexoA.hs      -- Texto del Anexo A para ejecutar y probar sin archivos
├── Main.hs             -- Único módulo con IO (bordes): lee archivos e imprime JSON
├── Pruebas.hs          -- 22 pruebas automáticas sobre el Anexo A y casos límite
├── evento.schema.json  -- JSON Schema del contrato de 14 campos
├── datos/              -- Los 8 archivos del Anexo A como archivos independientes
└── run.sh              -- Ejecuta C1 sobre datos/ con un solo comando
```

---

## 2. Cómo ejecutar y probar

Desde `haskell/`:

```bash
# 1. Pruebas automáticas (sin archivos externos)
runghc Pruebas.hs

# 2. Integrar los 8 archivos de datos/ e imprimir el JSON (75 eventos)
./run.sh
# equivalente a: runghc Main.hs datos

# 3. Guardar el resultado en un archivo
./run.sh evidencia_integrada.json
# equivalente a: runghc Main.hs datos evidencia_integrada.json

# 4. Integrar el Anexo A embebido, sin carpeta
runghc Main.hs
```

Si falta un archivo o una fila no se puede interpretar, el sistema no termina con una excepción sin contexto: `Main.hs` informa el archivo faltante y los parsers conservan la fila problemática como evento `corrupto` o `referencia`.

---

## 3. Diseño funcional

El núcleo es puro. `Main.hs` es el único módulo con IO y solo hace tres cosas: leer archivos, llamar a `integrarEvidencia` y escribir el JSON.

```haskell
integrarEvidencia
  :: String -> String -> String -> String -> String -> String -> String -> String
  -> [Evento]
```

El pipeline es composición de funciones puras:

```haskell
ordenarEventos
  . detectarContradicciones personas
  . map (validarPermisosYTopologia personas puertas)
  . marcarDuplicados
```

Cada parser devuelve eventos; los errores no se lanzan con excepciones: se representan con `Either String a`, `Maybe a` o un `Evento` con `estado = "corrupto"`.

---

## 4. Contrato JSON de 14 campos

Haskell genera un **arreglo JSON ordenado cronológicamente por `ts_utc`**. Cada elemento tiene exactamente estos 14 campos, siempre en el mismo orden. El esquema formal está en `evento.schema.json`.

```json
{
  "id": "tarjetas-00001",
  "fuente": "tarjetas.csv",
  "linea_original": 2,
  "tipo": "tarjeta",
  "ts_original": "2041-06-14T00:12:04",
  "ts_utc": "2041-06-14T00:12:04Z",
  "persona": "IV-07",
  "modulo": null,
  "puerta": "P2",
  "desde": "DOR",
  "hacia": "LAB-A",
  "valor": null,
  "estado": "valido",
  "motivo": null
}
```

| Campo | Tipo JSON | Descripción |
| :--- | :--- | :--- |
| `id` | `String` | Identificador único secuencial por fuente (`"<prefijo>-00001"`). |
| `fuente` | `String` | `"tarjetas.csv"`, `"radio.txt"`, `"energia.json"`, `"presencia.csv"`, `"temperatura.csv"`, `"bitacora.txt"`, y `"personal.csv"` / `"estacion.csv"` solo para diagnósticos de referencia. |
| `linea_original` | `Int` | Línea del archivo original. En `energia.json` apunta a la línea del `ts` o del consumo; en cortes, a la línea del módulo afectado. |
| `tipo` | `String` | `"tarjeta"`, `"radio"`, `"energia"`, `"energia_corte"`, `"energia_restablecido"`, `"presencia"`, `"temperatura"`, `"bitacora"` o `"referencia"`. |
| `ts_original` | `String \| null` | Fecha/hora tal como venía en la fuente (`"01.30"`, `"2254786200"`, `"00:52"`, `"12/06"`, etc.). |
| `ts_utc` | `String \| null` | ISO-8601 UTC (`"YYYY-MM-DDTHH:MM:SSZ"`). Es `null` cuando la hora no se pudo normalizar o en un diagnóstico de referencia. |
| `persona` | `String \| null` | Código canónico de `personal.csv`. En tarjetas es el **titular de la tarjeta**, no necesariamente quien la usó. |
| `modulo` | `String \| null` | Módulo del hecho (`"COM"`, `"DOR"`, `"LAB-A"`, `"LAB-B"`, `"GEN"`, `"RAD"`, `"ALM"`, `"EXT"`, `"*"`) o `null` si no está determinado. |
| `puerta` | `String \| null` | `"P1"` a `"P8"` en lecturas de `tarjetas.csv`. |
| `desde` | `String \| null` | Módulo de origen en `tarjetas.csv`. |
| `hacia` | `String \| null` | Módulo de destino en `tarjetas.csv`. |
| `valor` | `Double \| null` | Personas en `presencia`, grados Celsius en `temperatura`, kW en `energia`. `null` en tarjetas, radio, bitácora, cortes, restablecimientos y referencias. |
| `estado` | `String` | `"valido"`, `"denegado"`, `"duplicado"`, `"corrupto"` o `"contradictorio"`. |
| `motivo` | `String \| null` | Explicación de rechazo/anomalía, alias resuelto, módulo normalizado, inferencia de módulo, precisión temporal o transcripción. |

### 4.1. Semántica de `modulo` (importante para Prolog)

No se inventa ubicación:

- **Tarjetas:** `modulo` es `null`; la ubicación se expresa con `desde` y `hacia`.
- **Presencia, temperatura y consumo eléctrico:** `modulo` es el módulo de la lectura.
- **`energia_corte`:** se emite **un evento por módulo afectado**. `RAD` no recibe evento de corte si el archivo dice que continuó con baterías.
- **`energia_restablecido`:** un solo evento con `modulo = "*"` y `valor = null`; el restablecimiento es de alcance general.
- **Radio y bitácora:** `modulo` solo se llena cuando el propio autor afirma dónde está (`"aquí radio"`, `"escribo con linterna en el comedor"`). En ese caso el `motivo` dice `"Modulo inferido..."`. Si el mensaje menciona a otra persona o a otro módulo (`"La dejé en generadores"`, `"el almacén estaba helado"`), `modulo` queda `null`.
- **Referencias:** `modulo` es `null`.

### 4.2. Precisión temporal

La bitácora no siempre tiene hora. En lugar de fingir precisión, el `motivo` lo declara:

- Sin hora: `precision_temporal=desconocida; hora no registrada; se asigna 00:00:00Z solo para ordenar`.
- Con `aprox.`: `precision_temporal=aproximada; hora transcripta: 01:50 aprox.`.

`ts_utc` sigue existiendo para poder ordenar y para que C2 pueda usar la fecha; el consumidor debe leer el `motivo` para no tratar esas horas como exactas.

### 4.3. Identidad

La fuente de verdad es `personal.csv`:

- Los códigos de tarjeta se validan de forma **estricta** contra `personal.csv`.
- Los alias hablados (`"jefe"`, `"Luka"`, `"Doc"`, `"la doctora"`, etc.) se resuelven con una tabla explícita en `Normalizar.hs`; el código resultante **debe existir** en `personal.csv`.
- Si una tarjeta o un alias no existe en la referencia, el registro queda `corrupto` con el motivo; no se inventa una identidad.
- En un evento de tarjeta, `persona` es el titular. Si la tarjeta fue reportada perdida, el evento queda `contradictorio` y el consumidor no debe asumir que el titular fue quien la usó.

---

## 5. Validación y problemas encontrados

El pipeline detecta y deja rastro de:

| Problema | Tratamiento |
| :--- | :--- |
| Registro duplicado exacto | `estado = "duplicado"`, motivo con el `id` original. |
| Línea truncada o con columnas incompletas | `estado = "corrupto"`, motivo con la línea cruda. |
| Timestamp inválido en `energia.json` | `estado = "corrupto"`, `ts_utc = null`, bloque crudo en el motivo. |
| Consumo no numérico o módulo inválido | Evento `corrupto` con `ts_utc` si el timestamp era válido. |
| Corte sin `nota` | Se emite igualmente el evento de corte. |
| Alias de persona | Se resuelve al código canónico y se anota en el motivo. |
| Módulo `LAB_B` | Se normaliza a `LAB-B` y se anota. |
| Tarjeta sin permiso con resultado `OK` | `contradictorio`. |
| Tarjeta con `DENEGADO` y sin permiso | `denegado`, confirmado por `personal.csv`. |
| Tarjeta con `DENEGADO` pero con permiso vigente | `contradictorio` (posible falla del lector o uso anómalo). |
| Puerta sin lector usada con tarjeta | `contradictorio`. |
| Movimiento por una puerta que no conecta esos módulos | `contradictorio` por topología. |
| Tarjeta reportada perdida y usada después | `contradictorio`. |
| Lector registrando durante un corte que afecta a uno de los módulos de la puerta | `contradictorio`. |
| Fila inválida de `personal.csv` o `estacion.csv` | Evento `tipo = "referencia"`, `estado = "corrupto"`, con archivo y línea. |

### 5.1. Problemas concretos del Anexo A

- **Duplicado:** `tarjetas-00004` y `tarjetas-00005` repiten el mismo movimiento de `IV-07` por `P4`; el segundo queda `duplicado`.
- **Línea truncada:** `2041-06-14T0#:4?:1?,AK-0?,P2,DO` queda `corrupto` con la línea cruda y los errores de cada columna.
- **Identidad:** `"jefe"`, `"Luka"`, `"Doc"`, `"la doctora"` y `"Marta Ruiz"` se resuelven a sus códigos.
- **Módulo:** `LAB_B` de presencia se normaliza a `LAB-B`.
- **Línea partida:** la entrada de bitácora `"Kimura con"` + `"fiebre"` se reconstruye como un solo evento; la transcripción de radio `"...para la"` + `"cena."` también.
- **Corte:** se emiten cortes por módulo (`COM`, `DOR`, `LAB-A`, `LAB-B`, `GEN`, `ALM`) y **no** para `RAD`, que continúa con baterías.
- **Tarjeta perdida:** `LP-04` usa `P7` el 14/06 después de que la bitácora del 12/06 reportara la pérdida; el evento queda `contradictorio`.
- **Bitácora sin hora:** las entradas del 12/06 y 13/06 se ordenan a las 00:00 con `precision_temporal=desconocida`.

---

## 6. Cómo consumir el resultado (Scala, Prolog, Java)

1. **Filtrar diagnósticos:** los eventos con `tipo = "referencia"` no son evidencia de la noche; son problemas de `personal.csv` o `estacion.csv` para el informe (C6).
2. **Cortes de energía:** usar los eventos `energia_corte` por módulo. Si un módulo no tiene corte, no se vio afectado. El `energia_restablecido` con `modulo = "*"` cierra el corte para todos.
3. **Tarjetas:** `persona` es el titular de la tarjeta. Para saber quién pudo estar en un módulo, cruzar `desde`/`hacia` con presencia y no asumir que el titular fue el actor.
4. **Duplicados:** no usarlos para duplicar hechos de movimiento, pero conservarlos para C5/C6.
5. **Corruptos:** no usarlos como hechos confirmados; el motivo conserva la línea original para el informe.
6. **Precisión temporal:** leer `motivo` cuando empiece con `precision_temporal=`.
7. **Referencias:** si `personal.csv` o `estacion.csv` tienen filas inválidas, C1 las reporta; no hay que reconstruirlas en Scala.

---

## 7. Pruebas

`runghc Pruebas.hs` ejecuta 22 pruebas:

1. Conversión de epoch a UTC.
2. Hora con punto (`01.30`).
3. Alias de identidad contra `personal.csv`.
4. Normalización `LAB_B`.
5. Registro corrupto conservado.
6. Duplicado marcado.
7. `DENEGADO` marcado.
8. Contradicción de tarjeta perdida.
9. Línea partida de bitácora reconstruida.
10. Total de 75 eventos del Anexo A.
11. Corte por módulo y `RAD` no afectado.
12. Restablecimiento global.
13. `radio-00007` no ubica a Marta en `GEN`.
14. `bitacora-00004` no ubica al jefe en `ALM`.
15. `radio-00001` infiere `RAD` y deja rastro.
16. Fila inválida de `personal.csv` conservada.
17. Timestamp inválido de energía conservado como corrupto.
18. Corte sin `nota` no desaparece.
19. Consumo no numérico conservado con su timestamp.
20. Determinismo de la integración.
21. `DENEGADO` con permiso vigente se marca contradictorio.
22. Diagnóstico de `personal.csv` llega a la línea de tiempo integrada.

---

## 8. Límites y pendientes de integración

- C1 es batch: integra los ocho archivos y produce JSON. La recepción en vivo es C3 (Java).
- Para C3, el equipo debe acordar cómo representar una lectura viva en el contrato: `linea_original` puede usarse como número de secuencia, o se puede agregar un campo de origen. Hoy el esquema exige `linea_original >= 1`.
- La corrección de relojes (C5) puede reutilizar `ts_original` y volver a normalizar; las reglas de normalización están documentadas en este README y en `Normalizar.hs`.
- El parser de `energia.json` es deliberadamente básico y trabaja por bloques de línea, no es un parser JSON general. Si el formato se entrega minificado o con otra estructura, habrá que adaptarlo o usar una librería JSON permitida por el enunciado.
- La detección de corte durante una lectura de tarjeta es conservadora: si el corte afecta a **cualquiera** de los dos módulos de la puerta, el evento se marca `contradictorio`.

---

## 9. Declaración de herramientas

Se usó asistencia de IA para revisar el diseño y proponer mejoras de robustez. Las decisiones y la verificación con `runghc Pruebas.hs` quedan en el historial del repositorio y en esta documentación.
