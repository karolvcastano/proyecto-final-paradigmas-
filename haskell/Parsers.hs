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

-- Devuelve las personas válidas y, aparte, un evento de diagnóstico por cada
-- fila que no se pudo interpretar. Así ninguna fila de referencia desaparece
-- sin dejar rastro.
parsearPersonal :: String -> ([PersonaRef], [Evento])
parsearPersonal contenido =
  let numeradas = zip [1 ..] (lines contenido)
      filas =
        [ (numLinea, l)
          | (numLinea, l) <- numeradas,
            not (null (limpiar l)),
            not ("tarjeta," `isPrefixOf` aMinusculas (limpiar l))
        ]
      resultados =
        [ parsearLineaPersonal idx numLinea l
          | (idx, (numLinea, l)) <- zip [1 ..] filas
        ]
   in (concatMap fst resultados, concatMap snd resultados)

parsearLineaPersonal :: Int -> Int -> String -> ([PersonaRef], [Evento])
parsearLineaPersonal idx numLinea linea =
  let idEv   = formatearId FuentePersonal idx
      campos = map limpiar (dividirPor ',' linea)
   in case campos of
        [t, nom, cargo, acc]
          | not (null t) && not (null nom) ->
              ([PersonaRef t nom cargo (words acc) numLinea], [])
        _ ->
          ( [],
            [ eventoCorrupto
                idEv
                FuentePersonal
                numLinea
                "referencia"
                Nothing
                ( "Fila invalida en personal.csv (se esperaban 4 columnas, se obtuvieron "
                    ++ show (length campos)
                    ++ ") | linea cruda: "
                    ++ linea
                )
            ]
          )

parsearEstacion :: String -> ([PuertaRef], [Evento])
parsearEstacion contenido =
  let numeradas = zip [1 ..] (lines contenido)
      filas =
        [ (numLinea, l)
          | (numLinea, l) <- numeradas,
            not (null (limpiar l)),
            not ("puerta," `isPrefixOf` aMinusculas (limpiar l))
        ]
      resultados =
        [ parsearLineaEstacion idx numLinea l
          | (idx, (numLinea, l)) <- zip [1 ..] filas
        ]
   in (concatMap fst resultados, concatMap snd resultados)

parsearLineaEstacion :: Int -> Int -> String -> ([PuertaRef], [Evento])
parsearLineaEstacion idx numLinea linea =
  let idEv   = formatearId FuenteEstacion idx
      campos = map limpiar (dividirPor ',' linea)
      diag razon =
        ( [],
          [ eventoCorrupto
              idEv
              FuenteEstacion
              numLinea
              "referencia"
              Nothing
              (razon ++ " | linea cruda: " ++ linea)
          ]
        )
   in case campos of
        [p, m1Txt, m2Txt, lec]
          | not (null p) ->
              case (resolverModulo m1Txt, resolverModulo m2Txt) of
                (Right (m1, _), Right (m2, _))
                  | aMinusculas lec `elem` ["si", "no"] ->
                      ([PuertaRef p m1 m2 (aMinusculas lec == "si") numLinea], [])
                  | otherwise ->
                      diag ("Valor invalido en lector_tarjeta: " ++ lec ++ " (se esperaba si/no)")
                (Left e1, Left e2) -> diag ("Modulos invalidos: " ++ e1 ++ "; " ++ e2)
                (Left e1, _)       -> diag ("Modulo 1 invalido: " ++ e1)
                (_, Left e2)       -> diag ("Modulo 2 invalido: " ++ e2)
        _ ->
          diag
            ( "Fila invalida en estacion.csv (se esperaban 4 columnas, se obtuvieron "
                ++ show (length campos)
                ++ ")"
            )

-- ===========================================================================
-- 2. Parser Puro de tarjetas.csv
-- ===========================================================================

parsearTarjetas :: [PersonaRef] -> [PuertaRef] -> String -> [Evento]
parsearTarjetas personas puertas contenido =
  let numeradas = zip [1 ..] (lines contenido)
      filas =
        [ (numLinea, l)
          | (numLinea, l) <- numeradas,
            not (null (limpiar l)),
            not ("fecha_hora" `isPrefixOf` aMinusculas (limpiar l))
        ]
   in [ parsearLineaTarjeta personas puertas idx numLinea linea
        | (idx, (numLinea, linea)) <- zip [1 ..] filas
      ]

parsearLineaTarjeta :: [PersonaRef] -> [PuertaRef] -> Int -> Int -> String -> Evento
parsearLineaTarjeta personas puertas idx numLinea lineaCruda =
  let idEv   = formatearId FuenteTarjetas idx
      campos = map limpiar (dividirPor ',' lineaCruda)
   in case campos of
        [tsRaw, tarjetaRaw, puertaRaw, desdeRaw, haciaRaw, resRaw] ->
          case ( normalizarIso tsRaw,
                 resolverTarjeta personas tarjetaRaw,
                 validarPuertaExiste puertas puertaRaw,
                 resolverModulo desdeRaw,
                 resolverModulo haciaRaw,
                 validarResultadoLector resRaw
               ) of
            (Right tsUtc, Right pid, Right pId, Right (mDesde, notaDesde), Right (mHacia, notaHacia), Right (est, notaRes)) ->
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
                  evMotivo        = combinarMotivos [notaDesde, notaHacia, notaRes]
                }
            (eTs, ePer, ePue, eDes, eHac, eRes) ->
              let errores =
                    extraerErrores
                      [ fmap (const "") eTs,
                        fmap (const "") ePer,
                        fmap (const "") ePue,
                        fmap (const "") eDes,
                        fmap (const "") eHac,
                        fmap (const "") eRes
                      ]
               in Evento
                    { evId            = idEv,
                      evFuente        = FuenteTarjetas,
                      evLineaOriginal = numLinea,
                      evTipo          = "tarjeta",
                      evTsOriginal    = Just tsRaw,
                      evTsUtc         = aMaybe eTs,
                      evPersona       = aMaybe ePer,
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
              erroresParciales = diagnosticarCamposTruncados personas puertas campos
              tsUtcCand = case tsCand of
                Just t  -> aMaybe (normalizarIso t)
                Nothing -> Nothing
           in Evento
                { evId            = idEv,
                  evFuente        = FuenteTarjetas,
                  evLineaOriginal = numLinea,
                  evTipo          = "tarjeta",
                  evTsOriginal    = tsCand,
                  evTsUtc         = tsUtcCand,
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

diagnosticarCamposTruncados :: [PersonaRef] -> [PuertaRef] -> [String] -> String
diagnosticarCamposTruncados personas puertas campos =
  let e1 = case campos of (t : _) -> extraerErrores [normalizarIso t]; _ -> []
      e2 = case drop 1 campos of (p : _) -> extraerErrores [resolverTarjeta personas p]; _ -> []
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
              eventoCorruptoEn idEv FuentePresencia numLinea "presencia" (Just horaRaw) (aMaybe (normalizarHoraPunto (2041, 6, 14) horaRaw)) ("Registro corrupto en presencia.csv | linea cruda: " ++ lineaCruda)
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
              eventoCorruptoEn idEv FuenteTemperatura numLinea "temperatura" (Just epochRaw) (aMaybe (normalizarEpoch epochRaw)) ("Registro corrupto en temperatura.csv | linea cruda: " ++ lineaCruda)
        _ ->
          eventoCorrupto idEv FuenteTemperatura numLinea "temperatura" Nothing ("Columnas invalidas en temperatura.csv | linea cruda: " ++ lineaCruda)

leerDouble :: String -> Maybe Double
leerDouble txt =
  case reads (limpiar txt) :: [(Double, String)] of
    [(d, "")] -> Just d
    _         -> Nothing

-- ===========================================================================
-- 5. Parser Puro de energia.json
-- ===========================================================================

-- El archivo se entrega con un registro por bloque y una clave por línea.
-- Para no depender de una librería externa, se separan los bloques por su
-- línea "ts" y se interpreta cada bloque con funciones puras de texto.
-- Un bloque con ts inválido, tipo desconocido o consumo no numérico genera
-- un evento Corrupto que conserva el bloque crudo en el motivo.
parsearEnergia :: String -> [Evento]
parsearEnergia contenido =
  let lineas =
        [ (n, l)
          | (n, l) <- zip [1 ..] (lines contenido),
            not (null (limpiar l))
        ]
      bloques = dividirBloquesEnergia lineas
      eventos = concatMap parsearBloqueEnergia bloques
   in [ ev {evId = formatearId FuenteEnergia idx}
        | (idx, ev) <- zip [1 ..] eventos
      ]

dividirBloquesEnergia :: [(Int, String)] -> [[(Int, String)]]
dividirBloquesEnergia [] = []
dividirBloquesEnergia lineas =
  case dropWhile (not . esLineaTs . snd) lineas of
    [] -> []
    (primera : resto) ->
      let (bloque, siguientes) = span (not . esLineaTs . snd) resto
       in (primera : bloque) : dividirBloquesEnergia siguientes

esLineaTs :: String -> Bool
esLineaTs l = "\"ts\"" `isPrefixOf` limpiar l

parsearBloqueEnergia :: [(Int, String)] -> [Evento]
parsearBloqueEnergia bloque =
  case extraerCampoTexto "ts" bloque of
    Nothing ->
      [ eventoBloqueCorrupto
          (lineaInicial bloque)
          Nothing
          Nothing
          "Registro de energia sin campo ts"
          bloque
      ]
    Just (linTs, tsRaw) ->
      case normalizarIso tsRaw of
        Left err ->
          [ eventoBloqueCorrupto
              linTs
              (Just tsRaw)
              Nothing
              ("Timestamp de energia invalido: " ++ err)
              bloque
          ]
        Right tsUtc ->
          case extraerCampoTexto "tipo" bloque of
            Nothing ->
              [ eventoBloqueCorrupto
                  linTs
                  (Just tsRaw)
                  (Just tsUtc)
                  "Registro de energia sin campo tipo"
                  bloque
              ]
            Just (linTipo, tipo) ->
              case tipo of
                "lectura"       -> eventosLectura linTs tsRaw tsUtc bloque
                "corte"         -> eventosCorte linTs tsRaw tsUtc bloque
                "restablecido"  -> [eventoRestablecido linTs tsRaw tsUtc]
                otro ->
                  [ eventoBloqueCorrupto
                      linTipo
                      (Just tsRaw)
                      (Just tsUtc)
                      ("Tipo de registro de energia desconocido: " ++ otro)
                      bloque
                  ]

lineaInicial :: [(Int, String)] -> Int
lineaInicial [] = 0
lineaInicial ((n, _) : _) = n

eventosLectura :: Int -> String -> String -> [(Int, String)] -> [Evento]
eventosLectura linTs tsRaw tsUtc bloque =
  let consumos = extraerConsumos bloque
   in if null consumos
        then
          [ eventoBloqueCorrupto
              linTs
              (Just tsRaw)
              (Just tsUtc)
              "Registro de lectura sin consumos interpretables (consumo_kw)"
              bloque
          ]
        else concatMap (parsearConsumo tsRaw tsUtc) consumos

parsearConsumo :: String -> String -> (Int, String, String, String) -> [Evento]
parsearConsumo tsRaw tsUtc (numLinea, modRaw, valRaw, lineaCruda) =
  case (resolverModulo modRaw, leerDouble valRaw) of
    (Right (modulo, notaMod), Just kw) ->
      [ Evento
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
      ]
    (Left err, _) ->
      [ eventoCorruptoEn
          ""
          FuenteEnergia
          numLinea
          "energia"
          (Just tsRaw)
          (Just tsUtc)
          ("Consumo con modulo invalido: " ++ err ++ " | linea cruda: " ++ lineaCruda)
      ]
    (_, Nothing) ->
      [ eventoCorruptoEn
          ""
          FuenteEnergia
          numLinea
          "energia"
          (Just tsRaw)
          (Just tsUtc)
          ("Consumo no numerico: " ++ valRaw ++ " | linea cruda: " ++ lineaCruda)
      ]

eventosCorte :: Int -> String -> String -> [(Int, String)] -> [Evento]
eventosCorte linTs tsRaw tsUtc bloque =
  let afectados = extraerAfectados bloque
      notaTxt = case extraerCampoTexto "nota" bloque of
        Just (_, t) -> "; " ++ t
        Nothing     -> ""
      motivoBase = "Corte electrico" ++ notaTxt
   in if null afectados
        then
          [ Evento
              { evId            = "",
                evFuente        = FuenteEnergia,
                evLineaOriginal = linTs,
                evTipo          = "energia_corte",
                evTsOriginal    = Just tsRaw,
                evTsUtc         = Just tsUtc,
                evPersona       = Nothing,
                evModulo        = Nothing,
                evPuerta        = Nothing,
                evDesde         = Nothing,
                evHacia         = Nothing,
                evValor         = Nothing,
                evEstado        = Valido,
                evMotivo        = Just (motivoBase ++ "; sin lista de modulos afectados, alcance desconocido")
              }
          ]
        else
          concat
            [ case resolverModulo modRaw of
                Right (modulo, notaMod) ->
                  [ Evento
                      { evId            = "",
                        evFuente        = FuenteEnergia,
                        evLineaOriginal = n,
                        evTipo          = "energia_corte",
                        evTsOriginal    = Just tsRaw,
                        evTsUtc         = Just tsUtc,
                        evPersona       = Nothing,
                        evModulo        = Just modulo,
                        evPuerta        = Nothing,
                        evDesde         = Nothing,
                        evHacia         = Nothing,
                        evValor         = Nothing,
                        evEstado        = Valido,
                        evMotivo        = combinarMotivos [Just (motivoBase ++ "; afecta a " ++ moduloATexto modulo), notaMod]
                      }
                  ]
                Left err ->
                  [ eventoCorruptoEn
                      ""
                      FuenteEnergia
                      n
                      "energia_corte"
                      (Just tsRaw)
                      (Just tsUtc)
                      ("Modulo afectado invalido: " ++ err ++ " | linea cruda: " ++ l)
                  ]
            | (n, modRaw, l) <- afectados
            ]

eventoRestablecido :: Int -> String -> String -> Evento
eventoRestablecido linTs tsRaw tsUtc =
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
      evMotivo        = Just "Suministro electrico restablecido en toda la estacion"
    }

extraerConsumos :: [(Int, String)] -> [(Int, String, String, String)]
extraerConsumos = go False
  where
    go _ [] = []
    go enConsumo ((n, l) : xs)
      | "\"consumo_kw\"" `isInfixOf` l = go True xs
      | enConsumo && esCierreEstructura l = []
      | enConsumo && not (null (extraerValorEntreComillas l)) =
          ( n,
            extraerValorEntreComillas l,
            limpiarComaFinal (limpiar (despuesDeDosPuntos l)),
            l
          )
            : go True xs
      | otherwise = go enConsumo xs

extraerAfectados :: [(Int, String)] -> [(Int, String, String)]
extraerAfectados = go False
  where
    go _ [] = []
    go enAfecta ((n, l) : xs)
      | "\"afecta\"" `isInfixOf` l = go True xs
      | enAfecta && esCierreEstructura l = []
      | enAfecta && not (null (extraerValorEntreComillas l)) =
          (n, extraerValorEntreComillas l, l) : go True xs
      | otherwise = go enAfecta xs

esCierreEstructura :: String -> Bool
esCierreEstructura l =
  case limpiar l of
    ('}' : _) -> True
    (']' : _) -> True
    _         -> False

-- ===========================================================================
-- Utilidades internas para manejo de errores en parsers
-- ===========================================================================

extraerCampoTexto :: String -> [(Int, String)] -> Maybe (Int, String)
extraerCampoTexto clave bloque =
  case
      [ (n, v)
        | (n, l) <- bloque,
          ("\"" ++ clave ++ "\"") `isPrefixOf` limpiar l,
          let v = extraerValorEntreComillas (despuesDeDosPuntos l),
          not (null v)
      ]
    of
      (x : _) -> Just x
      []      -> Nothing

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

eventoBloqueCorrupto :: Int -> Maybe String -> Maybe String -> String -> [(Int, String)] -> Evento
eventoBloqueCorrupto numLinea mTsRaw mTsUtc razon bloque =
  Evento
    { evId            = "",
      evFuente        = FuenteEnergia,
      evLineaOriginal = numLinea,
      evTipo          = "energia",
      evTsOriginal    = mTsRaw,
      evTsUtc         = mTsUtc,
      evPersona       = Nothing,
      evModulo        = Nothing,
      evPuerta        = Nothing,
      evDesde         = Nothing,
      evHacia         = Nothing,
      evValor         = Nothing,
      evEstado        = Corrupto,
      evMotivo        =
        Just
          ( razon
              ++ " | bloque crudo: "
              ++ unirCon " | " (map snd bloque)
          )
    }

-- ===========================================================================
-- 6. Parser Puro de radio.txt (une líneas partidas como "...para la\ncena.")
-- ===========================================================================

parsearRadio :: [PersonaRef] -> String -> [Evento]
parsearRadio personas contenido =
  let noVacias =
        [ (n, limpiar l)
          | (n, l) <- zip [1 ..] (lines contenido),
            not (null (limpiar l)),
            not ("TRANSCRIP" `isPrefixOf` aMayusculas (limpiar l))
        ]
      agrupadas = unirLineasContinuadasRadio noVacias
   in [ parsearEntradaRadio personas idx numLinea texto
        | (idx, (numLinea, texto)) <- zip [1 ..] agrupadas
      ]

unirLineasContinuadasRadio :: [(Int, String)] -> [(Int, String)]
unirLineasContinuadasRadio = foldr paso []
  where
    paso (num, txt) [] = [(num, txt)]
    paso (num, txt) acc@((_, sigTxt) : resto)
      | "[" `isPrefixOf` sigTxt = (num, txt) : acc
      | otherwise               = (num, txt ++ " " ++ sigTxt) : resto

parsearEntradaRadio :: [PersonaRef] -> Int -> Int -> String -> Evento
parsearEntradaRadio personas idx numLinea entrada =
  let idEv = formatearId FuenteRadio idx
   in case entrada of
        ('[' : restoCorchete) ->
          let horaRaw       = takeWhile (/= ']') restoCorchete
              despuesCierre = limpiar (drop 1 (dropWhile (/= ']') restoCorchete))
              emisorRaw     = limpiar (takeWhile (/= ':') despuesCierre)
              mensaje       = limpiar (drop 1 (dropWhile (/= ':') despuesCierre))
           in case (normalizarHoraDosPuntos (2041, 6, 14) horaRaw, resolverPersona personas emisorRaw) of
                (Right tsUtc, Right (pid, notaAlias)) ->
                  let menciones =
                        [ etq ++ " -> " ++ cod
                          | (etq, cod) <- detectarMencionesValidas personas mensaje,
                            cod /= pid
                        ]
                      notaMenciones =
                        if null menciones
                          then Nothing
                          else Just ("Menciones resueltas: " ++ unirCon ", " menciones)
                      (mModulo, notaModulo) = inferirModuloRadio mensaje
                   in Evento
                        { evId            = idEv,
                          evFuente        = FuenteRadio,
                          evLineaOriginal = numLinea,
                          evTipo          = "radio",
                          evTsOriginal    = Just horaRaw,
                          evTsUtc         = Just tsUtc,
                          evPersona       = Just pid,
                          evModulo        = mModulo,
                          evPuerta        = Nothing,
                          evDesde         = Nothing,
                          evHacia         = Nothing,
                          evValor         = Nothing,
                          evEstado        = Valido,
                          evMotivo        = combinarMotivos [notaAlias, notaModulo, notaMenciones, Just ("Transcripcion: " ++ mensaje)]
                        }
                _ ->
                  eventoCorruptoEn idEv FuenteRadio numLinea "radio" (Just horaRaw) (aMaybe (normalizarHoraDosPuntos (2041, 6, 14) horaRaw)) ("Registro corrupto en radio.txt | linea cruda: " ++ entrada)
        _ ->
          eventoCorrupto idEv FuenteRadio numLinea "radio" Nothing ("Formato invalido en radio.txt | linea cruda: " ++ entrada)

-- Solo se infiere el módulo cuando el propio emisor afirma dónde está.
-- Mencionar a otra persona ("la dejé en generadores") no ubica al emisor.
inferirModuloRadio :: String -> (Maybe Modulo, Maybe String)
inferirModuloRadio msg =
  let m = aMinusculas msg
   in if "radio" `isInfixOf` m && ("aquí" `isInfixOf` m || "aqui" `isInfixOf` m)
        then
          ( Just RAD,
            Just "Modulo inferido del mensaje: el emisor dice estar en radio (RAD)"
          )
        else (Nothing, Nothing)

-- ===========================================================================
-- 7. Parser Puro de bitacora.txt (une párrafos partidos como "Kimura con\n\nfiebre")
-- ===========================================================================

parsearBitacora :: [PersonaRef] -> String -> [Evento]
parsearBitacora personas contenido =
  let noVacias =
        [ (n, limpiar l)
          | (n, l) <- zip [1 ..] (lines contenido),
            not (null (limpiar l)),
            not ("BITÁCORA" `isPrefixOf` aMayusculas (limpiar l)),
            not ("BITACORA" `isPrefixOf` aMayusculas (limpiar l))
        ]
      agrupadas = unirLineasContinuadasBitacora noVacias
   in [ parsearEntradaBitacora personas idx numLinea texto
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

parsearEntradaBitacora :: [PersonaRef] -> Int -> Int -> String -> Evento
parsearEntradaBitacora personas idx numLinea entrada =
  let idEv              = formatearId FuenteBitacora idx
      fechaPart         = take 5 entrada
      despuesFecha      = limpiar (drop 5 entrada)
      sinGuion          = if "-" `isPrefixOf` despuesFecha then limpiar (drop 1 despuesFecha) else despuesFecha
      (encabezado, msg) = separarEncabezadoBitacora sinGuion
      mHoraRaw          = extraerHoraOpcional encabezado
      tsOrig            = case mHoraRaw of Nothing -> fechaPart; Just h -> fechaPart ++ " " ++ h
   in case normalizarFechaBitacora 2041 fechaPart mHoraRaw of
        Right (tsUtc, notaHora) ->
          case resolverJefe personas of
            Left err ->
              eventoCorrupto
                idEv
                FuenteBitacora
                numLinea
                "bitacora"
                (Just tsOrig)
                ("No se pudo resolver al autor de la bitacora en personal.csv: " ++ err ++ " | linea cruda: " ++ entrada)
            Right (pid, _) ->
              let menciones = [etq ++ " -> " ++ cod | (etq, cod) <- detectarMencionesValidas personas msg]
                  notaMenciones =
                    if null menciones
                      then Nothing
                      else Just ("Menciones resueltas: " ++ unirCon ", " menciones)
                  (mModulo, notaModulo) = inferirModuloBitacora msg
               in Evento
                    { evId            = idEv,
                      evFuente        = FuenteBitacora,
                      evLineaOriginal = numLinea,
                      evTipo          = "bitacora",
                      evTsOriginal    = Just tsOrig,
                      evTsUtc         = Just tsUtc,
                      evPersona       = Just pid,
                      evModulo        = mModulo,
                      evPuerta        = Nothing,
                      evDesde         = Nothing,
                      evHacia         = Nothing,
                      evValor         = Nothing,
                      evEstado        = Valido,
                      evMotivo        =
                        combinarMotivos
                          [ Just ("Autor implicito: jefe de estacion -> " ++ pid),
                            notaHora,
                            notaModulo,
                            notaMenciones,
                            Just ("Nota bitacora: " ++ msg)
                          ]
                    }
        Left err ->
          eventoCorruptoEn idEv FuenteBitacora numLinea "bitacora" (Just tsOrig) (fmap fst (aMaybe (normalizarFechaBitacora 2041 fechaPart mHoraRaw))) (err ++ " | linea cruda: " ++ entrada)

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

-- Solo se infiere el módulo cuando el texto ubica explícitamente al autor.
-- "El almacén estaba helado" describe el almacén, no ubica al jefe allí.
inferirModuloBitacora :: String -> (Maybe Modulo, Maybe String)
inferirModuloBitacora msg =
  let m = aMinusculas msg
   in if "escribo con linterna en el comedor" `isInfixOf` m
        then
          ( Just COM,
            Just "Modulo inferido del texto: COM (el autor dice escribir en el comedor)"
          )
        else if "en el comedor" `isInfixOf` m
          then (Just COM, Just "Modulo inferido del texto: COM")
          else (Nothing, Nothing)

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
  eventoCorruptoEn idEv fuente numLinea tipo mTsOrig Nothing razon

eventoCorruptoEn :: String -> Fuente -> Int -> String -> Maybe String -> Maybe String -> String -> Evento
eventoCorruptoEn idEv fuente numLinea tipo mTsOrig mTsUtc razon =
  Evento
    { evId            = idEv,
      evFuente        = fuente,
      evLineaOriginal = numLinea,
      evTipo          = tipo,
      evTsOriginal    = mTsOrig,
      evTsUtc         = mTsUtc,
      evPersona       = Nothing,
      evModulo        = Nothing,
      evPuerta        = Nothing,
      evDesde         = Nothing,
      evHacia         = Nothing,
      evValor         = Nothing,
      evEstado        = Corrupto,
      evMotivo        = Just razon
    }
