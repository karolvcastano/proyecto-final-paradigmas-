-- Json.hs
-- Serializador funcional puro que convierte los eventos integrados al formato
-- JSON exacto de 14 campos acordado con el equipo (Scala, Java y Prolog).

module Json where

import Normalizar (unirCon)
import Tipos

-- Convierte una lista de Eventos en un arreglo JSON formateado
eventosAJson :: [Evento] -> String
eventosAJson [] = "[]\n"
eventosAJson eventos =
  "[\n"
    ++ unirCon ",\n" (map (eventoAJsonIndentado "  ") eventos)
    ++ "\n]\n"

-- Convierte un único Evento en un objeto JSON de 14 campos
eventoAJson :: Evento -> String
eventoAJson = eventoAJsonIndentado ""

eventoAJsonIndentado :: String -> Evento -> String
eventoAJsonIndentado sangria ev =
  let sangriaCampo = sangria ++ "  "
      campos =
        [ campoTexto   "id"             (evId ev),
          campoTexto   "fuente"         (fuenteATexto (evFuente ev)),
          campoEntero  "linea_original" (evLineaOriginal ev),
          campoTexto   "tipo"           (evTipo ev),
          campoMaybeT  "ts_original"    (evTsOriginal ev),
          campoMaybeT  "ts_utc"         (evTsUtc ev),
          campoMaybeT  "persona"        (evPersona ev),
          campoMaybeT  "modulo"         (fmap moduloATexto (evModulo ev)),
          campoMaybeT  "puerta"         (evPuerta ev),
          campoMaybeT  "desde"          (fmap moduloATexto (evDesde ev)),
          campoMaybeT  "hacia"          (fmap moduloATexto (evHacia ev)),
          campoMaybeD  "valor"          (evValor ev),
          campoTexto   "estado"         (estadoATexto (evEstado ev)),
          campoMaybeT  "motivo"         (evMotivo ev)
        ]
      lineasCampos = [sangriaCampo ++ c | c <- campos]
   in sangria ++ "{\n"
        ++ unirCon ",\n" lineasCampos ++ "\n"
        ++ sangria ++ "}"

campoTexto :: String -> String -> String
campoTexto clave valor =
  "\"" ++ clave ++ "\": " ++ escaparTexto valor

campoEntero :: String -> Int -> String
campoEntero clave valor =
  "\"" ++ clave ++ "\": " ++ show valor

campoMaybeT :: String -> Maybe String -> String
campoMaybeT clave Nothing    = "\"" ++ clave ++ "\": null"
campoMaybeT clave (Just txt) = campoTexto clave txt

campoMaybeD :: String -> Maybe Double -> String
campoMaybeD clave Nothing  = "\"" ++ clave ++ "\": null"
campoMaybeD clave (Just d) = "\"" ++ clave ++ "\": " ++ show d

-- Escapa comillas dobles y barras invertidas dentro de cadenas JSON
escaparTexto :: String -> String
escaparTexto s = "\"" ++ concatMap escaparChar s ++ "\""
  where
    escaparChar '"'  = "\\\""
    escaparChar '\\' = "\\\\"
    escaparChar '\n' = "\\n"
    escaparChar '\r' = "\\r"
    escaparChar '\t' = "\\t"
    escaparChar c    = [c]
