#!/usr/bin/env bash
# Ejecuta la integración C1 sobre los 8 archivos del Anexo A en ./datos.
# Uso: ./run.sh [archivo_salida.json]
set -euo pipefail
cd "$(dirname "$0")"

if [ "$#" -ge 1 ]; then
  runghc Main.hs datos "$1"
else
  runghc Main.hs datos
fi
