-- Parsers.hs
-- Funciones puras para leer las 2 fuentes de referencia (personal.csv y estacion.csv)
-- y las 6 fuentes de evidencia (tarjetas.csv, presencia.csv, temperatura.csv,
-- energia.json, radio.txt y bitacora.txt).

module Parsers where

import Data.Char (isDigit)
import Data.List (isInfixOf, isPrefixOf)
import Normalizar
import Tipos

-- ===========================================================================
-- 1. Parsers de Referencia: personal.csv y estacion.csv
-- ===========================================================================

parsearPersonal :: String -> [PersonaRef]
parsearPersonal contenido =
  let lineas = [limpiar l | l <- lines contenido, not (null (limpiar l))]
      datos  = [l | l <- lineas, not ("tarjeta," `isPrefixOf` aMinusculas l)]
   in [ PersonaRef
          { refTarjeta = limpiar t,
            refNombre  = limpiar nom,
            refCargo   = limpiar cargo,
            refAccesos = words (limpiar acc)
          }
        | l <- datos,
          [t, nom, cargo, acc] <- [dividirPor ',' l]
      ]

parsearEstacion :: String -> [PuertaRef]
parsearEstacion contenido =
  let lineas = [limpiar l | l <- lines contenido, not (null (limpiar l))]
      datos  = [l | l <- lineas, not ("puerta," `isPrefixOf` aMinusculas l)]
   in [ PuertaRef
          { refPuerta      = limpiar p,
            refModulo1     = m1,
            refModulo2     = m2,
            refTieneLector = aMinusculas (limpiar lec) == "si"
          }
        | l <- datos,
          [p, m1Txt, m2Txt, lec] <- [dividirPor ',' l],
          Right (m1, _) <- [resolverModulo m1Txt],
          Right (m2, _) <- [resolverModulo m2Txt]
      ]

-- ===========================================================================
-- 2. Parser Puro de tarjetas.csv
-- ===========================================================================

parsearTarjetas :: [PuertaRef] -> String -> [Evento]
parsearTarjetas puertas contenido =
  let numeradas = zip [1 ..] (lines contenido)
      filas =
        [ (numLinea, limpiar l)
          | (numLinea, l) <- numeradas,
            not (null (limpiar l)),
            not ("fecha_hora" `isPrefixOf` aMinusculas (limpiar l))
        ]
   in [ parsearLineaTarjeta puertas idx numLinea linea
        | (idx, (numLinea, linea)) <- zip [1 ..] filas
      ]

parsearLineaTarjeta :: [PuertaRef] -> Int -> Int -> String -> Evento
parsearLineaTarjeta puertas idx numLinea lineaCruda =
  let idEv   = formatearId FuenteTarjetas idx
      campos = map limpiar (dividirPor ',' lineaCruda)
   in case campos of
        [tsRaw, tarjetaRaw, puertaRaw, desdeRaw, haciaRaw, resRaw] ->
          case ( normalizarIso tsRaw,
                 resolverPersona tarjetaRaw,
                 validarPuertaExiste puertas puertaRaw,
                 resolverModulo desdeRaw,
                 resolverModulo haciaRaw,
                 validarResultadoLector resRaw
               ) of
            (Right tsUtc, Right (pid, notaAlias), Right pId, Right (mDesde, notaDesde), Right (mHacia, notaHacia), Right (est, notaRes)) ->
              Evento
                { evId            = idEv,
                  evFuente        = FuenteTarjetas,
                  evLineaOriginal = numLinea,
                  evTipo          = "tarjeta",
                  evTsOriginal    = Just tsRaw,
                  evTsUtc         = Just tsUtc,
                  evPersona       = Just pid,
                  evModulo        = Nothing,
                  evPuerta        = Just pId,
                  evDesde         = Just mDesde,
                  evHacia         = Just mHacia,
                  evValor         = Nothing,
                  evEstado        = est,
                  evMotivo        = combinarMotivos [notaAlias, notaDesde, notaHacia, notaRes]
                }
            (eTs, ePer, ePue, eDes, eHac, eRes) ->
              let errores = extraerErrores [fmap (const "") eTs, fmap (const "") ePer, fmap (const "") ePue, fmap (const "") eDes, fmap (const "") eHac, fmap (const "") eRes]
               in Evento
                    { evId            = idEv,
                      evFuente        = FuenteTarjetas,
                      evLineaOriginal = numLinea,
                      evTipo          = "tarjeta",
                      evTsOriginal    = Just tsRaw,
                      evTsUtc         = aMaybe eTs,
                      evPersona       = fmap fst (aMaybe ePer),
                      evModulo        = Nothing,
                      evPuerta        = aMaybe ePue,
                      evDesde         = fmap fst (aMaybe eDes),
                      evHacia         = fmap fst (aMaybe eHac),
                      evValor         = Nothing,
                      evEstado        = Corrupto,
                      evMotivo        = Just ("Registro corrupto (" ++ unirCon "; " errores ++ ") | linea cruda: " ++ lineaCruda)
                    }
        -- Caso de línea truncada como la línea 8: "2041-06-14T0#:4?:1?,AK-0?,P2,DO"
        _ ->
          let tsCand = case campos of
                (t : _) | not (null t) -> Just t
                _ -> Nothing
              pCand = case drop 2 campos of
                (d : _) -> aMaybe (validarPuertaExiste puertas d)
                _ -> Nothing
              erroresParciales = diagnosticarCamposTruncados puertas campos
           in Evento
                { evId            = idEv,
                  evFuente        = FuenteTarjetas,
                  evLineaOriginal = numLinea,
                  evTipo          = "tarjeta",
                  evTsOriginal    = tsCand,
                  evTsUtc         = Nothing,
                  evPersona       = Nothing,
                  evModulo        = Nothing,
                  evPuerta        = pCand,
                  evDesde         = Nothing,
                  evHacia         = Nothing,
                  evValor         = Nothing,
                  evEstado        = Corrupto,
                  evMotivo        =
                    Just
                      ( "Registro corrupto: columnas incompletas ("
                          ++ show (length campos)
                          ++ "/6); "
                          ++ erroresParciales
                          ++ " | linea cruda: "
                          ++ lineaCruda
                      )
                }

validarPuertaExiste :: [PuertaRef] -> String -> Either String String
validarPuertaExiste puertas raw =
  let limpio = limpiar raw
   in if any (\p -> refPuerta p == limpio) puertas
        then Right limpio
        else Left ("Puerta desconocida: " ++ limpio)

validarResultadoLector :: String -> Either String (Estado, Maybe String)
validarResultadoLector raw =
  case aMayusculas (limpiar raw) of
    "OK"       -> Right (Valido, Nothing)
    "DENEGADO" -> Right (Denegado, Just "Resultado del lector: DENEGADO")
    otro       -> Left ("Resultado desconocido: " ++ otro)

diagnosticarCamposTruncados :: [PuertaRef] -> [String] -> String
diagnosticarCamposTruncados puertas campos =
  let e1 = case campos of (t : _) -> extraerErrores [normalizarIso t]; _ -> []
      e2 = case drop 1 campos of (p : _) -> extraerErrores [fmap fst (resolverPersona p)]; _ -> []
      e3 = case drop 2 campos of (d : _) -> extraerErrores [validarPuertaExiste puertas d]; _ -> []
      e4 = case drop 3 campos of (m : _) -> extraerErrores [fmap (moduloATexto . fst) (resolverModulo m)]; _ -> []
   in unirCon "; " (e1 ++ e2 ++ e3 ++ e4)

-- ===========================================================================
-- 3. Parser Puro de presencia.csv
-- ===========================================================================

parsearPresencia :: String -> [Evento]
parsearPresencia contenido =
  let numeradas = zip [1 ..] (lines contenido)
      filas =
        [ (numLinea, limpiar l)
          | (numLinea, l) <- numeradas,
            not (null (limpiar l)),
            not ("hora;modulo" `isPrefixOf` aMinusculas (limpiar l))
        ]
   in [ parsearLineaPresencia idx numLinea linea
        | (idx, (numLinea, linea)) <- zip [1 ..] filas
      ]

parsearLineaPresencia :: Int -> Int -> String -> Evento
parsearLineaPresencia idx numLinea lineaCruda =
  let idEv   = formatearId FuentePresencia idx
      campos = map limpiar (dividirPor ';' lineaCruda)
   in case campos of
        [horaRaw, modRaw, perRaw] ->
          case (normalizarHoraPunto (2041, 6, 14) horaRaw, resolverModulo modRaw) of
            (Right tsUtc, Right (modulo, notaMod))
              | aMayusculas perRaw == "SIN_ENERGIA" ->
                  Evento
                    { evId            = idEv,
                      evFuente        = FuentePresencia,
                      evLineaOriginal = numLinea,
                      evTipo          = "presencia",
                      evTsOriginal    = Just horaRaw,
                      evTsUtc         = Just tsUtc,
                      evPersona       = Nothing,
                      evModulo        = Just modulo,
                      evPuerta        = Nothing,
                      evDesde         = Nothing,
                      evHacia         = Nothing,
                      evValor         = Nothing,
                      evEstado        = Valido,
                      evMotivo        = combinarMotivos [notaMod, Just "Sensores de presencia sin energia (SIN_ENERGIA)"]
                    }
              | esNumeroEntero perRaw ->
                  Evento
                    { evId            = idEv,
                      evFuente        = FuentePresencia,
                      evLineaOriginal = numLinea,
                      evTipo          = "presencia",
                      evTsOriginal    = Just horaRaw,
                      evTsUtc         = Just tsUtc,
                      evPersona       = Nothing,
                      evModulo        = Just modulo,
                      evPuerta        = Nothing,
                      evDesde         = Nothing,
                      evHacia         = Nothing,
                      evValor         = Just (fromIntegral (read perRaw :: Int)),
                      evEstado        = Valido,
                      evMotivo        = notaMod
                    }
            _ ->
              eventoCorrupto idEv FuentePresencia numLinea "presencia" (Just horaRaw) ("Registro corrupto en presencia.csv | linea cruda: " ++ lineaCruda)
        _ ->
          eventoCorrupto idEv FuentePresencia numLinea "presencia" Nothing ("Columnas invalidas en presencia.csv | linea cruda: " ++ lineaCruda)

-- ===========================================================================
-- 4. Parser Puro de temperatura.csv
-- ===========================================================================

parsearTemperatura :: String -> [Evento]
parsearTemperatura contenido =
  let numeradas = zip [1 ..] (lines contenido)
      filas =
        [ (numLinea, limpiar l)
          | (numLinea, l) <- numeradas,
            not (null (limpiar l)),
            not ("epoch,sensor" `isPrefixOf` aMinusculas (limpiar l))
        ]
   in [ parsearLineaTemperatura idx numLinea linea
        | (idx, (numLinea, linea)) <- zip [1 ..] filas
      ]

parsearLineaTemperatura :: Int -> Int -> String -> Evento
parsearLineaTemperatura idx numLinea lineaCruda =
  let idEv   = formatearId FuenteTemperatura idx
      campos = map limpiar (dividirPor ',' lineaCruda)
   in case campos of
        [epochRaw, sensorRaw, celsiusRaw] ->
          case (normalizarEpoch epochRaw, resolverModulo sensorRaw, leerDouble celsiusRaw) of
            (Right tsUtc, Right (modulo, notaMod), Just grados) ->
              Evento
                { evId            = idEv,
                  evFuente        = FuenteTemperatura,
                  evLineaOriginal = numLinea,
                  evTipo          = "temperatura",
                  evTsOriginal    = Just epochRaw,
                  evTsUtc         = Just tsUtc,
                  evPersona       = Nothing,
                  evModulo        = Just modulo,
                  evPuerta        = Nothing,
                  evDesde         = Nothing,
                  evHacia         = Nothing,
                  evValor         = Just grados,
                  evEstado        = Valido,
                  evMotivo        = notaMod
                }
            _ ->
              eventoCorrupto idEv FuenteTemperatura numLinea "temperatura" (Just epochRaw) ("Registro corrupto en temperatura.csv | linea cruda: " ++ lineaCruda)
        _ ->
          eventoCorrupto idEv FuenteTemperatura numLinea "temperatura" Nothing ("Columnas invalidas en temperatura.csv | linea cruda: " ++ lineaCruda)

leerDouble :: String -> Maybe Double
leerDouble txt =
  case reads (limpiar txt) :: [(Double, String)] of
    [(d, "")] -> Just d
    _         -> Nothing

-- ===========================================================================
-- 5. Parser Puro de energia.json (recorrido recursivo de líneas)
-- ===========================================================================

parsearEnergia :: String -> [Evento]
parsearEnergia contenido =
  let numeradas = [(n, limpiar l) | (n, l) <- zip [1 ..] (lines contenido), not (null (limpiar l))]
      eventosSinId = recorrerLineasEnergia Nothing Nothing [] numeradas
   in [ ev {evId = formatearId FuenteEnergia idx}
        | (idx, ev) <- zip [1 ..] eventosSinId
      ]

-- Recorre las líneas de energia.json recordando el timestamp ("ts") y el "tipo" actual
recorrerLineasEnergia :: Maybe (Int, String, String) -> Maybe String -> [String] -> [(Int, String)] -> [Evento]
recorrerLineasEnergia _ _ _ [] = []
recorrerLineasEnergia mTs mTipo afectados ((numLinea, linea) : resto)
  -- Cuando encontramos un nuevo "ts": "2041-06-14T..."
  | "\"ts\"" `isPrefixOf` linea =
      let tsRaw = extraerValorEntreComillas (despuesDeDosPuntos linea)
          tsUtc = either (const tsRaw) id (normalizarIso tsRaw)
       in recorrerLineasEnergia (Just (numLinea, tsRaw, tsUtc)) Nothing [] resto
  -- Cuando encontramos "tipo": "lectura" | "corte" | "restablecido"
  | "\"tipo\"" `isPrefixOf` linea =
      let tipoVal = extraerValorEntreComillas (despuesDeDosPuntos linea)
       in case (mTs, tipoVal) of
            (Just (linTs, tsRaw, tsUtc), "restablecido") ->
              Evento
                { evId            = "",
                  evFuente        = FuenteEnergia,
                  evLineaOriginal = linTs,
                  evTipo          = "energia_restablecido",
                  evTsOriginal    = Just tsRaw,
                  evTsUtc         = Just tsUtc,
                  evPersona       = Nothing,
                  evModulo        = Just TODOS,
                  evPuerta        = Nothing,
                  evDesde         = Nothing,
                  evHacia         = Nothing,
                  evValor         = Nothing,
                  evEstado        = Valido,
                  evMotivo        = Just "Suministro electrico restablecido"
                }
                : recorrerLineasEnergia mTs (Just "restablecido") [] resto
            _ -> recorrerLineasEnergia mTs (Just tipoVal) [] resto
  -- Si estamos dentro de "tipo": "corte" y encontramos "nota": "..."
  | mTipo == Just "corte" && "\"nota\"" `isPrefixOf` linea =
      case mTs of
        Just (linTs, tsRaw, tsUtc) ->
          let notaTxt = extraerValorEntreComillas (despuesDeDosPuntos linea)
              listaAf = unirCon ", " (reverse afectados)
              motivoCorte = "Corte electrico afecta: " ++ listaAf ++ "; " ++ notaTxt
           in Evento
                { evId            = "",
                  evFuente        = FuenteEnergia,
                  evLineaOriginal = linTs,
                  evTipo          = "energia_corte",
                  evTsOriginal    = Just tsRaw,
                  evTsUtc         = Just tsUtc,
                  evPersona       = Nothing,
                  evModulo        = Just TODOS,
                  evPuerta        = Nothing,
                  evDesde         = Nothing,
                  evHacia         = Nothing,
                  evValor         = Just 0.0,
                  evEstado        = Valido,
                  evMotivo        = Just motivoCorte
                }
                : recorrerLineasEnergia mTs Nothing [] resto
        Nothing -> recorrerLineasEnergia mTs mTipo afectados resto
  -- Si estamos en "corte" y la línea es un módulo entre comillas (ej. "COM",)
  | mTipo == Just "corte" && comienzaConModuloEntreComillas linea =
      let modNombre = extraerValorEntreComillas linea
       in recorrerLineasEnergia mTs mTipo (modNombre : afectados) resto
  -- Si estamos en "lectura" y la línea tiene consumo de un módulo (ej. "COM": 2.1,)
  | mTipo == Just "lectura" && comienzaConModuloEntreComillas linea && ':' `elem` linea =
      case mTs of
        Just (_, tsRaw, tsUtc) ->
          let modKey  = extraerValorEntreComillas linea
              valStr  = limpiarComaFinal (limpiar (despuesDeDosPuntos linea))
           in case (resolverModulo modKey, leerDouble valStr) of
                (Right (modulo, notaMod), Just kw) ->
                  Evento
                    { evId            = "",
                      evFuente        = FuenteEnergia,
                      evLineaOriginal = numLinea,
                      evTipo          = "energia",
                      evTsOriginal    = Just tsRaw,
                      evTsUtc         = Just tsUtc,
                      evPersona       = Nothing,
                      evModulo        = Just modulo,
                      evPuerta        = Nothing,
                      evDesde         = Nothing,
                      evHacia         = Nothing,
                      evValor         = Just kw,
                      evEstado        = Valido,
                      evMotivo        = notaMod
                    }
                    : recorrerLineasEnergia mTs mTipo afectados resto
                _ -> recorrerLineasEnergia mTs mTipo afectados resto
        Nothing -> recorrerLineasEnergia mTs mTipo afectados resto
  | otherwise =
      recorrerLineasEnergia mTs mTipo afectados resto

comienzaConModuloEntreComillas :: String -> Bool
comienzaConModuloEntreComillas linea =
  let clave = extraerValorEntreComillas linea
   in clave `elem` ["COM", "DOR", "LAB-A", "LAB-B", "GEN", "RAD", "ALM", "EXT"]

despuesDeDosPuntos :: String -> String
despuesDeDosPuntos s =
  case dropWhile (/= ':') s of
    (':' : resto) -> limpiar resto
    _             -> ""

extraerValorEntreComillas :: String -> String
extraerValorEntreComillas s =
  case dropWhile (/= '"') s of
    ('"' : resto) -> takeWhile (/= '"') resto
    _             -> ""

limpiarComaFinal :: String -> String
limpiarComaFinal s
  | not (null s) && last s == ',' = init s
  | otherwise = s

-- ===========================================================================
-- 6. Parser Puro de radio.txt (une líneas partidas como "...para la\ncena.")
-- ===========================================================================

parsearRadio :: String -> [Evento]
parsearRadio contenido =
  let noVacias =
        [ (n, limpiar l)
          | (n, l) <- zip [1 ..] (lines contenido),
            not (null (limpiar l)),
            not ("TRANSCRIP" `isPrefixOf` aMayusculas (limpiar l))
        ]
      agrupadas = unirLineasContinuadasRadio noVacias
   in [ parsearEntradaRadio idx numLinea texto
        | (idx, (numLinea, texto)) <- zip [1 ..] agrupadas
      ]

unirLineasContinuadasRadio :: [(Int, String)] -> [(Int, String)]
unirLineasContinuadasRadio = foldr paso []
  where
    paso (num, txt) [] = [(num, txt)]
    paso (num, txt) acc@((_, sigTxt) : resto)
      | "[" `isPrefixOf` sigTxt = (num, txt) : acc
      | otherwise               = (num, txt ++ " " ++ sigTxt) : resto

parsearEntradaRadio :: Int -> Int -> String -> Evento
parsearEntradaRadio idx numLinea entrada =
  let idEv = formatearId FuenteRadio idx
   in case entrada of
        ('[' : restoCorchete) ->
          let horaRaw       = takeWhile (/= ']') restoCorchete
              despuesCierre = limpiar (drop 1 (dropWhile (/= ']') restoCorchete))
              emisorRaw     = limpiar (takeWhile (/= ':') despuesCierre)
              mensaje       = limpiar (drop 1 (dropWhile (/= ':') despuesCierre))
           in case (normalizarHoraDosPuntos (2041, 6, 14) horaRaw, resolverPersona emisorRaw) of
                (Right tsUtc, Right (pid, notaAlias)) ->
                  let menciones =
                        [ etq ++ " -> " ++ cod
                          | (etq, cod) <- detectarMenciones mensaje,
                            cod /= pid
                        ]
                      notaMenciones =
                        if null menciones
                          then Nothing
                          else Just ("Menciones resueltas: " ++ unirCon ", " menciones)
                   in Evento
                        { evId            = idEv,
                          evFuente        = FuenteRadio,
                          evLineaOriginal = numLinea,
                          evTipo          = "radio",
                          evTsOriginal    = Just horaRaw,
                          evTsUtc         = Just tsUtc,
                          evPersona       = Just pid,
                          evModulo        = inferirModuloRadio mensaje,
                          evPuerta        = Nothing,
                          evDesde         = Nothing,
                          evHacia         = Nothing,
                          evValor         = Nothing,
                          evEstado        = Valido,
                          evMotivo        = combinarMotivos [notaAlias, notaMenciones, Just ("Transcripcion: " ++ mensaje)]
                        }
                _ ->
                  eventoCorrupto idEv FuenteRadio numLinea "radio" (Just horaRaw) ("Registro corrupto en radio.txt | linea cruda: " ++ entrada)
        _ ->
          eventoCorrupto idEv FuenteRadio numLinea "radio" Nothing ("Formato invalido en radio.txt | linea cruda: " ++ entrada)

inferirModuloRadio :: String -> Maybe Modulo
inferirModuloRadio msg =
  let m = aMinusculas msg
   in if "aquí radio" `isInfixOf` m || "aqui radio" `isInfixOf` m || "aquí en radio" `isInfixOf` m
        then Just RAD
        else if "para dormitorios" `isInfixOf` m
          then Just DOR
          else if "en generadores" `isInfixOf` m
            then Just GEN
            else if "en el b" `isInfixOf` m
              then Just LAB_B
              else Nothing

-- ===========================================================================
-- 7. Parser Puro de bitacora.txt (une párrafos partidos como "Kimura con\n\nfiebre")
-- ===========================================================================

parsearBitacora :: String -> [Evento]
parsearBitacora contenido =
  let noVacias =
        [ (n, limpiar l)
          | (n, l) <- zip [1 ..] (lines contenido),
            not (null (limpiar l)),
            not ("BITÁCORA" `isPrefixOf` aMayusculas (limpiar l)),
            not ("BITACORA" `isPrefixOf` aMayusculas (limpiar l))
        ]
      agrupadas = unirLineasContinuadasBitacora noVacias
   in [ parsearEntradaBitacora idx numLinea texto
        | (idx, (numLinea, texto)) <- zip [1 ..] agrupadas
      ]

unirLineasContinuadasBitacora :: [(Int, String)] -> [(Int, String)]
unirLineasContinuadasBitacora = foldr paso []
  where
    paso (num, txt) [] = [(num, txt)]
    paso (num, txt) acc@((_, sigTxt) : resto)
      | iniciaConFecha sigTxt = (num, txt) : acc
      | otherwise             = (num, txt ++ " " ++ sigTxt) : resto

iniciaConFecha :: String -> Bool
iniciaConFecha s =
  case take 5 s of
    [d1, d2, '/', m1, m2] -> all isDigit [d1, d2, m1, m2]
    _                     -> False

parsearEntradaBitacora :: Int -> Int -> String -> Evento
parsearEntradaBitacora idx numLinea entrada =
  let idEv              = formatearId FuenteBitacora idx
      fechaPart         = take 5 entrada
      despuesFecha      = limpiar (drop 5 entrada)
      sinGuion          = if "-" `isPrefixOf` despuesFecha then limpiar (drop 1 despuesFecha) else despuesFecha
      (encabezado, msg) = separarEncabezadoBitacora sinGuion
      mHoraRaw          = extraerHoraOpcional encabezado
      tsOrig            = case mHoraRaw of Nothing -> fechaPart; Just h -> fechaPart ++ " " ++ h
   in case normalizarFechaBitacora 2041 fechaPart mHoraRaw of
        Right (tsUtc, notaHora) ->
          let menciones = [etq ++ " -> " ++ cod | (etq, cod) <- detectarMenciones msg]
              notaMenciones =
                if null menciones
                  then Nothing
                  else Just ("Menciones resueltas: " ++ unirCon ", " menciones)
           in Evento
                { evId            = idEv,
                  evFuente        = FuenteBitacora,
                  evLineaOriginal = numLinea,
                  evTipo          = "bitacora",
                  evTsOriginal    = Just tsOrig,
                  evTsUtc         = Just tsUtc,
                  evPersona       = Just "JS-01",
                  evModulo        = inferirModuloBitacora msg,
                  evPuerta        = Nothing,
                  evDesde         = Nothing,
                  evHacia         = Nothing,
                  evValor         = Nothing,
                  evEstado        = Valido,
                  evMotivo        =
                    combinarMotivos
                      [ Just "Autor implicito: Jefe de estacion -> JS-01",
                        notaHora,
                        notaMenciones,
                        Just ("Nota bitacora: " ++ msg)
                      ]
                }
        Left err ->
          eventoCorrupto idEv FuenteBitacora numLinea "bitacora" (Just tsOrig) (err ++ " | linea cruda: " ++ entrada)

separarEncabezadoBitacora :: String -> (String, String)
separarEncabezadoBitacora txt =
  let antesPunto   = takeWhile (/= '.') txt
      despuesPunto = limpiar (drop 1 (dropWhile (/= '.') txt))
   in if "aprox" `isInfixOf` aMinusculas antesPunto
        then (limpiar antesPunto ++ ".", despuesPunto)
        else (limpiar antesPunto, despuesPunto)

extraerHoraOpcional :: String -> Maybe String
extraerHoraOpcional enc =
  case dividirPor ',' enc of
    (_ : horaParte : _) ->
      let limpio = limpiar horaParte
       in if null limpio then Nothing else Just limpio
    _ -> Nothing

inferirModuloBitacora :: String -> Maybe Modulo
inferirModuloBitacora msg =
  let m = aMinusculas msg
   in if "en el comedor" `isInfixOf` m
        then Just COM
        else if "el almacén estaba helado" `isInfixOf` m || "el almacen estaba helado" `isInfixOf` m
          then Just ALM
          else Nothing

-- ===========================================================================
-- Utilidades internas para manejo de errores en parsers
-- ===========================================================================

aMaybe :: Either a b -> Maybe b
aMaybe (Right x) = Just x
aMaybe (Left _)  = Nothing

extraerErrores :: [Either String a] -> [String]
extraerErrores xs = [err | Left err <- xs]

eventoCorrupto :: String -> Fuente -> Int -> String -> Maybe String -> String -> Evento
eventoCorrupto idEv fuente numLinea tipo mTsOrig razon =
  Evento
    { evId            = idEv,
      evFuente        = fuente,
      evLineaOriginal = numLinea,
      evTipo          = tipo,
      evTsOriginal    = mTsOrig,
      evTsUtc         = Nothing,
      evPersona       = Nothing,
      evModulo        = Nothing,
      evPuerta        = Nothing,
      evDesde         = Nothing,
      evHacia         = Nothing,
      evValor         = Nothing,
      evEstado        = Corrupto,
      evMotivo        = Just razon
    }
