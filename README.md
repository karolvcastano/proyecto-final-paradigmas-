# Proyecto Halley-7 — Paradigmas del Lenguaje

Estado actual del repositorio:

| Capacidad | Lenguaje | Estado |
| :--- | :--- | :--- |
| C1 — Integrar la evidencia | Haskell | Implementado y probado |
| C2 — Responder preguntas | Prolog | Pendiente |
| C3 — Recibir la estación en vivo | Java | Pendiente |
| C4 — Atender varios investigadores | Java | Pendiente |
| C5 — Custodiar la evidencia | Scala | Pendiente |
| C6 — Informe del caso | Scala | Pendiente |

## C1 (Haskell)

La integración de los ocho archivos del Anexo A, la validación, la normalización de identidad/tiempo y la línea de tiempo están en [`haskell/`](haskell/).

```bash
cd haskell
runghc Pruebas.hs      # 22 pruebas
./run.sh               # integra datos/ e imprime el JSON (75 eventos)
./run.sh salida.json   # guarda el JSON
```

El contrato de 14 campos está documentado en [`haskell/README.md`](haskell/README.md) y formalizado en [`haskell/evento.schema.json`](haskell/evento.schema.json).

## Estructura

```text
haskell/   C1: integración, normalización, validación y JSON
prolog/    C2: consultas forenses (pendiente)
java/      C3/C4: recepción en vivo y concurrencia (pendiente)
scala/     C5/C6: custodia e informe (pendiente)
docs/      Bitácora de decisiones técnicas
```
