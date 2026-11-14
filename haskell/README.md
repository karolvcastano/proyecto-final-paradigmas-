# Haskell (C1): Integrar la Evidencia

**Responsable:** Juan Diego Pinilla  
**Capacidad:** C1 — Leer las 6 fuentes de evidencia y las 2 de referencia, validar cada registro, resolver alias de identidad y módulos, unificar el tiempo a UTC y construir la línea de tiempo única de la noche sin descartar ningún dato sin rastro.

---

## 1. Estructura de Archivos y Diseño Funcional

El proyecto está escrito en **Haskell estándar** (usando únicamente tipos algebraicos `data`, `Maybe`, `Either`, recursión, ajuste de patrones `case ... of`, guardas `|`, comprensión de listas, funciones de orden superior `map` / `filter` / `foldr` y composición de funciones `.`), sin gestores complejos ni librerías externas:

```text
haskell/
├── Tipos.hs        -- Tipos de Datos Algebraicos (Modulo, Fuente, Estado, Evento, PersonaRef, PuertaRef)
├── Normalizar.hs   -- Funciones puras para limpiar cadenas, resolver alias, normalizar módulos y convertir horas a UTC
├── Parsers.hs      -- Funciones puras que leen cada una de las 6 fuentes de evidencia y las 2 de referencia
├── Validador.hs    -- Composición de funciones puras: duplicados, permisos, contradicciones y ordenamiento
├── Json.hs         -- Serializador puro de Evento y [Evento] al contrato JSON de 14 campos
├── DatosAnexoA.hs  -- Contenido de los 8 archivos del Anexo A para ejecución y pruebas autónomas
├── Main.hs         -- Único archivo con IO (en los bordes): lee archivos e imprime el JSON
└── Pruebas.hs      -- Pruebas automáticas de las funciones puras sobre los casos del Anexo A
```

---

## 2. Cómo Ejecutar y Probar

Desde la carpeta `haskell/`, usando directamente `runghc`:

```bash
# 1. Ejecutar las pruebas unitarias sobre los casos del Anexo A
runghc Pruebas.hs

# 2. Imprimir por consola el arreglo JSON completo de la línea de tiempo (70 eventos)
runghc Main.hs

# 3. Leer los 8 archivos desde una carpeta y mostrar el JSON por consola
runghc Main.hs ../ruta_carpeta_datos

# 4. Leer los 8 archivos desde una carpeta y guardar el resultado en un archivo .json
runghc Main.hs ../ruta_carpeta_datos evidencia_integrada.json
```

---

## 3. Especificación del JSON Generado y Cómo Tratarlo

Haskell genera un **arreglo JSON ordenado cronológicamente por `ts_utc`** donde cada elemento tiene **exactamente los 14 campos acordados por el equipo**, siempre en el mismo orden:

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

### 3.1. Significado de cada uno de los 14 Campos

| Campo | Tipo JSON | Descripción |
| :--- | :--- | :--- |
| `id` | `String` | Identificador único secuencial por fuente (`"<prefijo>-00001"`). |
| `fuente` | `String` | Archivo origen: `"tarjetas.csv"`, `"presencia.csv"`, `"temperatura.csv"`, `"energia.json"`, `"radio.txt"` o `"bitacora.txt"`. |
| `linea_original` | `Int` | Número de línea donde aparece el registro en el archivo original. |
| `tipo` | `String` | Categoría del evento: `"tarjeta"`, `"presencia"`, `"temperatura"`, `"energia"`, `"energia_corte"`, `"energia_restablecido"`, `"radio"`, `"bitacora"`. |
| `ts_original` | `String \| null` | Cadena de fecha/hora tal como venía en la fuente original (`"01.30"`, `"2254786200"`, `"00:52"`, etc.). |
| `ts_utc` | `String \| null` | Timestamp unificado a ISO-8601 UTC (`"YYYY-MM-DDTHH:MM:SSZ"`). Es `null` únicamente si la fecha del registro es `"corrupto"`. |
| `persona` | `String \| null` | Código canónico según `personal.csv` (`"JS-01"`, `"DV-02"`, `"MR-03"`, `"LP-04"`, `"AK-05"`, `"IV-07"`). Si la fuente usaba un alias (`"Luka"`, `"Doc"`, `"jefe"`), aquí ya se entrega el código canónico. |
| `modulo` | `String \| null` | Código canónico según `estacion.csv`: `"COM"`, `"DOR"`, `"LAB-A"`, `"LAB-B"`, `"GEN"`, `"RAD"`, `"ALM"`, `"EXT"` o `"*"` (cuando afecta a toda la estación). |
| `puerta` | `String \| null` | Código de puerta (`"P1"` a `"P8"`), presente en lecturas de `tarjetas.csv`. |
| `desde` | `String \| null` | Módulo de origen del desplazamiento en `tarjetas.csv`. |
| `hacia` | `String \| null` | Módulo de destino del desplazamiento en `tarjetas.csv`. |
| `valor` | `Double \| null` | Valor numérico de la lectura (`Option[Double]` en Scala):<br>• En `"presencia"`: cantidad de personas (`1.0`, `2.0`, `0.0`, o `null` si es `SIN_ENERGIA`).<br>• En `"temperatura"`: grados Celsius (`12.0`, `-6.3`, `-39.1`).<br>• En `"energia"`: consumo en kW (`2.1`, `5.2`, etc.).<br>• En `"tarjeta"`, `"radio"` y `"bitacora"`: `null`. |
| `estado` | `String` | Clasificación tras la validación de C1: `"valido"`, `"contradictorio"`, `"denegado"`, `"duplicado"` o `"corrupto"`. |
| `motivo` | `String \| null` | Explicación de rechazo/anomalía, registro de alias o módulo corregido, o transcripción del texto en `radio.txt` y `bitacora.txt`. |

---

### 3.2. Cómo tratar el resultado según `estado` (Guía para Scala y Prolog)

Ningún dato se descarta en Haskell; todos los registros se incluyen en el JSON con su respectivo `estado` y `motivo`:

1. **`"estado": "valido"`**:
   - **Scala (C5 / C6)**: Se registra en la cadena de hashes y hace parte de la línea de tiempo oficial del informe. Si `motivo` no es `null`, contiene trazabilidad útil (ej. `"Modulo normalizado: LAB_B -> LAB-B"` o `"Alias resuelto: Luka -> LP-04"`).
   - **Prolog (C2)**: Se carga como hecho válido de movimiento, presencia, temperatura o energía.

2. **`"estado": "contradictorio"`**:
   - **Ejemplo del Anexo A (`tarjetas-00008`)**: La tarjeta `LP-04` abre `P7` (`GEN` $\rightarrow$ `ALM`) el `14/06` a las `01:39:47Z`, pero en `bitacora-00001` (`12/06`) Petrov reportó haber perdido su tarjeta y en `radio.txt` transmite desde `RAD`.
   - **Scala (C6)**: Incluirlo tanto en la línea de tiempo como en la sección de **problemas y contradicciones de las fuentes**.
   - **Prolog (C2)**: La puerta `P7` sí se abrió hacia `ALM` con la tarjeta `LP-04`, pero **no debe asumirse que quien la portaba era Petrov (`LP-04`)**, sino que otra persona pudo usar la tarjeta extraviada.

3. **`"estado": "denegado"`**:
   - **Ejemplo del Anexo A (`tarjetas-00012`)**: `DV-02` pasa su tarjeta por `P4` (`LAB-B` $\rightarrow$ `GEN`) a las `02:40:05Z` con resultado `DENEGADO`.
   - **Prolog (C2)**: Indica que `DV-02` sí estaba en `LAB-B` frente a `P4` a las `02:40:05Z`, pero **la puerta no se abrió** (no pasó a `GEN`).

4. **`"estado": "duplicado"`**:
   - **Ejemplo del Anexo A (`tarjetas-00005`)**: Repite exactamente `tarjetas-00004` (`IV-07` en `P4` a las `01:20:33Z`).
   - **Scala (C5 / C6)**: Se conserva en custodia inmutable y se reporta en la lista de problemas de las fuentes (`"Registro duplicado exacto de tarjetas-00004"`).
   - **Prolog (C2)**: Ignorarlo al calcular desplazamientos para no duplicar hechos.

5. **`"estado": "corrupto"`**:
   - **Ejemplo del Anexo A (`tarjetas-00007`)**: Línea truncada `2041-06-14T0#:4?:1?,AK-0?,P2,DO` con `ts_utc: null`.
   - **Scala (C5 / C6)**: Se guarda en custodia y se muestra en la sección de registros dañados del informe junto con su `motivo` (que conserva la línea original intacta).
   - **Prolog (C2)**: No se usa como hecho confirmado de desplazamiento.
