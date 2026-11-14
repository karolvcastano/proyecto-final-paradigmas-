-- Normalizar.hs
-- Funciones puras para limpiar cadenas, resolver alias de personas,
-- normalizar nombres de modulos y unificar todos los formatos de hora a UTC.

module Normalizar where

import Data.Char (isDigit, isSpace, toLower, toUpper)
import Data.List (isInfixOf, isPrefixOf)
import Tipos

-- ===========================================================================
-- 1. Utilidades básicas de listas y cadenas (recursión y orden superior)
-- ===========================================================================

-- Elimina espacios en blanco al inicio y al final de una cadena
limpiar :: String -> String
limpiar = reverse . dropWhile isSpace . reverse . dropWhile isSpace

-- Convierte toda una cadena a minúsculas
aMinusculas :: String -> String
aMinusculas = map toLower

-- Convierte toda una cadena a mayúsculas
aMayusculas :: String -> String
aMayusculas = map toUpper

-- Divide una cadena usando un carácter separador (ej. ',' o ';')
dividirPor :: Char -> String -> [String]
dividirPor _ "" = [""]
dividirPor sep (c : cs)
  | c == sep  = "" : dividirPor sep cs
  | otherwise = case dividirPor sep cs of
      (r : rs) -> (c : r) : rs
      []       -> [[c]]

-- Une una lista de cadenas con un separador de texto
unirCon :: String -> [String] -> String
unirCon _ [] = ""
unirCon _ [x] = x
unirCon sep (x : xs) = x ++ sep ++ unirCon sep xs

-- Rellena con ceros a la izquierda hasta alcanzar el ancho deseado
rellenarCeros :: Int -> Int -> String
rellenarCeros ancho n =
  let txt = show n
      faltan = max 0 (ancho - length txt)
   in replicate faltan '0' ++ txt

-- Genera el ID canónico de un evento: "<prefijo>-00001"
formatearId :: Fuente -> Int -> String
formatearId fuente numero =
  prefijoFuente fuente ++ "-" ++ rellenarCeros 5 numero

-- Combina varios motivos opcionales (Maybe String) separados por "; "
combinarMotivos :: [Maybe String] -> Maybe String
combinarMotivos lista =
  let validos = [m | Just m <- lista, not (null m)]
   in if null validos
        then Nothing
        else Just (unirCon "; " validos)

-- Verifica si una cadena contiene solo dígitos y no está vacía
esNumeroEntero :: String -> Bool
esNumeroEntero s = not (null s) && all isDigit s

-- ===========================================================================
-- 2. Normalización de Módulos y Sensores
-- ===========================================================================

-- Convierte un texto a su Modulo canónico.
-- Devuelve Left si es desconocido, o Right (Modulo, Maybe notaDeNormalizacion).
resolverModulo :: String -> Either String (Modulo, Maybe String)
resolverModulo texto =
  case limpiar texto of
    "COM"   -> Right (COM, Nothing)
    "DOR"   -> Right (DOR, Nothing)
    "LAB-A" -> Right (LAB_A, Nothing)
    "LAB-B" -> Right (LAB_B, Nothing)
    "GEN"   -> Right (GEN, Nothing)
    "RAD"   -> Right (RAD, Nothing)
    "ALM"   -> Right (ALM, Nothing)
    "EXT"   -> Right (EXT, Nothing)
    "*"     -> Right (TODOS, Nothing)
    -- En presencia.csv aparece "LAB_B" con guion bajo; se corrige y se deja rastro
    "LAB_B" -> Right (LAB_B, Just "Modulo normalizado: LAB_B -> LAB-B")
    "T-ALM" -> Right (ALM, Nothing)
    "T-EXT" -> Right (EXT, Nothing)
    otro    -> Left ("Modulo desconocido o truncado: " ++ otro)

-- ===========================================================================
-- 3. Unificación de Identidades (Resolución de Alias)
-- ===========================================================================

-- Resuelve un código de tarjeta o un alias ("Luka", "Doc", "jefe", etc.)
-- al identificador único de personal.csv.
-- Si era un alias, devuelve también la nota explicativa para el campo "motivo".
resolverPersona :: String -> Either String (String, Maybe String)
resolverPersona texto =
  let limpio = limpiar texto
      minus  = aMinusculas limpio
   in case limpio of
        "JS-01" -> Right ("JS-01", Nothing)
        "DV-02" -> Right ("DV-02", Nothing)
        "MR-03" -> Right ("MR-03", Nothing)
        "LP-04" -> Right ("LP-04", Nothing)
        "AK-05" -> Right ("AK-05", Nothing)
        "IV-07" -> Right ("IV-07", Nothing)
        _ -> case buscarAlias minus of
          Just codigo ->
            Right (codigo, Just ("Alias resuelto: " ++ limpio ++ " -> " ++ codigo))
          Nothing ->
            Left ("Identidad o tarjeta invalida: " ++ limpio)

buscarAlias :: String -> Maybe String
buscarAlias minus
  | minus `elem` ["okafor", "tomas okafor", "tomás okafor", "jefe"] = Just "JS-01"
  | minus `elem` ["vidal", "daniel vidal", "doc", "el doc"]         = Just "DV-02"
  | minus `elem` ["marta ruiz", "ruiz", "marta"]                    = Just "MR-03"
  | minus `elem` ["petrov", "lucas petrov", "luka"]                 = Just "LP-04"
  | minus `elem` ["kimura", "aiko kimura", "aiko"]                  = Just "AK-05"
  | minus `elem` ["irene", "irene valcarcel", "irene valcárcel", "la doctora", "doctora valcarcel", "doctora valcárcel"] = Just "IV-07"
  | otherwise = Nothing

-- Busca personas mencionadas dentro de un mensaje de radio o bitácora
detectarMenciones :: String -> [(String, String)]
detectarMenciones mensaje =
  let minus = aMinusculas mensaje
      patrones =
        [ ("Okafor", "okafor", "JS-01"),
          ("Doc", "doc,", "DV-02"),
          ("el doc", "el doc", "DV-02"),
          ("Vidal", "vidal", "DV-02"),
          ("Marta Ruiz", "marta ruiz", "MR-03"),
          ("Petrov", "petrov", "LP-04"),
          ("Luka", "luka", "LP-04"),
          ("Kimura", "kimura", "AK-05"),
          ("doctora Valcárcel", "doctora valcárcel", "IV-07"),
          ("La doctora", "la doctora", "IV-07"),
          ("Irene", "irene", "IV-07")
        ]
      encontrados =
        [ (etiqueta, codigo)
          | (etiqueta, patron, codigo) <- patrones,
            patron `isInfixOf` minus
        ]
   in sinRepetirCodigo encontrados
  where
    sinRepetirCodigo [] = []
    sinRepetirCodigo ((etq, cod) : xs) =
      (etq, cod) : sinRepetirCodigo [par | par@(_, c) <- xs, c /= cod]

-- ===========================================================================
-- 4. Unificación Temporal (Conversión pura a ISO-8601 UTC)
-- ===========================================================================

-- Formatea una fecha y hora como "YYYY-MM-DDTHH:MM:SSZ"
formatearIsoUtc :: Int -> Int -> Int -> Int -> Int -> Int -> String
formatearIsoUtc anio mes dia hora minuto segundo =
  rellenarCeros 4 anio ++ "-"
    ++ rellenarCeros 2 mes ++ "-"
    ++ rellenarCeros 2 dia ++ "T"
    ++ rellenarCeros 2 hora ++ ":"
    ++ rellenarCeros 2 minuto ++ ":"
    ++ rellenarCeros 2 segundo ++ "Z"

-- 4.1. Normaliza un timestamp ISO ("2041-06-14T01:20:33") a UTC ("2041-06-14T01:20:33Z")
normalizarIso :: String -> Either String String
normalizarIso raw =
  let limpio = limpiar raw
      sinZ   = if not (null limpio) && last limpio == 'Z' then init limpio else limpio
   in case dividirPor 'T' sinZ of
        [parteFecha, parteHora] ->
          case (dividirPor '-' parteFecha, dividirPor ':' parteHora) of
            ([aTxt, mTxt, dTxt], [hTxt, minTxt, sTxt])
              | esNumeroEntero aTxt && length aTxt == 4
                  && validarRango 1 12 mTxt
                  && validarRango 1 31 dTxt
                  && validarRango 0 23 hTxt
                  && validarRango 0 59 minTxt
                  && validarRango 0 59 sTxt ->
                  Right
                    ( formatearIsoUtc
                        (read aTxt)
                        (read mTxt)
                        (read dTxt)
                        (read hTxt)
                        (read minTxt)
                        (read sTxt)
                    )
            _ -> Left ("Timestamp ISO corrupto o invalido: " ++ limpio)
        _ -> Left ("Timestamp ISO corrupto o invalido: " ++ limpio)

-- 4.2. Convierte segundos Unix Epoch (ej. "2254786200") a ISO-8601 UTC ("2041-06-14T01:30:00Z")
-- usando aritmética entera y recursión sobre años y meses desde 1970-01-01.
normalizarEpoch :: String -> Either String String
normalizarEpoch raw =
  let limpio = limpiar raw
   in if esNumeroEntero limpio
        then
          let totalSegundos = read limpio :: Integer
              diasTotales   = totalSegundos `div` 86400
              segsDelDia    = fromIntegral (totalSegundos `mod` 86400) :: Int
              hora          = segsDelDia `div` 3600
              minuto        = (segsDelDia `mod` 3600) `div` 60
              segundo       = segsDelDia `mod` 60
              (anio, mes, dia) = diasDesde1970AFecha diasTotales
           in Right (formatearIsoUtc anio mes dia hora minuto segundo)
        else Left ("Epoch invalido: " ++ limpio)

esBisiesto :: Integer -> Bool
esBisiesto y = (y `mod` 4 == 0 && y `mod` 100 /= 0) || (y `mod` 400 == 0)

diasDesde1970AFecha :: Integer -> (Int, Int, Int)
diasDesde1970AFecha dias =
  let (anio, diasRestantesAnio) = buscarAnio 1970 dias
      (mes, dia)                = buscarMes 1 (diasPorMes anio) diasRestantesAnio
   in (fromIntegral anio, mes, fromIntegral dia + 1)
  where
    buscarAnio :: Integer -> Integer -> (Integer, Integer)
    buscarAnio a d =
      let dAnio = if esBisiesto a then 366 else 365
       in if d >= dAnio
            then buscarAnio (a + 1) (d - dAnio)
            else (a, d)

    diasPorMes :: Integer -> [Integer]
    diasPorMes a = [31, if esBisiesto a then 29 else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    buscarMes :: Int -> [Integer] -> Integer -> (Int, Integer)
    buscarMes m [] d = (m, d)
    buscarMes m (dm : dms) d =
      if d >= dm
        then buscarMes (m + 1) dms (d - dm)
        else (m, d)

-- 4.3. Normaliza horas con punto de presencia.csv (ej. "01.30" -> "2041-06-14T01:30:00Z")
normalizarHoraPunto :: (Int, Int, Int) -> String -> Either String String
normalizarHoraPunto (anio, mes, dia) raw =
  case dividirPor '.' (limpiar raw) of
    [hTxt, mTxt]
      | validarRango 0 23 hTxt && validarRango 0 59 mTxt ->
          Right (formatearIsoUtc anio mes dia (read hTxt) (read mTxt) 0)
    _ -> Left ("Hora con punto invalida: " ++ limpiar raw)

-- 4.4. Normaliza horas con dos puntos de radio.txt (ej. "00:52" -> "2041-06-14T00:52:00Z")
normalizarHoraDosPuntos :: (Int, Int, Int) -> String -> Either String String
normalizarHoraDosPuntos (anio, mes, dia) raw =
  case dividirPor ':' (limpiar raw) of
    [hTxt, mTxt]
      | validarRango 0 23 hTxt && validarRango 0 59 mTxt ->
          Right (formatearIsoUtc anio mes dia (read hTxt) (read mTxt) 0)
    _ -> Left ("Hora HH:MM invalida: " ++ limpiar raw)

-- 4.5. Normaliza fechas "DD/MM" y hora opcional ("01:50 aprox.") de bitacora.txt
normalizarFechaBitacora :: Int -> String -> Maybe String -> Either String (String, Maybe String)
normalizarFechaBitacora anio fechaTxt mHoraTxt =
  case dividirPor '/' (limpiar fechaTxt) of
    [dTxt, mTxt]
      | validarRango 1 31 dTxt && validarRango 1 12 mTxt ->
          let dia = read dTxt
              mes = read mTxt
           in case mHoraTxt of
                Nothing ->
                  Right
                    ( formatearIsoUtc anio mes dia 0 0 0,
                      Just "Entrada diaria sin hora exacta (asignada 00:00:00Z)"
                    )
                Just horaRaw ->
                  let limpioHora = limpiar horaRaw
                      esAprox    = "aprox" `isInfixOf` aMinusculas limpioHora
                      soloHora   = takeWhile (\c -> isDigit c || c == ':') limpioHora
                   in case normalizarHoraDosPuntos (anio, mes, dia) soloHora of
                        Right iso ->
                          let nota =
                                if esAprox
                                  then Just ("Hora aproximada en bitacora (" ++ limpioHora ++ ")")
                                  else Nothing
                           in Right (iso, nota)
                        Left err -> Left err
    _ -> Left ("Fecha DD/MM invalida en bitacora: " ++ fechaTxt)

validarRango :: Int -> Int -> String -> Bool
validarRango minimo maximo txt =
  esNumeroEntero txt && let n = read txt in n >= minimo && n <= maximo
