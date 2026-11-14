-- Validador.hs
-- Pipeline funcional puro de validacion, deduplicacion, cruce forense
-- y ordenamiento cronologico de la linea de tiempo (Capacidad C1).

module Validador where

import Data.List (isInfixOf, sort, sortBy)
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
  let (personas, diagPersonal) = parsearPersonal txtPersonal
      (puertas, diagEstacion)  = parsearEstacion txtEstacion
      eventosCrudos =
        diagPersonal
          ++ diagEstacion
          ++ parsearBitacora personas txtBitacora
          ++ parsearTarjetas personas puertas txtTarjetas
          ++ parsearRadio personas txtRadio
          ++ parsearEnergia txtEnergia
          ++ parsearPresencia txtPresencia
          ++ parsearTemperatura txtTemp
      pipelineValidacion =
        ordenarEventos
          . detectarContradicciones personas
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
              lectorOk  = puertaTieneLector puertas pId
           in case (conectaOk, lectorOk, evEstado ev, permisoOk) of
                (False, _, _, _) ->
                  ev
                    { evEstado = Contradictorio,
                      evMotivo =
                        combinarMotivos
                          [ evMotivo ev,
                            Just ("Contradiccion topologica: la puerta " ++ pId ++ " no conecta " ++ moduloATexto mDesde ++ " con " ++ moduloATexto mHacia)
                          ]
                    }
                (_, False, _, _) ->
                  ev
                    { evEstado = Contradictorio,
                      evMotivo =
                        combinarMotivos
                          [ evMotivo ev,
                            Just ("Contradiccion de lector: la puerta " ++ pId ++ " no tiene lector de tarjeta")
                          ]
                    }
                (True, True, Denegado, False) ->
                  ev
                    { evMotivo =
                        combinarMotivos
                          [ evMotivo ev,
                            Just ("Confirmado por personal.csv: tarjeta " ++ pid ++ " no tiene permiso para abrir " ++ pId)
                          ]
                    }
                (True, True, Denegado, True) ->
                  ev
                    { evEstado = Contradictorio,
                      evMotivo =
                        combinarMotivos
                          [ evMotivo ev,
                            Just ("Contradiccion de acceso: lector registro DENEGADO pero " ++ pid ++ " si tiene permiso en " ++ pId)
                          ]
                    }
                (True, True, Valido, False) ->
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

puertaTieneLector :: [PuertaRef] -> String -> Bool
puertaTieneLector puertas pId =
  case [p | p <- puertas, refPuerta p == pId] of
    (p : _) -> refTieneLector p
    []      -> False

-- ===========================================================================
-- 4. Detección de Contradicciones Cruzadas entre Fuentes
-- ===========================================================================

-- Intervalo de corte por módulo: (módulo, inicio, fin opcional).
-- El fin es Nothing si no hay un "restablecido" posterior en la fuente.
type IntervaloCorte = (Modulo, String, Maybe String)

detectarContradicciones :: [PersonaRef] -> [Evento] -> [Evento]
detectarContradicciones personas eventos =
  let tarjetasPerdidas = extraerTarjetasPerdidas personas eventos
      intervalosCorte  = extraerCortesEnergia eventos
   in map (revisarContradiccion tarjetasPerdidas intervalosCorte) eventos

-- Busca en bitacora.txt menciones a pérdida de tarjeta (ej. Petrov LP-04 el 12/06)
extraerTarjetasPerdidas :: [PersonaRef] -> [Evento] -> [(String, String, String)]
extraerTarjetasPerdidas personas eventos =
  [ (codigoPersona, evId ev, tsUtc)
    | ev <- eventos,
      evFuente ev == FuenteBitacora,
      Just motivo <- [evMotivo ev],
      let m = aMinusculas motivo,
      "perdió su tarjeta" `isInfixOf` m || "perdio su tarjeta" `isInfixOf` m,
      (_, codigoPersona) <- detectarMencionesValidas personas motivo,
      Just tsUtc <- [evTsUtc ev]
  ]

-- Empareja cada evento "energia_corte" con el siguiente "energia_restablecido".
-- Los cortes se emiten por módulo, así que un mismo instante puede tener
-- varios intervalos (COM, DOR, LAB-A, ...). RAD no aparece si no fue afectado.
extraerCortesEnergia :: [Evento] -> [IntervaloCorte]
extraerCortesEnergia eventos =
  let restablecimientos =
        sort [ts | ev <- eventos, evTipo ev == "energia_restablecido", Just ts <- [evTsUtc ev]]
      cortes =
        [ (m, ts)
          | ev <- eventos,
            evTipo ev == "energia_corte",
            Just m <- [evModulo ev],
            m /= TODOS,
            Just ts <- [evTsUtc ev]
        ]
      siguienteFin ini =
        case [f | f <- restablecimientos, f > ini] of
          (f : _) -> Just f
          []      -> Nothing
   in [(m, ini, siguienteFin ini) | (m, ini) <- cortes]

revisarContradiccion :: [(String, String, String)] -> [IntervaloCorte] -> Evento -> Evento
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

revisarCorte :: [IntervaloCorte] -> Evento -> Evento
revisarCorte cortes ev
  | evFuente ev == FuenteTarjetas,
    Just ts <- evTsUtc ev,
    Just modulo <- primerModuloAfectado [m | Just m <- [evDesde ev, evHacia ev]] ts cortes =
      ev
        { evEstado = Contradictorio,
          evMotivo =
            combinarMotivos
              [ evMotivo ev,
                Just
                  ( "Contradiccion electrica: el lector registro una tarjeta en "
                      ++ maybe "?" id (evPuerta ev)
                      ++ " durante el corte que afecta a "
                      ++ moduloATexto modulo
                  )
              ]
        }
  | otherwise = ev
  where
    primerModuloAfectado :: [Modulo] -> String -> [IntervaloCorte] -> Maybe Modulo
    primerModuloAfectado [] _ _ = Nothing
    primerModuloAfectado (m : ms) ts intervalos =
      case [() | (m', ini, mFin) <- intervalos, m' == m, ts > ini, maybe True (ts <) mFin] of
        (_ : _) -> Just m
        []      -> primerModuloAfectado ms ts intervalos

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
    -- los que no tienen hora (corruptos o diagnósticos de referencia)
    -- quedan al final con marca (True, "9999").
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
      FuentePersonal    -> 7
      FuenteEstacion    -> 8
