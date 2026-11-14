-- Pruebas.hs
-- Pruebas automaticas de las funciones puras de C1.
-- Se ejecuta directamente con: runghc Pruebas.hs

module Main where

import Data.List (isInfixOf)
import DatosAnexoA
import Normalizar
import Tipos
import Validador (integrarEvidencia)

integrarAnexoA :: [Evento]
integrarAnexoA =
  integrarEvidencia
    personalAnexoA
    estacionAnexoA
    tarjetasAnexoA
    radioAnexoA
    energiaAnexoA
    presenciaAnexoA
    temperaturaAnexoA
    bitacoraAnexoA

main :: IO ()
main = do
  putStrLn "=== PRUEBAS CAPACIDAD C1 (HASKELL) ==="
  let eventos = integrarAnexoA
      resultados =
        [ ("1. Epoch 2254786200 -> 2041-06-14T01:30:00Z",
           normalizarEpoch "2254786200" == Right "2041-06-14T01:30:00Z"),
          ("2. Hora 01.30 -> 2041-06-14T01:30:00Z",
           normalizarHoraPunto (2041, 6, 14) "01.30" == Right "2041-06-14T01:30:00Z"),
          ("3. Resolucion de alias Luka -> LP-04 y jefe -> JS-01",
           fmap fst (resolverPersona "Luka") == Right "LP-04"
             && fmap fst (resolverPersona "jefe") == Right "JS-01"),
          ("4. Normalizacion de modulo LAB_B -> LAB-B con rastro",
           resolverModulo "LAB_B" == Right (LAB_B, Just "Modulo normalizado: LAB_B -> LAB-B")),
          ("5. Registro corrupto tarjetas-00007 conservado con estado Corrupto",
           verificarEvento eventos "tarjetas-00007" (\e -> evEstado e == Corrupto && evTsUtc e == Nothing)),
          ("6. Registro duplicado tarjetas-00005 marcado como Duplicado",
           verificarEvento eventos "tarjetas-00005" (\e -> evEstado e == Duplicado)),
          ("7. Acceso DENEGADO de DV-02 en P4 (tarjetas-00012) marcado como Denegado",
           verificarEvento eventos "tarjetas-00012" (\e -> evEstado e == Denegado)),
          ("8. Contradiccion de tarjeta perdida LP-04 (tarjetas-00008 vs bitacora-00001)",
           verificarEvento eventos "tarjetas-00008" (\e -> evEstado e == Contradictorio)),
          ("9. Linea partida en bitacora-00003 ('Kimura con fiebre') reconstruida",
           verificarEvento eventos "bitacora-00003" (\e -> maybe False ("Kimura con fiebre" `isInfixOf`) (evMotivo e))),
          ("10. Total de eventos integrados del Anexo A = 70",
           length eventos == 70)
        ]
  mapM_ mostrarResultado resultados
  let fallos = [nombre | (nombre, ok) <- resultados, not ok]
  if null fallos
    then putStrLn "\nTODAS LAS PRUEBAS PASARON EXITOSAMENTE."
    else putStrLn ("\nFALLARON " ++ show (length fallos) ++ " PRUEBAS.")

verificarEvento :: [Evento] -> String -> (Evento -> Bool) -> Bool
verificarEvento eventos idBuscado predicado =
  case [e | e <- eventos, evId e == idBuscado] of
    (ev : _) -> predicado ev
    []       -> False

mostrarResultado :: (String, Bool) -> IO ()
mostrarResultado (nombre, True)  = putStrLn ("[OK]    " ++ nombre)
mostrarResultado (nombre, False) = putStrLn ("[FALLO] " ++ nombre)
