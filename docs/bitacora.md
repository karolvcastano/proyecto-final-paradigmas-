# Bitácora de decisiones técnicas

Cada decisión lleva fecha, problema, alternativas (con al menos una descartada), decisión y la prueba que la respalda.


## D-01 · 14/11/2026 · Hash encadenado para la custodia de la evidencia (Scala)
- **Problema:** cómo demostrar que ningún registro de evidencia fue alterado después de guardarse.
- **Alternativas consideradas:**
  - A) Guardar un hash independiente por registro. Descartada: un cambio en un registro intermedio no se detecta si nadie vuelve a verificar el historial.
  - B) Encadenar cada hash con el anterior. Elegida.
- **Decisión:** cada registro guarda `sha256(hash_anterior + evento)`. El primer registro usa `GENESIS`.
- **Prueba que la respalda:** `CadenaSpec` en `scala/src/test`: el mismo historial da el mismo hash final, y alterar un evento anterior cambia el hash final. Ambas pasan con `sbt test`.
- **Responsable:** Karol Viviana Castaño Usma 

