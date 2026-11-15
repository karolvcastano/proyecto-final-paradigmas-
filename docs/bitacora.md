# Bitácora de decisiones técnicas

Cada decisión lleva fecha, problema, alternativas (con al menos una descartada), decisión y la prueba que la respalda.

---

## 2026-11-13 — Uso de Haskell básico con módulos puros y `Main.hs` para entrada/salida

**Problema.** Necesitábamos organizar el código de la parte C1 en Haskell cumpliendo la regla del paradigma funcional (lógica pura separada de la lectura de archivos) y usando únicamente lo visto en clase.

**Alternativas.**
- Usar un proyecto con `.cabal` y librerías externas para leer CSV y JSON: descartada porque complica la compilación y usa herramientas que no vimos en clase.
- Crear módulos `.hs` simples (`Tipos.hs`, `Normalizar.hs`, `Parsers.hs`, `Validador.hs`, `Json.hs`) usando solo funciones puras de Haskell y dejar toda la lectura y escritura de archivos en `Main.hs`: elegida.

**Decisión.** Toda la transformación de datos se hizo con funciones puras, listas, recursión y tipos algebraicos (`Modulo`, `Fuente`, `Estado`, `Evento`), ejecutando el programa directamente con `runghc Main.hs`.

**Prueba.** Ejecución de `runghc Main.hs` y `runghc Pruebas.hs` sin instalar librerías externas.

---

## 2026-11-13 — Unificación de todas las horas al formato UTC (`YYYY-MM-DDTHH:MM:SSZ`)

**Problema.** Los archivos vienen con formatos de hora distintos: ISO (`2041-06-14T00:12:04`), segundos Epoch (`2254786200`), hora con punto (`01.30`), hora entre corchetes (`[00:52]`) y fechas `DD/MM` en la bitácora. Así no se podían comparar ni ordenar en una sola línea de tiempo.

**Alternativas.**
- Dejar cada fecha en su texto original: descartada porque no se puede ordenar cronológicamente un número Epoch contra una hora como `01.30`.
- Convertir todas las fechas al formato de texto `YYYY-MM-DDTHH:MM:SSZ` en `Normalizar.hs`, pasando el Epoch a fecha con divisiones enteras (`div` y `mod` por `86400`) y recursión: elegida.

**Decisión.** Se conserva el texto original en `ts_original` y la fecha unificada en `ts_utc`. Cuando una entrada de la bitácora no tiene hora o dice `aprox.`, se aclara en el campo `motivo` para no confundirla con una hora exacta.

**Prueba.** Pruebas 1 y 2 de `haskell/Pruebas.hs` (`2254786200` y `01.30` se convierten a `2041-06-14T01:30:00Z`).

---

## 2026-11-13 — Manejo de errores con `Either` y `Estado` para no borrar ningún dato

**Problema.** El enunciado pide que ningún registro se descarte en silencio: las líneas rotas (como `2041-06-14T0#:4?:1?,AK-0?,P2,DO`) o repetidas deben conservarse junto con la razón por la que fallaron.

**Alternativas.**
- Usar `Maybe Evento` y eliminar los `Nothing` al leer los archivos: descartada porque borra el registro dañado y no deja rastro del error.
- Validar con `Either String a` y clasificar cada registro con el tipo `Estado` (`Valido`, `Denegado`, `Duplicado`, `Corrupto`, `Contradictorio`): elegida.

**Decisión.** Si una línea falla al validarse o está repetida, igual se crea el `Evento` con el estado correspondiente y se guarda la línea original junto con la explicación del problema en `motivo`. Además, antes de parsear radio y bitácora se unen las líneas que quedaron partidas por saltos de línea.

**Prueba.** Pruebas 5, 6 y 9 de `haskell/Pruebas.hs` (`tarjetas-00007` queda `corrupto` y `tarjetas-00005` queda `duplicado`).

---

## 2026-11-14 — Resolución de nombres y apodos verificando contra `personal.csv`

**Problema.** En `tarjetas.csv` aparecen códigos (`IV-07`), pero en `radio.txt` y `bitacora.txt` se usan nombres o apodos (`"Petrov"`, `"Luka"`, `"Doc"`, `"jefe"`). También notamos que si alguien mencionaba otro módulo en radio (como *"La dejé en generadores"*), no podíamos asumir que quien hablaba estaba en ese módulo.

**Alternativas.**
- Dejar los nombres tal como aparecen en cada archivo e inferir el módulo por cualquier lugar mencionado en el texto: descartada porque deja varias identidades para la misma persona e inventa ubicaciones falsas.
- Traducir todos los apodos a su código de tarjeta verificando que exista en `personal.csv`, y asignar `modulo` en radio/bitácora solo cuando la propia persona dice dónde está: elegida.

**Decisión.** Toda persona queda identificada con su código de `personal.csv` (dejando en `motivo` qué apodo se tradujo), el autor de la bitácora se busca por el cargo `"Jefe de estación"`, y `modulo` queda en `null` si el mensaje habla del lugar de otra persona.

**Prueba.** Pruebas 3, 13, 14 y 15 de `haskell/Pruebas.hs`.

---

## 2026-11-14 — Separación de los cortes de energía por módulo afectado

**Problema.** En `energia.json` el corte de las `01:40` indica una lista de módulos afectados (`COM`, `DOR`, `LAB-A`, `LAB-B`, `GEN`, `ALM`) mientras que `RAD` sigue funcionando con baterías. Si hacíamos un solo evento de corte general, Prolog y Scala no sabían fácilmente qué módulos quedaron sin luz.

**Alternativas.**
- Generar un único evento de corte con `modulo = "*"` y poner la lista de módulos en texto dentro de `motivo`: descartada porque obliga a los otros lenguajes a separar texto para saber si un módulo tenía energía.
- Generar un evento `energia_corte` individual por cada módulo afectado: elegida.

**Decisión.** Cada módulo sin luz tiene su propio evento `energia_corte`, por lo que `RAD` no aparece como cortado, y cuando vuelve la luz a las `02:15` se genera un evento `energia_restablecido` con `modulo = "*"`.

**Prueba.** Pruebas 11 y 12 de `haskell/Pruebas.hs`.

---

## 2026-11-15 — Cruce de fuentes para detectar contradicciones manteniendo los 14 campos del JSON

**Problema.** Había datos que individualmente parecían bien formados pero contradecían a otros archivos, como el uso de la tarjeta `LP-04` el 14/06 en `P7` después de que Petrov reportara en la bitácora del 12/06 que la había perdido, o posibles lecturas de puertas durante un apagón.

**Alternativas.**
- Agregar campos nuevos al JSON para marcar alertas y tarjetas perdidas: descartada porque rompía el contrato de 14 campos que ya habíamos acordado con Scala, Prolog y Java.
- Hacer una función de cruce (`detectarContradicciones` y `validarPermisosYTopologia` en `Validador.hs`) que cambie `estado` a `"contradictorio"` y explique el cruce en `motivo`: elegida.

**Decisión.** El validador revisa permisos y conexión de puertas contra `personal.csv` y `estacion.csv`, cruza las tarjetas reportadas perdidas en la bitácora y revisa si una puerta registró paso durante un corte en ese módulo, dejando todo expresado dentro de los mismos 14 campos del JSON.

**Prueba.** Pruebas 7, 8 y 21 de `haskell/Pruebas.hs` (`tarjetas-00008` se marca `contradictorio` haciendo referencia a `bitacora-00001`).
