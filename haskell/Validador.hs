-- Validador.hs
-- Pipeline funcional puro de validacion, deduplicacion, cruce forense
-- y ordenamiento cronologico de la linea de tiempo (Capacidad C1).

module Validador where

import Data.List (isInfixOf, sortBy)
import Normalizar
import Parsers
import Tipos

-- ===========================================================================
-- 1. Pipeline Principal mediante Composición de Funciones (.)
-- ===========================================================================

-- Recibe el texto de los 8 archivos y devuelve la línea de tiempo integrada.
integrarEvidencia
  :: String -> String -> String -> String -> String -> String -> String -> String -> [Evento]
integrarEvidencia txtPersonal txtEstacion txtTarjetas txtRadio txtEnergia txtPresencia txtTemp txtBitacora =
  let personas = parsearPersonal txtPersonal
      puertas  = parsearEstacion txtEstacion
      eventosCrudos =
        parsearBitacora txtBitacora
          ++ parsearTarjetas puertas txtTarjetas
          ++ parsearRadio txtRadio
          ++ parsearEnergia txtEnergia
          ++ parsearPresencia txtPresencia
          ++ parsearTemperatura txtTemp
      pipelineValidacion =
        ordenarEventos
          . detectarContradicciones
          . map (validarPermisosYTopologia personas puertas)
          . marcarDuplicados
   in pipelineValidacion eventosCrudos

-- ===========================================================================
-- 2. Detección Pura de Registros Duplicados (recursión con acumulador)
-- ===========================================================================

type ClaveEvento =
  ( Fuente,
    String,
    Maybe String,
    Maybe String,
    Maybe Modulo,
    Maybe String,
    Maybe Modulo,
    Maybe Modulo,
    Maybe Double
  )

marcarDuplicados :: [Evento] -> [Evento]
marcarDuplicados lista = recorrer [] lista
  where
    recorrer :: [(ClaveEvento, String)] -> [Evento] -> [Evento]
    recorrer _ [] = []
    recorrer vistos (ev : resto)
      | evEstado ev == Corrupto = ev : recorrer vistos resto
      | otherwise =
          let clave = obtenerClave ev
           in case lookup clave vistos of
                Nothing ->
                  ev : recorrer ((clave, evId ev) : vistos) resto
                Just idOriginal ->
                  let evDuplicado =
                        ev
                          { evEstado = Duplicado,
                            evMotivo =
                              combinarMotivos
                                [ evMotivo ev,
                                  Just ("Registro duplicado exacto de " ++ idOriginal)
                                ]
                          }
                   in evDuplicado : recorrer vistos resto

    obtenerClave :: Evento -> ClaveEvento
    obtenerClave ev =
      ( evFuente ev,
        evTipo ev,
        evTsUtc ev,
        evPersona ev,
        evModulo ev,
        evPuerta ev,
        evDesde ev,
        evHacia ev,
        evValor ev
      )

-- ===========================================================================
-- 3. Validación contra personal.csv y estacion.csv
-- ===========================================================================

validarPermisosYTopologia :: [PersonaRef] -> [PuertaRef] -> Evento -> Evento
validarPermisosYTopologia personas puertas ev
  | evFuente ev /= FuenteTarjetas = ev
  | evEstado ev `elem` [Corrupto, Duplicado] = ev
  | otherwise =
      case (evPersona ev, evPuerta ev, evDesde ev, evHacia ev) of
        (Just pid, Just pId, Just mDesde, Just mHacia) ->
          let conectaOk = puertaConecta puertas pId mDesde mHacia
              permisoOk = personaTienePermiso personas pid pId
           in case (conectaOk, evEstado ev, permisoOk) of
                (False, _, _) ->
                  ev
                    { evEstado = Contradictorio,
                      evMotivo =
                        combinarMotivos
                          [ evMotivo ev,
                            Just ("Contradiccion topologica: la puerta " ++ pId ++ " no conecta " ++ moduloATexto mDesde ++ " con " ++ moduloATexto mHacia)
                          ]
                    }
                (True, Denegado, False) ->
                  ev
                    { evMotivo =
                        combinarMotivos
                          [ evMotivo ev,
                            Just ("Confirmado por personal.csv: tarjeta " ++ pid ++ " no tiene permiso para abrir " ++ pId)
                          ]
                    }
                (True, Valido, False) ->
                  ev
                    { evEstado = Contradictorio,
                      evMotivo =
                        combinarMotivos
                          [ evMotivo ev,
                            Just ("Contradiccion de acceso: lector registro OK pero " ++ pid ++ " no tiene permiso en " ++ pId)
                          ]
                    }
                _ -> ev
        _ -> ev

personaTienePermiso :: [PersonaRef] -> String -> String -> Bool
personaTienePermiso personas pid puerta =
  case [refAccesos p | p <- personas, refTarjeta p == pid] of
    (accesos : _) -> puerta `elem` accesos
    []            -> False

puertaConecta :: [PuertaRef] -> String -> Modulo -> Modulo -> Bool
puertaConecta puertas pId m1 m2 =
  case [p | p <- puertas, refPuerta p == pId] of
    (p : _) ->
      (refModulo1 p == m1 && refModulo2 p == m2)
        || (refModulo2 p == m1 && refModulo1 p == m2)
    [] -> False

-- ===========================================================================
-- 4. Detección de Contradicciones Cruzadas entre Fuentes
-- ===========================================================================

detectarContradicciones :: [Evento] -> [Evento]
detectarContradicciones eventos =
  let tarjetasPerdidas = extraerTarjetasPerdidas eventos
      intervalosCorte  = extraerCortesEnergia eventos
   in map (revisarContradiccion tarjetasPerdidas intervalosCorte) eventos

-- Busca en bitacora.txt menciones a pérdida de tarjeta (ej. Petrov LP-04 el 12/06)
extraerTarjetasPerdidas :: [Evento] -> [(String, String, String)]
extraerTarjetasPerdidas eventos =
  [ (codigoPersona, evId ev, tsUtc)
    | ev <- eventos,
      evFuente ev == FuenteBitacora,
      Just motivo <- [evMotivo ev],
      let m = aMinusculas motivo,
      "perdió su tarjeta" `isInfixOf` m || "perdio su tarjeta" `isInfixOf` m,
      (_, codigoPersona) <- detectarMenciones motivo,
      Just tsUtc <- [evTsUtc ev]
  ]

-- Empareja cada evento "energia_corte" con su "energia_restablecido"
extraerCortesEnergia :: [Evento] -> [(String, String)]
extraerCortesEnergia eventos =
  let inicios = [ts | ev <- eventos, evTipo ev == "energia_corte", Just ts <- [evTsUtc ev]]
      fines   = [ts | ev <- eventos, evTipo ev == "energia_restablecido", Just ts <- [evTsUtc ev]]
   in zip inicios fines

revisarContradiccion :: [(String, String, String)] -> [(String, String)] -> Evento -> Evento
revisarContradiccion perdidas cortes ev
  | evEstado ev `elem` [Corrupto, Duplicado] = ev
  | otherwise = revisarCorte cortes (revisarTarjetaPerdida perdidas ev)

revisarTarjetaPerdida :: [(String, String, String)] -> Evento -> Evento
revisarTarjetaPerdida perdidas ev
  | evFuente ev == FuenteTarjetas,
    Just pid <- evPersona ev,
    Just tsUso <- evTsUtc ev =
      case [(idBit, tsPerdida) | (p, idBit, tsPerdida) <- perdidas, p == pid, tsPerdida <= tsUso] of
        ((idBit, tsPerdida) : _) ->
          let puertaTxt = maybe "?" id (evPuerta ev)
           in ev
                { evEstado = Contradictorio,
                  evMotivo =
                    combinarMotivos
                      [ evMotivo ev,
                        Just
                          ( "Contradiccion forense: tarjeta "
                              ++ pid
                              ++ " utilizada en "
                              ++ puertaTxt
                              ++ ", pero fue reportada perdida en "
                              ++ idBit
                              ++ " ("
                              ++ tsPerdida
                              ++ ")"
                          )
                      ]
                }
        [] -> ev
  | otherwise = ev

revisarCorte :: [(String, String)] -> Evento -> Evento
revisarCorte cortes ev
  | evFuente ev == FuenteTarjetas,
    Just ts <- evTsUtc ev,
    any (\(ini, fin) -> ts > ini && ts < fin) cortes =
      ev
        { evEstado = Contradictorio,
          evMotivo =
            combinarMotivos
              [ evMotivo ev,
                Just "Contradiccion electrica: lector registro tarjeta durante corte de energia"
              ]
        }
  | otherwise = ev

-- ===========================================================================
-- 5. Ordenamiento Determinista de la Línea de Tiempo
-- ===========================================================================

ordenarEventos :: [Evento] -> [Evento]
ordenarEventos = sortBy compararEventos
  where
    compararEventos :: Evento -> Evento -> Ordering
    compararEventos a b =
      compare (claveOrden a) (claveOrden b)

    -- Los eventos con ts_utc válido van primero en orden cronológico;
    -- los corruptos (ts_utc = Nothing) quedan al final con marca (True, "9999").
    claveOrden :: Evento -> ((Bool, String), Int, Int, String)
    claveOrden ev =
      let claveTs = case evTsUtc ev of
            Just ts -> (False, ts)
            Nothing -> (True, "9999")
       in (claveTs, prioridadFuente (evFuente ev), evLineaOriginal ev, evId ev)

    prioridadFuente :: Fuente -> Int
    prioridadFuente f = case f of
      FuenteEnergia     -> 1
      FuenteTarjetas    -> 2
      FuentePresencia   -> 3
      FuenteTemperatura -> 4
      FuenteRadio       -> 5
      FuenteBitacora    -> 6
